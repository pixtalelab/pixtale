import 'dart:async';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixtale_sync/db/db.dart';
import 'package:pixtale_sync/db/schema.dart';
import 'package:pixtale_sync/services/log_service.dart';
import 'package:pixtale_sync/services/settings_service.dart';
import 'package:pixtale_sync/services/user_service.dart';
import 'package:pixtale_sync/models/log.dart';

// 验证当前结构会初始化，并在再次打开时保留已有数据。

/// 执行数据库结构测试。
void main() {
  sqfliteFfiInit();

  test('同文件的服务复用连接，事务期间的日志和用户查询排队完成', () async {
    final directory = await Directory.systemTemp.createTemp('db_concurrent_');
    final file = File('${directory.path}/test.sqlite');
    final foreground = Db(factory: databaseFactoryFfi, databasePath: file.path);
    final background = Db(factory: databaseFactoryFfi, databasePath: file.path);
    final entered = Completer<void>();
    final release = Completer<void>();
    Future<void>? transaction;
    try {
      final connections = await Future.wait([
        foreground.database,
        background.database,
      ]);
      expect(connections[0], same(connections[1]));
      transaction = connections[0].transaction((txn) async {
        await txn.update('settings', {'task_status': 1});
        entered.complete();
        await release.future;
        await txn.update('settings', {'task_status': 2});
      });
      await entered.future;
      final logs = LogService(database: background);
      final write = logs.add(
        albumName: '全部相册',
        event: '开始同步',
        status: LogStatus.success,
      );
      final read = UserService(database: foreground).get();
      release.complete();
      await Future.wait([transaction, write, read])
          .timeout(const Duration(seconds: 5));
      final records = await logs.list();
      expect(records.single.event, '开始同步');
      expect(records.single.status, LogStatus.success);
      expect(records.single.message, 'Success');
    } finally {
      if (!release.isCompleted) release.complete();
      await transaction;
      await foreground.close();
      await background.close();
      await directory.delete(recursive: true);
    }
  });

  test('新库使用当前结构，再次打开保留任务且不重复设置', () async {
    final directory = await Directory.systemTemp.createTemp('db_schema_');
    final file = File('${directory.path}/test.sqlite');
    var database = Db(factory: databaseFactoryFfi, databasePath: file.path);
    try {
      final db = await database.database;
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final names = tables.map((table) => table['name']).toSet();
      expect(
        names,
        containsAll([
          'user',
          'storage',
          'task',
          'log',
          'settings',
          'rule',
          'rule_item',
        ]),
      );
      expect(names, isNot(contains('album')));
      expect(names, isNot(contains('window_state')));
      expect(names, isNot(contains('template')));
      expect(names, isNot(contains('template_item')));
      expect(await db.getVersion(), 0);
      expect(
        (await db.query('settings')).single['schema_version'],
        databaseVersion,
      );
      expect((await db.query('settings')).single['log_max_count'], 500);
      expect((await db.query('settings')).single['locale'], '');
      expect((await db.query('settings')).single['id'], 'setting');
      final columns = await db.rawQuery('PRAGMA table_info(settings)');
      expect(
        columns.firstWhere((column) => column['name'] == 'id')['type'],
        'TEXT',
      );
      await expectLater(
        db.insert('settings', {'id': 'other'}),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        (await db.query('settings')).single.containsKey('file_limit_mb'),
        isFalse,
      );
      await db.insert('task', {
        'user_id': 'user',
        'album_id': 'saved',
        'sort_time': 123,
      });
      await database.close();

      database = Db(factory: databaseFactoryFfi, databasePath: file.path);
      final reopened = await database.database;
      final task = (await reopened.query('task')).single;
      expect(task['album_id'], 'saved');
      expect(task['sort_time'], 123);
      expect(task['completed_count'], 0);
      expect(task['is_invalid'], 0);
      expect(task.containsKey('rule_id'), isTrue);
      expect(task.containsKey('storage_id'), isFalse);
      expect(await reopened.query('settings'), hasLength(1));
      expect(
        (await reopened.query('settings')).single['schema_version'],
        databaseVersion,
      );
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });

  for (final version in [0, 21]) {
    test('版本 $version 清空所有旧表，按最新结构重建', () async {
      final directory = await Directory.systemTemp.createTemp('db_reset_');
      final file = File('${directory.path}/test.sqlite');
      final database = Db(factory: databaseFactoryFfi, databasePath: file.path);
      try {
        final raw = await databaseFactoryFfi.openDatabase(file.path);
        await _createOldSchema(raw, version);
        await _seedData(raw);
        await raw.execute('ALTER TABLE task ADD COLUMN storage_id TEXT');
        await raw.execute(
          'ALTER TABLE settings ADD COLUMN file_limit_mb INTEGER',
        );
        await raw.execute(
          'CREATE TABLE "legacy""table" (id INTEGER PRIMARY KEY)',
        );
        await raw.execute('CREATE INDEX legacy_index ON "legacy""table"(id)');
        await raw.close();

        final db = await database.database;
        final names = (await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT GLOB 'sqlite_*'",
        )).map((table) => table['name']).toSet();
        expect(names, {
          'user',
          'storage',
          'task',
          'log',
          'settings',
          'rule',
          'rule_item',
        });
        for (final table in [
          'user',
          'storage',
          'task',
          'log',
          'rule',
          'rule_item',
        ]) {
          expect(await db.query(table), isEmpty, reason: table);
        }
        final settings = (await db.query('settings')).single;
        expect(settings['id'], 'setting');
        expect(settings['schema_version'], databaseVersion);
        expect(settings['log_max_count'], 500);
        expect(settings.containsKey('file_limit_mb'), isFalse);
        final taskColumns = await db.rawQuery('PRAGMA table_info(task)');
        expect(
          taskColumns.map((column) => column['name']),
          isNot(contains('storage_id')),
        );
        final indexes = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'index'",
        );
        expect(
          indexes.map((index) => index['name']),
          isNot(contains('legacy_index')),
        );
      } finally {
        await database.close();
        await directory.delete(recursive: true);
      }
    });
  }

  test('缺少版本列的旧库按版本 0 清空重建', () async {
    final directory = await Directory.systemTemp.createTemp('db_unversioned_');
    final file = File('${directory.path}/test.sqlite');
    final database = Db(factory: databaseFactoryFfi, databasePath: file.path);
    try {
      final raw = await databaseFactoryFfi.openDatabase(file.path);
      await raw.execute('CREATE TABLE settings (id INTEGER PRIMARY KEY)');
      await raw.insert('settings', {'id': 1});
      await raw.execute('CREATE TABLE legacy (id INTEGER PRIMARY KEY)');
      await raw.close();
      final db = await database.database;
      expect((await db.query('settings')).single['id'], 'setting');
      expect(
        (await db.query('settings')).single['schema_version'],
        databaseVersion,
      );
      expect(
        await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE name = 'legacy'",
        ),
        isEmpty,
      );
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });

  for (final version in [22, 23]) {
    test('版本 $version 直接使用已有数据库，不处理旧结构', () async {
      final directory = await Directory.systemTemp.createTemp('db_no_migrate_');
      final file = File('${directory.path}/test.sqlite');
      final database = Db(factory: databaseFactoryFfi, databasePath: file.path);
      try {
        final raw = await databaseFactoryFfi.openDatabase(file.path);
        await _createOldSchema(raw, version);
        await _seedData(raw);
        final saved = <String, List<Map<String, Object?>>>{};
        for (final table in [
          'settings',
          'user',
          'storage',
          'task',
          'log',
          'rule',
          'rule_item',
        ]) {
          saved[table] = await raw.query(table);
        }
        await raw.close();

        final db = await database.database;
        for (final entry in saved.entries) {
          expect(await db.query(entry.key), entry.value, reason: entry.key);
        }
      } finally {
        await database.close();
        await directory.delete(recursive: true);
      }
    });
  }

  test('新设置记录以 setting 为主键读写', () async {
    final database = Db(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    try {
      final settings = SettingsService(database: database);
      await settings.updateTaskInterval(5);
      await settings.updateLogMaxCount(10);
      await settings.updateTaskStatus(1);
      await settings.updateUploadConcurrency(2);
      await settings.updateLocale('zh');
      await settings.updateLastSyncAt();
      final values = await settings.get();
      expect(values.taskInterval, 5);
      expect(values.logMaxCount, 10);
      expect(values.taskStatus, 1);
      expect(values.uploadConcurrency, 2);
      expect(values.locale, 'zh');
      expect(values.lastSyncAt, isNotNull);
      final rows = await (await database.database).query('settings');
      expect(rows, hasLength(1));
      expect(rows.single['id'], 'setting');
    } finally {
      await database.close();
    }
  });
}

