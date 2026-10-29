import 'dart:async';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixtale_sync/db/db.dart';
import 'package:pixtale_sync/db/schema.dart';
import 'package:pixtale_sync/services/log_service.dart';
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
    var database = Db(
      factory: databaseFactoryFfi,
      databasePath: file.path,
    );
    try {
      final db = await database.database;
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final names = tables.map((table) => table['name']).toSet();
      expect(names, containsAll(['user', 'storage', 'task', 'log', 'settings']));
      expect(names, isNot(contains('album')));
      expect(names, isNot(contains('window_state')));
      expect(await db.getVersion(), 0);
      expect(
        (await db.query('settings')).single['schema_version'],
        databaseVersion,
      );
      expect((await db.query('settings')).single['log_max_count'], 500);
      expect((await db.query('settings')).single['locale'], '');
      await db.insert('task', {
        'user_id': 'user',
        'album_id': 'saved',
        'sort_time': 123,
      });
      await db.rawUpdate('UPDATE settings SET schema_version = 0 WHERE id = 1');
      await database.close();

      database = Db(factory: databaseFactoryFfi, databasePath: file.path);
      final reopened = await database.database;
      final task = (await reopened.query('task')).single;
      expect(task['album_id'], 'saved');
      expect(task['sort_time'], 123);
      expect(task['completed_count'], 0);
      expect(task['is_invalid'], 0);
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

  test('版本不一致时补齐当前结构，已有表和数据保持不变', () async {
    final directory = await Directory.systemTemp.createTemp('db_existing_');
    final file = File('${directory.path}/test.sqlite');
    final raw = await databaseFactoryFfi.openDatabase(file.path);
    await raw.setVersion(18);
    await raw.execute('''
CREATE TABLE settings (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  task_interval INTEGER NOT NULL DEFAULT 10,
  log_max_count INTEGER NOT NULL DEFAULT 500,
  task_status INTEGER NOT NULL DEFAULT 2,
  upload_concurrency INTEGER NOT NULL DEFAULT 1,
  last_sync_at TEXT,
  album_sort TEXT NOT NULL DEFAULT 'original'
);
''');
    await raw.insert('settings', {'id': 1, 'log_max_count': 200});
    await raw.execute('''
CREATE TABLE task (
  user_id TEXT NOT NULL,
  album_id TEXT NOT NULL,
  sort_time INTEGER NOT NULL,
  completed_count INTEGER NOT NULL DEFAULT 0,
  storage_id TEXT,
  album_name TEXT NOT NULL DEFAULT '',
  photo_count INTEGER NOT NULL DEFAULT 0,
  cover BLOB,
  path TEXT,
  is_invalid INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, album_id)
);
''');
    await raw.insert('task', {
      'user_id': 'user',
      'album_id': 'saved',
      'sort_time': 123,
      'completed_count': 5,
      'album_name': '旅行',
    });
    await raw.close();

    final database = Db(
      factory: databaseFactoryFfi,
      databasePath: file.path,
    );
    try {
      final db = await database.database;
      expect(await db.getVersion(), 18);
      final task = (await db.query('task')).single;
      expect(task['album_id'], 'saved');
      expect(task['completed_count'], 5);
      expect(task['album_name'], '旅行');
      final settings = (await db.query('settings')).single;
      expect(settings['schema_version'], databaseVersion);
      expect(settings['log_max_count'], 200);
      expect(settings['album_sort'], 'original');
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final names = tables.map((table) => table['name']).toSet();
      expect(names, containsAll(['user', 'storage', 'log']));
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });
}
