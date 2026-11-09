// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixtale_sync/l10n/locale.dart';
import 'package:pixtale_sync/providers/sync_provider.dart';
import 'package:pixtale_sync/services/sync_service.dart';
import 'package:pixtale_sync/services/window_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tray_manager/legacy.dart';
import 'package:window_manager/window_manager.dart';

// 验证默认窗口屏幕适配。

/// 执行桌面窗口测试，无需创建原生窗口。
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('托盘菜单使用当前语言，并随语言切换更新', (tester) async {
    final events = <String>[];
    final tray = _Tray(events);
    final locale = _Locale()..change(const Locale('zh'));
    final service = WindowService(
      tray: tray,
      window: _Window(events),
      locale: locale,
    );
    await service.initializeTray();
    expect(tray.menus.last.items!.map((item) => item.label), [
      '打开',
      null,
      '退出',
    ]);
    locale.change(const Locale('en'));
    await tester.pump();
    expect(tray.menus.last.items!.map((item) => item.label), [
      'Open',
      null,
      'Quit',
    ]);
    tray.menus.last.items!.first.onClick!(tray.menus.last.items!.first);
    await tester.pump();
    expect(events, ['show', 'focus']);
    await service.quit();
    final count = tray.menus.length;
    locale.change(const Locale('zh'));
    service.onTrayIconRightMouseDown();
    service.onTrayIconMouseDown();
    await tester.pump();
    expect(tray.menus, hasLength(count));
    expect(events.where((event) => event == 'show'), hasLength(1));
  });

  testWidgets('退出等原生菜单回调返回后执行，先隐藏再清理同步，期间不重建托盘', (tester) async {
    final events = <String>[];
    final tray = _Tray(events);
    final locale = _Locale();
    final service = WindowService(
      tray: tray,
      window: _Window(events),
      locale: locale,
    );
    final pending = Completer<void>();
    final sync = _Sync(events, pending.future);
    addTearDown(sync.dispose);
    await service.initializeTray();
    service.bindSync(sync);
    final item = tray.menus.last.items!.last;
    item.onClick!(item);
    expect(events, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(events, ['hide', 'destroyTray', 'stopSync']);
    final count = tray.menus.length;
    locale.change(const Locale('en'));
    service.onTrayIconRightMouseDown();
    service.onTrayIconMouseDown();
    await service.quit();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tray.menus, hasLength(count));
    expect(events, ['hide', 'destroyTray', 'stopSync']);
    pending.complete();
    await tester.pump();
    expect(events, [
      'hide',
      'destroyTray',
      'stopSync',
      'allowClose',
      'destroyWindow',
    ]);
  });

  testWidgets('停止同步失败时仍销毁窗口退出', (tester) async {
    final events = <String>[];
    final service = WindowService(tray: _Tray(events), window: _Window(events));
    final pending = Completer<void>();
    final sync = _Sync(events, pending.future);
    addTearDown(sync.dispose);
    await service.initializeTray();
    service.bindSync(sync);
    final operation = service.quit();
    final assertion = expectLater(operation, throwsStateError);
    await tester.pump();
    pending.completeError(StateError('Cannot stop sync'));
    await assertion;
    expect(events, [
      'hide',
      'destroyTray',
      'stopSync',
      'allowClose',
      'destroyWindow',
    ]);
  });

  test('首次打开使用默认尺寸并居中', () {
    expect(
      WindowService.fitBounds(const Rect.fromLTWH(0, 0, 1920, 1040)),
      const Rect.fromLTWH(480, 120, 960, 800),
    );
  });

  test('按屏幕原点居中，支持负坐标屏幕', () {
    expect(
      WindowService.fitBounds(const Rect.fromLTWH(-1920, 0, 1920, 1040)),
      const Rect.fromLTWH(-1440, 120, 960, 800),
    );
  });

  test('窗口限制在可用屏幕内，支持比最小尺寸还小的屏幕', () {
    expect(
      WindowService.fitBounds(const Rect.fromLTWH(0, 0, 800, 600)),
      const Rect.fromLTWH(0, 0, 800, 600),
    );
    expect(
      WindowService.fitBounds(const Rect.fromLTWH(0, 0, 500, 400)),
      const Rect.fromLTWH(0, 0, 500, 400),
    );
  });

  test('已保存尺寸居中，超出屏幕或小于最小尺寸时退回默认', () {
    expect(
      WindowService.fitBounds(
        const Rect.fromLTWH(0, 0, 1920, 1040),
        saved: const Size(720, 800),
      ),
      const Rect.fromLTWH(600, 120, 720, 800),
    );
    expect(
      WindowService.fitBounds(
        const Rect.fromLTWH(0, 0, 1920, 1040),
        saved: const Size(2000, 800),
      ),
      const Rect.fromLTWH(480, 120, 960, 800),
    );
    expect(
      WindowService.fitBounds(
        const Rect.fromLTWH(0, 0, 1920, 1040),
        saved: const Size(500, 400),
      ),
      const Rect.fromLTWH(480, 120, 960, 800),
    );
  });

  test('窗口文件保存宽高，无效内容视为没有记录', () async {
    final directory = await Directory.systemTemp.createTemp('window_json_');
    addTearDown(() => directory.delete(recursive: true));
    expect(await WindowService.readSavedSize(directory), isNull);

    await WindowService.writeSavedSize(const Size(720, 800), directory);
    expect(await WindowService.readSavedSize(directory), const Size(720, 800));

    final file = File('${directory.path}/window.json');
    await file.writeAsString('{');
    expect(await WindowService.readSavedSize(directory), isNull);
    expect(WindowService.sizeFromJson('{"width":100,"height":100}'), isNull);
  });
}

