import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pixtale_sync/db/db.dart';
import 'package:pixtale_sync/models/log.dart';
import 'package:pixtale_sync/services/log_service.dart';
import 'package:pixtale_sync/services/settings_service.dart';

// 验证日志倒序分页、筛选、数量限制和清空通知。

/// 执行日志持久化测试。
void main() {
  sqfliteFfiInit();

  late Db database;
  late LogService logs;
  late SettingsService settings;

  setUp(() {
    database = Db(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    logs = LogService(database: database);
    settings = SettingsService(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  test('成功固定保存 Success，失败保留错误，倒序分页和异常筛选', () async {
    await logs.add(
      albumName: '旅行',
      event: '远程检测',
      status: LogStatus.success,
    );
    await logs.add(
      albumName: '旅行',
      event: 'bad.jpg',
      status: LogStatus.failure,
      message: '上传失败',
    );
    await logs.add(
      albumName: '工作',
      event: '远程检测',
      status: LogStatus.success,
      message: '成功',
    );
    final first = await logs.list(limit: 2);
    expect(first.map((log) => log.albumName), ['工作', '旅行']);
    expect(first.first.message, 'Success');
    expect(first.last.message, '上传失败');
    expect((await logs.list(offset: 2, limit: 2)).single.event, '远程检测');
    final failures = await logs.list(failuresOnly: true);
    expect(failures, hasLength(1));
    expect(failures.single.event, 'bad.jpg');
    expect(failures.single.createdAt.isUtc, isTrue);
    final successes = await logs.list(status: LogStatus.success);
    expect(successes.map((log) => log.event), ['远程检测', '远程检测']);
    expect(successes.map((log) => log.message), ['Success', 'Success']);
  });

  test('保留数量默认 500，仅允许 10 至 1000 条', () async {
    expect((await settings.get()).logMaxCount, 500);
    for (final value in [0, 9, 1001]) {
      await expectLater(settings.updateLogMaxCount(value), throwsRangeError);
    }
    await settings.updateLogMaxCount(10);
    expect((await settings.get()).logMaxCount, 10);
    await settings.updateLogMaxCount(500);
    expect((await settings.get()).logMaxCount, 500);
    await settings.updateLogMaxCount(1000);
    expect((await settings.get()).logMaxCount, 1000);
  });

  test('按设置自动清理最旧日志', () async {
    await settings.updateLogMaxCount(10);
    for (var index = 0; index < 15; index++) {
      await logs.add(
        albumName: '旅行',
        event: '$index.jpg',
        status: LogStatus.failure,
      );
    }
    final records = await logs.list();
    expect(records, hasLength(10));
    expect(records.first.event, '14.jpg');
    expect(records.last.event, '5.jpg');
  });

  test('写入和清空完成后发送变更通知', () async {
    final changed = logs.changes.first;
    await logs.add(
      albumName: '旅行',
      event: '远程检测',
      status: LogStatus.success,
    );
    await changed;
    final cleared = logs.changes.first;
    await logs.clear();
    await cleared;
    expect(await logs.list(), isEmpty);
  });
}