/// 旧日志创建时间样本。
const _logTimes = [
  '2026-11-10T12:00:00.123001Z',
  '2026-11-10T20:00:00.123+08:00',
  '2026-11-10T12:00:00.123001Z',
];

/// 构造带整数设置主键和自增日志主键的旧库，验证版本处理边界。
Future<void> _createOldSchema(Database db, int version) async {
  for (final statement in databaseSchema) {
    if (statement.startsWith('INSERT OR IGNORE INTO settings')) continue;
    if (statement.contains('CREATE TABLE IF NOT EXISTS settings (')) {
      await db.execute(
        statement.replaceFirst(
          "id TEXT NOT NULL PRIMARY KEY CHECK (id = '$settingsId')",
          'id INTEGER PRIMARY KEY CHECK (id = 1)',
        ),
      );
    } else if (statement.contains('CREATE TABLE IF NOT EXISTS log (')) {
      await db.execute(
        statement.replaceFirst(
          'id TEXT PRIMARY KEY',
          'id INTEGER PRIMARY KEY AUTOINCREMENT',
        ),
      );
    } else {
      await db.execute(statement);
    }
  }
  await db.insert('settings', {
    'id': 1,
    'schema_version': version,
    'task_interval': 15,
    'log_max_count': 200,
    'task_status': 1,
    'upload_concurrency': 3,
    'last_sync_at': '2026-11-09T12:00:00Z',
    'locale': 'en',
  });
}

