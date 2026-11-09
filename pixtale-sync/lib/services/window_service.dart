// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:path/path.dart' as path;
import 'package:pixtale_sync/db/database_path.dart';
import 'package:pixtale_sync/l10n/locale.dart';
import 'package:pixtale_sync/providers/sync_provider.dart';
import 'package:pixtale_sync/services/tray_sync_service.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/legacy.dart';
import 'package:window_manager/window_manager.dart';

// 桌面窗口优先恢复用户上次的宽高，否则用默认尺寸居中。关闭时隐藏到系统托盘。

/// 统一管理桌面窗口，移动端不初始化此服务。
class WindowService with WindowListener, TrayListener {
  /// 创建窗口服务，平台接口和语言可替换以验证原生资源的退出顺序。
  WindowService({TrayManager? tray, WindowManager? window, AppLocale? locale})
    : _tray = tray ?? trayManager,
      _window = window ?? windowManager,
      _locale = locale ?? AppLocale.instance;

  /// 应用启动时使用的窗口服务。
  static final instance = WindowService();

  /// 没有有效记录时使用的逻辑像素尺寸。
  static const defaultSize = Size(960, 800);

  /// 常规屏幕上的窗口最小尺寸。
  static const minimumSize = Size(600, 630);

  /// 用户数据目录中的窗口尺寸文件，不写入数据库。
  static const windowFileName = 'window.json';

