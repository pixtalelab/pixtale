import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixtale_sync/l10n/locale.dart';
import 'package:pixtale_sync/models/sync.dart';
import 'package:pixtale_sync/providers/sync_provider.dart';
import 'package:pixtale_sync/services/sync_service.dart';
import 'package:pixtale_sync/services/tray_sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() {
    final locale = AppLocale.instance.locale;
    AppLocale.instance.locale = const Locale('zh');
    addTearDown(() => AppLocale.instance.locale = locale);
  });

  testWidgets('托盘跟随同步进度、相册、下次时间和停止状态', (tester) async {
    final sync = _TestSync();
    final tooltips = <String>[];
    final tray = TraySyncService(
      sync: sync,
      setToolTip: (text) async => tooltips.add(text),
    );
    addTearDown(sync.dispose);
    addTearDown(tray.dispose);

    await tester.pump(const Duration(milliseconds: 200));
    expect(tooltips.last, 'Pixtale Sync');
    sync.update(active: true);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tooltips.last, '准备同步');
    sync.update(active: true, albumId: 'a', albumName: '旅行', checking: true);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tooltips.last, '正在远程检测 - 旅行');

    sync.update(active: true, albumId: 'a', progress: _progress(20));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tooltips.last, '正在同步 20 / 123 - 旅行');
    final writes = tooltips.length;
    for (var completed = 21; completed <= 30; completed++) {
      sync.update(active: true, albumId: 'a', progress: _progress(completed));
    }
    await tester.pump(const Duration(milliseconds: 200));
    expect(tooltips.length, writes + 1);
    expect(tooltips.last, '正在同步 30 / 123 - 旅行');

    sync.update(
      active: true,
      albumId: 'b',
      progress: _progress(1, albumId: 'b', albumName: '家庭'),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(tooltips.last, '正在同步 1 / 123 - 家庭');
    sync.update(active: true, stopping: true, albumId: 'b', albumName: '家庭');
    await tester.pump(const Duration(milliseconds: 200));
    expect(tooltips.last, '正在停止同步 - 家庭');
    sync.update(active: true, nextSyncAt: DateTime(2026, 11, 7, 20, 32));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tooltips.last, '下次同步：20:32');
    sync.update(active: true, stopping: true);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tooltips.last, '正在停止同步');
    sync.update(active: false);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tooltips.last, 'Pixtale Sync');
  });

  testWidgets('异步写入顺序更新，不让旧进度覆盖新状态', (tester) async {
    final sync = _TestSync();
    final pending = Completer<void>();
    final tooltips = <String>[];
    final tray = TraySyncService(
      sync: sync,
      setToolTip: (text) async {
        if (tooltips.isEmpty) await pending.future;
        tooltips.add(text);
      },
    );
    addTearDown(sync.dispose);
    addTearDown(tray.dispose);
    sync.update(active: true, albumId: 'a', progress: _progress(20));
    await tester.pump(const Duration(milliseconds: 200));
    sync.update(active: true, nextSyncAt: DateTime(2026, 11, 7, 20, 32));
    await tester.pump(const Duration(milliseconds: 200));
    pending.complete();
    await tester.pump();
    expect(tooltips, ['正在同步 20 / 123 - 旅行', '下次同步：20:32']);
  });

  testWidgets('提示更新失败后下次状态变化可恢复，长相册名安全截断', (tester) async {
    final sync = _TestSync();
    final tooltips = <String>[];
    var fail = true;
    final tray = TraySyncService(
      sync: sync,
      setToolTip: (text) async {
        if (fail) throw StateError('Tray unavailable');
        tooltips.add(text);
      },
    );
    addTearDown(sync.dispose);
    addTearDown(tray.dispose);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tooltips, isEmpty);
    fail = false;
    sync.update(
      active: true,
      albumId: 'a',
      progress: _progress(20, albumName: '📸' * 100),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final tooltip = tooltips.single;
    expect(tooltip.length, lessThanOrEqualTo(127));
    expect(tooltip, startsWith('正在同步 20 / 123 - 📸'));
    expect(tooltip, endsWith('…'));
    expect(
      tooltip.runes.any((rune) => rune >= 0xD800 && rune <= 0xDFFF),
      isFalse,
    );
  });

  testWidgets('提示跟随语言，释放后不再更新托盘', (tester) async {
    final sync = _TestSync();
    final tooltips = <String>[];
    final tray = TraySyncService(
      sync: sync,
      setToolTip: (text) async => tooltips.add(text),
    );
    addTearDown(sync.dispose);
    AppLocale.instance.locale = const Locale('en');
    sync.update(active: true, albumId: 'a', progress: _progress(20));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tooltips.single, 'Syncing 20 / 123 - 旅行');
    sync.update(active: false);
    tray.dispose();
    sync.update(active: true, nextSyncAt: DateTime(2026, 11, 7, 20, 32));
    await tester.pump(const Duration(seconds: 1));
    expect(tooltips, hasLength(1));
  });

  test('进度消息携带相册名，兼容旧消息', () {
    final progress = _progress(20);
    expect(SyncProgress.fromJson(progress.toJson()).albumName, '旅行');
    expect(
      SyncProgress.fromJson(progress.toJson()..remove('albumName')).albumName,
      '',
    );
    const activity = SyncActivity(
      albumId: 'a',
      albumName: '旅行',
      checking: true,
    );
    final restored = SyncActivity.fromJson(activity.toJson());
    expect(restored.albumId, 'a');
    expect(restored.albumName, '旅行');
    expect(restored.checking, isTrue);
    expect(SyncActivity.fromJson({'stopping': false}).albumName, isNull);
  });

  testWidgets('下一轮检测保留进度但显示检测状态和当前相册名', (tester) async {
    final sync = _TestSync();
    final tooltips = <String>[];
    final tray = TraySyncService(
      sync: sync,
      setToolTip: (text) async => tooltips.add(text),
    );
    addTearDown(sync.dispose);
    addTearDown(tray.dispose);
    sync.update(active: true, albumId: 'a', progress: _progress(123));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tooltips.last, '正在同步 123 / 123 - 旅行');
    sync.update(active: true, nextSyncAt: DateTime(2026, 11, 7, 20, 32));
    await tester.pump(const Duration(milliseconds: 200));
    sync.update(active: true, albumId: 'a', albumName: '新旅行', checking: true);
    await tester.pump(const Duration(milliseconds: 200));
    expect(sync.progress['a']?.completed, 123);
    expect(tooltips.last, '正在远程检测 - 新旅行');
  });
}

SyncProgress _progress(
  int completed, {
  String albumId = 'a',
  String albumName = '旅行',
}) => SyncProgress(
  albumId: albumId,
  completed: completed,
  total: 123,
  ruleName: '本地照片',
  albumName: albumName,
);

class _TestSync extends SyncProvider {
  _TestSync() : super(service: SyncService());

  void update({
    required bool active,
    bool stopping = false,
    String? albumId,
    String? albumName,
    bool checking = false,
    SyncProgress? progress,
    DateTime? nextSyncAt,
  }) {
    this.active = active;
    this.stopping = stopping;
    currentAlbumId = albumId;
    currentAlbumName = albumName ?? progress?.albumName;
    this.checking = checking;
    this.nextSyncAt = nextSyncAt;
    if (progress != null) this.progress[progress.albumId] = progress;
    notifyListeners();
  }
}
