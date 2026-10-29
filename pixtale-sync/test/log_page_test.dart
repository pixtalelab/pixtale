import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixtale_sync/models/log.dart';
import 'package:pixtale_sync/pages/log_page.dart';
import 'package:pixtale_sync/services/log_service.dart';
import 'package:pixtale_sync/theme/app_theme.dart';
import 'localized_app.dart';

// 验证日志只读展示、状态颜色和新增记录刷新。

/// 执行不依赖原生平台和数据库的日志界面测试。
void main() {
  testWidgets('窄屏日志只读显示全部记录，支持实时刷新和清空', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = MemoryLogs();
    addTearDown(service.events.close);
    service.records.addAll([
      _log(2, 'bad.jpg', LogStatus.failure, '不支持的图片'),
      _log(1, '远程检测', LogStatus.success, 'Success'),
    ]);
    await tester.pumpWidget(
      localizedApp(
        theme: buildAppTheme(),
        home: LogPage(logService: service),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('bad.jpg'), findsOneWidget);
    expect(find.text('远程检测'), findsOneWidget);
    expect(find.text('成功'), findsOneWidget);
    expect(find.text('失败'), findsOneWidget);
    expect(find.text('Success'), findsOneWidget);
    final colors = Theme.of(tester.element(find.text('成功'))).colorScheme;
    final original = ColorScheme.fromSeed(
      seedColor: const Color(0xFF247A78),
      surface: const Color(0xFFF8FAF9),
    );
    expect(colors.primary, const Color(0xFF111111));
    expect(colors.surface, const Color(0xFFFFFFFF));
    expect(colors.onSurface, original.onSurface);
    expect(colors.onSurfaceVariant, original.onSurfaceVariant);
    expect(colors.secondary, original.secondary);
    expect(
      DefaultTextStyle.of(tester.element(find.text('日志'))).style.color,
      original.onSurface,
    );
    expect(
      Theme.of(tester.element(find.text('日志'))).textButtonTheme.style,
      isNull,
    );
    for (final status in ['成功', '失败']) {
      final badge = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.text(status),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(
        (badge.decoration as BoxDecoration).color,
        status == '成功' ? colors.primary : colors.error,
      );
      expect(
        tester.widget<Text>(find.text(status)).style?.color,
        status == '成功' ? colors.onPrimary : colors.onError,
      );
    }
    expect(find.byType(SegmentedButton<bool>), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('bad.jpg'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.ancestor(of: find.text('bad.jpg'), matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(find.text('Success'), findsOneWidget);
    expect(find.text('不支持的图片'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();
    expect(find.text('全部'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(MenuItemButton),
        matching: find.text('失败'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('bad.jpg'), findsOneWidget);
    expect(find.text('远程检测'), findsNothing);
    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(MenuItemButton),
        matching: find.text('成功'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('远程检测'), findsOneWidget);
    expect(find.text('bad.jpg'), findsNothing);
    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(MenuItemButton),
        matching: find.text('全部'),
      ),
    );
    await tester.pumpAndSettle();

    service.records.insert(0, _log(3, 'new.jpg', LogStatus.failure, '请求超时'));
    service.events.add(null);
    await tester.pumpAndSettle();
    expect(find.text('new.jpg'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pumpAndSettle();
    expect(find.text('bad.jpg'), findsNothing);
    expect(find.text('new.jpg'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

/// 创建带固定时间的日志样本。
Log _log(int id, String event, int status, String message) => Log(
  id: id,
  albumName: '旅行照片',
  event: event,
  status: status,
  message: message,
  createdAt: DateTime.utc(2026, 10, 27, 6, 32, 10),
);

/// 用内存记录模拟分页查询和已持久化通知。
class MemoryLogs extends LogService {
  final List<Log> records = [];
  final events = StreamController<void>.broadcast();

  /// 返回测试用变更流。
  @override
  Stream<void> get changes => events.stream;

  /// 按界面筛选和分页参数返回预设记录。
  @override
  Future<List<Log>> list({
    bool failuresOnly = false,
    int? status,
    int offset = 0,
    int limit = 100,
  }) async {
    final selected = status ?? (failuresOnly ? LogStatus.failure : null);
    return records
        .where((log) => selected == null || log.status == selected)
        .skip(offset)
        .take(limit)
        .toList();
  }

  /// 清空后通知页面刷新。
  @override
  Future<void> clear() async {
    records.clear();
    events.add(null);
  }
}