  /// 桌面且不是测试时画出自定义标题栏，并藏掉系统那一条。
  static bool get showsTitleBar {
    if (Platform.environment['FLUTTER_TEST'] == 'true') return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  bool _exiting = false;
  TraySyncService? _traySync;
  final TrayManager _tray;
  final WindowManager _window;
  final AppLocale _locale;

  /// 托盘和页面使用同一份同步状态。
  void bindSync(SyncProvider sync) {
    _traySync?.dispose();
    _traySync = TraySyncService(sync: sync, setToolTip: _tray.setToolTip);
  }

  void unbindSync(SyncProvider sync) {
    if (_traySync?.sync != sync) return;
    _traySync?.dispose();
    _traySync = null;
  }

  /// 在主屏幕内以默认尺寸居中显示窗口。
  Future<void> initialize() async {
    await _window.ensureInitialized();
    _window.addListener(this);
    await _window.setPreventClose(true);
    await initializeTray();
    final primary = await screenRetriever.getPrimaryDisplay();
    final visibleSize = primary.visibleSize ?? primary.size;
    final saved = await readSavedSize();
    final bounds = fitBounds(
      Rect.fromLTWH(
        primary.visiblePosition?.dx ?? 0,
        primary.visiblePosition?.dy ?? 0,
        visibleSize.width,
        visibleSize.height,
      ),
      saved: saved,
    );
    await _window.waitUntilReadyToShow(
      WindowOptions(
        size: bounds.size,
        minimumSize: Size(
          math.min(minimumSize.width, bounds.width),
          math.min(minimumSize.height, bounds.height),
        ),
        title: 'Pixtale Sync',
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
      ),
    );
    await _window.setBounds(bounds);
    await _window.show();
    await _window.focus();
  }

  /// 创建托盘，并在应用语言变化时更新右键菜单。
  Future<void> initializeTray() async {
    _tray.addListener(this);
    _locale.addListener(_onLocaleChanged);
    await _tray.setIcon('assets/tray_icon.png');
    await _tray.setToolTip('Pixtale Sync');
    await _updateTrayMenu();
  }

  /// 使用与界面一致的语言重建菜单，包含跟随系统的情况。
  Future<void> _updateTrayMenu() async {
    if (_exiting) return;
    final text = AppLocale.strings(saved: _locale.locale?.languageCode);
    await _tray.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: 'show',
            label: text.open,
            onClick: (_) => unawaited(_showWindow()),
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit',
            label: text.quit,
            // 原生菜单回调返回后再销毁资源，避免在回调中释放所属托盘。
            onClick: (_) => unawaited(Future<void>(quit)),
          ),
        ],
      ),
    );
  }

  /// 用户切换语言时立即更新菜单。
  void _onLocaleChanged() => unawaited(_updateTrayMenu());

  /// 拖动结束后记下当前宽高。最大化时不覆盖上次的普通尺寸。
  @override
  void onWindowResized() {
    unawaited(_rememberSize());
  }

  /// 点击窗口关闭按钮时先保存尺寸，再隐藏窗口并保留托盘图标。
  @override
  void onWindowClose() {
    if (_exiting) return;
    unawaited(_rememberSize().whenComplete(_window.hide));
  }

  /// 点击托盘图标时重新显示窗口。
  @override
  void onTrayIconMouseDown() {
    unawaited(_showWindow());
  }

  /// 右键托盘图标时弹出操作菜单。
  @override
  void onTrayIconRightMouseDown() {
    unawaited(_showTrayMenu());
  }

  /// 打开前再解析系统语言，退出期间不再创建托盘资源。
  Future<void> _showTrayMenu() async {
    await _updateTrayMenu();
    if (!_exiting) await _tray.popUpContextMenu();
  }

  /// 显示窗口并恢复焦点。
  Future<void> _showWindow() async {
    if (_exiting) return;
    await _window.show();
    await _window.focus();
  }

  /// 先隐藏窗口及托盘，再等待同步停止，最后销毁原生窗口。
  Future<void> quit() async {
    if (_exiting) return;
    _exiting = true;
    final sync = _traySync?.sync;
    _traySync?.dispose();
    _traySync = null;
    _locale.removeListener(_onLocaleChanged);
    try {
      // 先让可见窗口消失，避免 Flutter 引擎释放期间留下停止重绘的界面。
      await _window.hide();
      _window.removeListener(this);
      _tray.removeListener(this);
      await _tray.destroy();
      await sync?.stop();
    } finally {
      await _window.setPreventClose(false);
      await _window.destroy();
    }
  }

  /// 读取上次保存的宽高。文件缺失或内容无效时返回空。
  static Future<Size?> readSavedSize([Directory? directory]) async {
    try {
      final folder = directory ?? Directory(await desktopDatabaseDirectory());
      final file = File(path.join(folder.path, windowFileName));
      if (!await file.exists()) return null;
      return sizeFromJson(await file.readAsString());
    } catch (_) {
      return null;
    }
  }

  /// 把当前窗口宽高写入用户数据目录。
  static Future<void> writeSavedSize(Size size, [Directory? directory]) async {
    final folder = directory ?? Directory(await desktopDatabaseDirectory());
    await folder.create(recursive: true);
    final file = File(path.join(folder.path, windowFileName));
    await file.writeAsString(
      jsonEncode({'width': size.width, 'height': size.height}),
    );
  }

  /// 解析窗口文件。小于最小尺寸或数字无效时返回空。
  static Size? sizeFromJson(String text) {
    try {
      final data = jsonDecode(text);
      if (data is! Map) return null;
      final width = data['width'];
      final height = data['height'];
      if (width is! num || height is! num) return null;
      final size = Size(width.toDouble(), height.toDouble());
      if (!size.width.isFinite ||
          !size.height.isFinite ||
          size.width < minimumSize.width ||
          size.height < minimumSize.height) {
        return null;
      }
      return size;
    } catch (_) {
      return null;
    }
  }

  /// 优先使用已保存尺寸并居中。超出屏幕或无效时退回默认尺寸。
  static Rect fitBounds(Rect screen, {Size? saved}) {
    final preferred = _usableSize(saved, screen) ?? defaultSize;
    final width = math.min(preferred.width, screen.width);
    final height = math.min(preferred.height, screen.height);
    return Rect.fromLTWH(
      screen.center.dx - width / 2,
      screen.center.dy - height / 2,
      width,
      height,
    );
  }

  /// 已保存尺寸必须不小于最小尺寸，并且能放进当前屏幕。
  static Size? _usableSize(Size? saved, Rect screen) {
    if (saved == null) return null;
    if (saved.width < minimumSize.width || saved.height < minimumSize.height) {
      return null;
    }
    if (saved.width > screen.width || saved.height > screen.height) return null;
    return saved;
  }

  /// 最大化时保留上一次普通尺寸，读写失败不影响窗口显示。
  Future<void> _rememberSize() async {
    try {
      if (await _window.isMaximized()) return;
      final bounds = await _window.getBounds();
      await writeSavedSize(bounds.size);
    } catch (_) {}
  }
}