/// 记录托盘操作，测试中不加载原生 FFI。
class _Tray implements TrayManager {
  /// 共享退出流程事件。
  _Tray(this.events);
  final List<String> events;
  final List<Menu> menus = [];

  /// 测试无需注册原生托盘回调。
  @override
  void addListener(TrayListener listener) {}

  /// 测试无需解除原生托盘回调。
  @override
  void removeListener(TrayListener listener) {}

  /// 跳过图片加载。
  @override
  Future<void> setIcon(
    String iconPath, {
    bool isTemplate = false,
    TrayIconPosition iconPosition = TrayIconPosition.left,
    int iconSize = 18,
  }) async {}

  /// 退出后不应再写提示，否则原生实现可能重建托盘图标。
  @override
  Future<void> setToolTip(String value) async {
    if (events.contains('destroyTray')) {
      throw StateError('Tray already destroyed');
    }
  }

  /// 保留生成的菜单，用于检查文案和点击回调。
  @override
  Future<void> setContextMenu(Menu menu) async => menus.add(menu);

  /// 记录菜单弹出。
  @override
  Future<void> popUpContextMenu({bool bringAppToFront = false}) async =>
      events.add('popup');

  /// 记录托盘销毁。
  @override
  Future<void> destroy() async => events.add('destroyTray');

  /// 其他未使用接口不参与测试。
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 记录原生窗口显示和退出的先后顺序。
class _Window implements WindowManager {
  /// 共享退出流程事件。
  _Window(this.events);
  final List<String> events;

  /// 模拟解除窗口监听。
  @override
  void removeListener(WindowListener listener) {}

  /// 模拟隐藏窗口。
  @override
  Future<void> hide() async => events.add('hide');

  /// 模拟托盘重新显示窗口。
  @override
  Future<void> show({bool inactive = false}) async => events.add('show');

  /// 模拟恢复窗口焦点。
  @override
  Future<void> focus() async => events.add('focus');

  /// 退出时应解除阻止关闭。
  @override
  Future<void> setPreventClose(bool value) async {
    events.add(value ? 'preventClose' : 'allowClose');
  }

  /// 记录最终销毁窗口。
  @override
  Future<void> destroy() async => events.add('destroyWindow');

  /// 其他未使用接口不参与测试。
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 让测试直接切换语言并发送与设置页面相同的通知。
class _Locale extends AppLocale {
  /// 更新语言并通知托盘重建菜单。
  void change(Locale value) {
    locale = value;
    notifyListeners();
  }
}

/// 控制同步停止的完成时机。
class _Sync extends SyncProvider {
  /// 注入不会访问原生插件的同步实现。
  _Sync(this.events, this.pending) : super(service: SyncService());
  final List<String> events;
  final Future<void> pending;

  /// 等待测试放行，验证窗口在同步停止前已隐藏。
  @override
  Future<void> stop() async {
    events.add('stopSync');
    await pending;
  }
}
