import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixtale_sync/db/db.dart';
import 'package:pixtale_sync/db/schema.dart';
import 'package:pixtale_sync/models/rule.dart';
import 'package:pixtale_sync/models/user.dart';
import 'package:pixtale_sync/request/request.dart';
import 'package:pixtale_sync/services/rule_service.dart';
import 'package:pixtale_sync/services/user_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  const mb = 1024 * 1024;
  final uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('模板和规则使用独立 UUID，追加顺序及内容在重开后保留', () async {
    final directory = await Directory.systemTemp.createTemp('rules_');
    final path = '${directory.path}/test.sqlite';
    var database = Db(factory: databaseFactoryFfi, databasePath: path);
    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });
    await _signIn(database);
    var service = RuleService(database: database);
    final id = await service.add(
      name: '  旅行备份  ',
      fileType: RuleFileType.video,
      fileMinSize: 20 * mb,
      fileMaxSize: 30 * mb,
      storageId: 'video-cloud',
    );
    for (final type in [RuleFileType.photo, RuleFileType.any]) {
      await service.addItem(
        pid: id,
        fileType: type,
        fileMinSize: 0,
        fileMaxSize: mb ~/ 2,
        storageId: 'photo-cloud',
      );
    }
    await database.close();
    database = Db(factory: databaseFactoryFfi, databasePath: path);
    service = RuleService(database: database);
    final rule = (await service.list()).single;
    expect(rule.id, matches(uuid));
    expect(rule.userId, 'user');
    expect(rule.name, '旅行备份');
    expect(
      rule.sortTime,
      closeTo(DateTime.now().millisecondsSinceEpoch ~/ 1000, 10),
    );
    expect(rule.items.map((item) => item.fileType), [
      RuleFileType.video,
      RuleFileType.photo,
      RuleFileType.any,
    ]);
    expect(rule.items.map((item) => item.id).toSet(), hasLength(3));
    for (final item in rule.items) {
      expect(item.id, matches(uuid));
      expect(item.id, isNot(id));
      expect(item.pid, id);
      expect(item.createdAt.isUtc, isTrue);
    }
    expect(rule.items.first.fileMinSize, 20 * mb);
    expect(rule.items.first.fileMaxSize, 30 * mb);
    expect(rule.items.first.storageId, 'video-cloud');
    expect(rule.items.last.fileMaxSize, mb ~/ 2);
  });

  test('创建首条规则失败回滚模板，拒绝无效范围和不存在的父模板', () async {
    final database = Db(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(database.close);
    final db = await database.database;
    await _signIn(database);
    final service = RuleService(database: database);
    await db.execute('''
CREATE TRIGGER reject_rule_item BEFORE INSERT ON rule_item
BEGIN SELECT RAISE(ABORT, 'test failure'); END;
''');
    await expectLater(
      service.add(
        name: '失败',
        fileType: RuleFileType.any,
        fileMinSize: 0,
        fileMaxSize: mb,
        storageId: 'cloud',
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect(await db.query('rule'), isEmpty);
    expect(await db.query('rule_item'), isEmpty);
    await db.execute('DROP TRIGGER reject_rule_item');
    await expectLater(
      service.add(
        name: ' ',
        fileType: RuleFileType.any,
        fileMinSize: 0,
        fileMaxSize: mb,
        storageId: 'cloud',
      ),
      throwsArgumentError,
    );
    await expectLater(
      service.add(
        name: '无效',
        fileType: RuleFileType.any,
        fileMinSize: 2,
        fileMaxSize: 1,
        storageId: 'cloud',
      ),
      throwsArgumentError,
    );
    await expectLater(
      service.add(
        name: '无效',
        fileType: RuleFileType.any,
        fileMinSize: -1,
        fileMaxSize: mb,
        storageId: 'cloud',
      ),
      throwsArgumentError,
    );
    await expectLater(
      service.add(
        name: '无效',
        fileType: RuleFileType.any,
        fileMinSize: 0,
        fileMaxSize: mb,
        storageId: '',
      ),
      throwsArgumentError,
    );
    await expectLater(
      service.addItem(
        pid: 'missing',
        fileType: RuleFileType.any,
        fileMinSize: 0,
        fileMaxSize: mb,
        storageId: 'cloud',
      ),
      throwsStateError,
    );
    expect(await db.query('rule_item'), isEmpty);
  });

  test('修改保留规则标识、创建时间和顺序，删除只影响指定规则并持久化', () async {
    final directory = await Directory.systemTemp.createTemp('rules_edit_');
    final path = '${directory.path}/test.sqlite';
    var database = Db(factory: databaseFactoryFfi, databasePath: path);
    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });
    await _signIn(database);
    var service = RuleService(database: database);
    final pid = await service.add(
      name: '旅行',
      fileType: RuleFileType.video,
      fileMinSize: 20 * mb,
      fileMaxSize: 30 * mb,
      storageId: 'video',
    );
    await service.addItem(
      pid: pid,
      fileType: RuleFileType.any,
      fileMinSize: 0,
      fileMaxSize: mb,
      storageId: 'other',
    );
    final before = (await service.list()).single;
    final first = before.items.first;
    final second = before.items.last;
    await expectLater(
      service.updateItem(
        id: first.id,
        pid: 'wrong',
        fileType: RuleFileType.photo,
        fileMinSize: 25 * mb,
        fileMaxSize: 35 * mb,
        storageId: 'photos',
      ),
      throwsStateError,
    );
    await expectLater(
      service.updateItem(
        id: first.id,
        pid: pid,
        fileType: RuleFileType.photo,
        fileMinSize: 35 * mb,
        fileMaxSize: 25 * mb,
        storageId: 'photos',
      ),
      throwsArgumentError,
    );
    await service.updateItem(
      id: first.id,
      pid: pid,
      fileType: RuleFileType.photo,
      fileMinSize: 25 * mb,
      fileMaxSize: 35 * mb,
      storageId: 'photos',
    );
    await database.close();
    database = Db(factory: databaseFactoryFfi, databasePath: path);
    service = RuleService(database: database);
    final after = (await service.list()).single;
    expect(after.items.map((item) => item.id), [first.id, second.id]);
    expect(after.sortTime, before.sortTime);
    expect(after.items.first.createdAt, first.createdAt);
    expect(after.items.first.fileType, RuleFileType.photo);
    expect(after.items.first.fileMinSize, 25 * mb);
    expect(after.items.first.fileMaxSize, 35 * mb);
    expect(after.items.first.storageId, 'photos');
    expect(after.items.last.storageId, second.storageId);
    await expectLater(
      service.removeItem(id: first.id, pid: 'wrong'),
      throwsStateError,
    );
    await service.removeItem(id: first.id, pid: pid);
    expect((await service.list()).single.items.single.id, second.id);
    await service.removeItem(id: second.id, pid: pid);
    await database.close();
    database = Db(factory: databaseFactoryFfi, databasePath: path);
    service = RuleService(database: database);
    final empty = (await service.list()).single;
    expect(empty.id, pid);
    expect(empty.name, '旅行');
    expect(empty.items, isEmpty);
  });

  test('重命名只修改名称，删除模板事务清理子规则且不影响其他模板', () async {
    final directory = await Directory.systemTemp.createTemp('rules_remove_');
    final path = '${directory.path}/test.sqlite';
    var database = Db(factory: databaseFactoryFfi, databasePath: path);
    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });
    await _signIn(database);
    var service = RuleService(database: database);
    final id = await service.add(
      name: '旅行',
      fileType: RuleFileType.video,
      fileMinSize: 20 * mb,
      fileMaxSize: 30 * mb,
      storageId: 'video',
    );
    await service.addItem(
      pid: id,
      fileType: RuleFileType.photo,
      fileMinSize: 0,
      fileMaxSize: mb,
      storageId: 'photos',
    );
    final otherId = await service.add(
      name: '其他模板',
      fileType: RuleFileType.any,
      fileMinSize: 0,
      fileMaxSize: mb,
      storageId: 'other',
    );
    final before = (await service.list()).first;
    var db = await database.database;
    final rules = await db.query('rule_item', orderBy: 'rowid');
    await expectLater(service.rename(id: id, name: ' '), throwsArgumentError);
    await expectLater(
      service.rename(id: 'missing', name: '名称'),
      throwsStateError,
    );
    await service.rename(id: id, name: '  新的模板  ');
    await database.close();
    database = Db(factory: databaseFactoryFfi, databasePath: path);
    service = RuleService(database: database);
    db = await database.database;
    final after = (await service.list()).first;
    expect(after.id, before.id);
    expect(after.name, '新的模板');
    expect(after.sortTime, before.sortTime);
    expect(await db.query('rule_item', orderBy: 'rowid'), rules);
    await db.execute('''
CREATE TRIGGER reject_rule_delete BEFORE DELETE ON rule
BEGIN SELECT RAISE(ABORT, 'test failure'); END;
''');
    await expectLater(service.remove(id), throwsA(isA<DatabaseException>()));
    expect(await db.query('rule_item', orderBy: 'rowid'), rules);
    expect(await service.list(), hasLength(2));
    await db.execute('DROP TRIGGER reject_rule_delete');
    await service.remove(id);
    await database.close();
    database = Db(factory: databaseFactoryFfi, databasePath: path);
    service = RuleService(database: database);
    db = await database.database;
    expect((await service.list()).single.id, otherId);
    expect((await db.query('rule_item')).single['pid'], otherId);
    await expectLater(service.remove('missing'), throwsStateError);
    expect((await service.list()).single.name, '其他模板');
  });

  test('模板和规则按用户隔离，退出后不可读写，重新登录恢复原数据', () async {
    final database = Db(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(database.close);
    final users = UserService(database: database);
    final service = RuleService(database: database);
    expect(await service.list(), isEmpty);
    await expectLater(
      service.add(
        name: '未登录',
        fileType: RuleFileType.any,
        fileMinSize: 0,
        fileMaxSize: mb,
        storageId: 'cloud',
      ),
      throwsA(isA<ApiException>()),
    );
    await _signIn(database, 'a');
    final id = await service.add(
      name: 'A 的模板',
      fileType: RuleFileType.video,
      fileMinSize: 20 * mb,
      fileMaxSize: 30 * mb,
      storageId: 'a-cloud',
    );
    final item = (await service.list()).single.items.single;
    await users.remove('a');
    expect(await service.list(), isEmpty);
    await expectLater(
      service.rename(id: id, name: '未登录修改'),
      throwsA(isA<ApiException>()),
    );
    await expectLater(service.remove(id), throwsA(isA<ApiException>()));
    await _signIn(database, 'b');
    expect(await service.list(), isEmpty);
    await expectLater(
      service.addItem(
        pid: id,
        fileType: RuleFileType.any,
        fileMinSize: 0,
        fileMaxSize: mb,
        storageId: 'b-cloud',
      ),
      throwsStateError,
    );
    await expectLater(service.rename(id: id, name: '跨账户修改'), throwsStateError);
    await expectLater(service.remove(id), throwsStateError);
    await expectLater(
      service.updateItem(
        id: item.id,
        pid: id,
        fileType: RuleFileType.any,
        fileMinSize: 0,
        fileMaxSize: mb,
        storageId: 'b-cloud',
      ),
      throwsStateError,
    );
    await expectLater(
      service.removeItem(id: item.id, pid: id),
      throwsStateError,
    );
    final bId = await service.add(
      name: 'B 的模板',
      fileType: RuleFileType.photo,
      fileMinSize: 0,
      fileMaxSize: mb,
      storageId: 'b-cloud',
    );
    expect((await service.list()).single.userId, 'b');
    await users.remove('b');
    await _signIn(database, 'a');
    final restored = (await service.list()).single;
    expect(restored.id, id);
    expect(restored.userId, 'a');
    expect(restored.name, 'A 的模板');
    expect(restored.items.single.id, item.id);
    expect(restored.items.single.storageId, 'a-cloud');
    await service.remove(id);
    final db = await database.database;
    expect((await db.query('rule')).single['id'], bId);
    expect((await db.query('rule_item')).single['pid'], bId);
  });

  test('按 sort_time 升序，置顶使用当前账户最小值减一且重开后保留', () async {
    final directory = await Directory.systemTemp.createTemp('rules_pin_');
    final path = '${directory.path}/test.sqlite';
    var database = Db(factory: databaseFactoryFfi, databasePath: path);
    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });
    await _signIn(database, 'a');
    var service = RuleService(database: database);
    Future<String> add(String name) => service.add(
      name: name,
      fileType: RuleFileType.any,
      fileMinSize: 0,
      fileMaxSize: mb,
      storageId: 'cloud',
    );
    final first = await add('先添加');
    final second = await add('后添加');
    var db = await database.database;
    await db.update(
      'rule',
      {'sort_time': 200},
      where: 'id = ?',
      whereArgs: [first],
    );
    await db.update(
      'rule',
      {'sort_time': 100},
      where: 'id = ?',
      whereArgs: [second],
    );
    expect((await service.list()).map((rule) => rule.id), [second, first]);
    final rules = await db.query('rule_item', orderBy: 'rowid');
    final users = UserService(database: database);
    await users.remove('a');
    await _signIn(database, 'b');
    final other = await add('B 的模板');
    await db.update(
      'rule',
      {'sort_time': -1000},
      where: 'id = ?',
      whereArgs: [other],
    );
    await expectLater(service.pin(first), throwsStateError);
    await users.remove('b');
    await expectLater(service.pin(first), throwsA(isA<ApiException>()));
    await _signIn(database, 'a');
    await expectLater(service.pin('missing'), throwsStateError);
    await service.pin(first);
    expect((await service.list()).map((rule) => rule.id), [first, second]);
    expect((await service.list()).first.sortTime, 99);
    await service.pin(second);
    expect((await service.list()).first.id, second);
    expect((await service.list()).first.sortTime, 98);
    await service.pin(second);
    expect((await service.list()).first.sortTime, 97);
    expect(
      await db.query(
        'rule_item',
        where: 'pid IN (?, ?)',
        whereArgs: [first, second],
        orderBy: 'rowid',
      ),
      rules,
    );
    expect(
      (await db.query(
        'rule',
        where: 'id = ?',
        whereArgs: [other],
      )).single['sort_time'],
      -1000,
    );
    await database.close();
    database = Db(factory: databaseFactoryFfi, databasePath: path);
    service = RuleService(database: database);
    expect((await service.list()).map((rule) => rule.id), [second, first]);
    expect((await service.list()).first.sortTime, 97);
    await service.rename(id: second, name: '置顶后改名');
    expect((await service.list()).first.sortTime, 97);
  });

  test('版本 20 的数据库清空后重建规则表，重新登录后可新增规则', () async {
    final directory = await Directory.systemTemp.createTemp('rules_migrate_');
    final path = '${directory.path}/test.sqlite';
    var database = Db(factory: databaseFactoryFfi, databasePath: path);
    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });
    await _signIn(database);
    final old = await database.database;
    await old.execute('DROP TABLE rule_item');
    await old.execute('DROP TABLE rule');
    await old.update('settings', {'schema_version': 20, 'log_max_count': 444});
    await old.insert('task', {
      'user_id': 'user',
      'album_id': 'album',
      'sort_time': 123,
    });
    await database.close();
    database = Db(factory: databaseFactoryFfi, databasePath: path);
    final db = await database.database;
    expect(
      (await db.query('settings')).single['schema_version'],
      databaseVersion,
    );
    expect((await db.query('settings')).single['log_max_count'], 500);
    expect(await db.query('task'), isEmpty);
    expect(await db.query('user'), isEmpty);
    expect(await db.query('rule'), isEmpty);
    expect(await db.query('rule_item'), isEmpty);
    final columns = await db.rawQuery('PRAGMA table_info(rule)');
    expect(columns.map((column) => column['name']), [
      'id',
      'user_id',
      'name',
      'sort_time',
    ]);
    expect(
      columns.singleWhere((column) => column['name'] == 'sort_time')['type'],
      'INTEGER',
    );
    final indexes = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index'",
    );
    expect(
      indexes.map((index) => index['name']),
      containsAll(['rule_user_id', 'rule_item_pid']),
    );
    final foreignKeys = await db.rawQuery('PRAGMA foreign_key_list(rule_item)');
    expect(foreignKeys.single['table'], 'rule');
    expect(foreignKeys.single['from'], 'pid');
    expect(foreignKeys.single['to'], 'id');
    await _signIn(database);
    final id = await RuleService(database: database).add(
      name: '升级后新增',
      fileType: RuleFileType.video,
      fileMinSize: 20 * mb,
      fileMaxSize: 30 * mb,
      storageId: 'cloud',
    );
    final rule = (await RuleService(database: database).list()).single;
    expect(rule.id, id);
    expect(rule.userId, 'user');
    expect(rule.items.single.fileMaxSize, 30 * mb);
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    await database.close();
    database = Db(factory: databaseFactoryFfi, databasePath: path);
    final reopened = (await RuleService(database: database).list()).single;
    expect(reopened.id, id);
    expect(reopened.sortTime, rule.sortTime);
    expect(reopened.items.single.id, rule.items.single.id);
  });
}

Future<void> _signIn(Db database, [String id = 'user']) =>
    UserService(database: database).add(
      User(
        userId: id,
        username: id,
        avatar: '',
        type: 0,
        token: 'token',
        endpoint: 'https://example.com',
      ),
    );