/// 各业务表保存关联数据，区分重建清空和保留升级。
Future<void> _seedData(Database db) async {
  await db.insert('user', {
    'user_id': 'user',
    'username': '用户',
    'token': 'token',
  });
  await db.insert('storage', {
    'user_id': 'user',
    'storage_id': 'local',
    'name': '本地',
    'type': 0,
  });
  await db.insert('rule', {
    'id': 'rule',
    'user_id': 'user',
    'name': '规则',
    'sort_time': 123,
  });
  await db.insert('rule_item', {
    'id': 'item',
    'pid': 'rule',
    'file_type': 'any',
    'file_min_size': 0,
    'file_max_size': 200,
    'storage_id': 'local',
    'created_at': _logTimes[0],
  });
  await db.insert('task', {
    'user_id': 'user',
    'album_id': 'saved',
    'sort_time': 123,
    'rule_id': 'rule',
  });
  final logColumns = await db.rawQuery('PRAGMA table_info(log)');
  final integerId = logColumns.first['type'] == 'INTEGER';
  for (var index = 0; index < _logTimes.length; index++) {
    await db.insert('log', {
      if (!integerId) 'id': '00000000-0000-4000-8000-00000000000$index',
      'album_name': '旅行',
      'event': '$index.jpg',
      'status': LogStatus.failure,
      'message': '上传失败 $index',
      'created_at': integerId
          ? _logTimes[index]
          : Log.encodeTime(DateTime.parse(_logTimes[index])),
    });
  }
}
