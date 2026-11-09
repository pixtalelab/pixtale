import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pixtale_sync/db/db.dart';
import 'package:pixtale_sync/models/rule.dart';
import 'package:pixtale_sync/request/request.dart';
import 'package:pixtale_sync/services/auth_service.dart';
import 'package:pixtale_sync/services/rule_service.dart';
import 'package:pixtale_sync/services/storage_service.dart';
import 'package:pixtale_sync/services/user_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// 验证登录请求、存储缓存、账户默认规则及失败时的事务回滚。

/// 执行登录初始化的集成测试。
void main() {
  sqfliteFfiInit();
  late Db database;
  late UserService users;
  late RuleService rules;
  late StorageService storages;
  late List<String> requests;
  late List<Map<String, Object>> remoteStorages;
  var userId = 'a';
  var storageFailed = false;

  setUp(() {
    database = Db(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    users = UserService(database: database);
    rules = RuleService(database: database);
    storages = StorageService(database: database);
    requests = [];
    remoteStorages = [
      {'storageId': 'cloud', 'name': 'Cloud', 'type': 3},
      {'storageId': 'local', 'name': 'Local disk', 'type': 1},
    ];
    userId = 'a';
    storageFailed = false;
  });
  tearDown(() => database.close());

  /// 模拟完整登录协议，存储请求始终使用本次登录的凭证。
  Future<http.Response> respond(http.Request request) async {
    requests.add(request.url.path);
    Object? data;
    switch (request.url.path) {
      case '/api/login':
        expect(jsonDecode(request.body), {
          'username': 'tester',
          'password': 'password',
        });
        data = {'token': 'token-$userId'};
      case '/api/user/info':
        expect(request.headers['authorization'], 'token-$userId');
        data = {'userId': userId, 'username': 'tester', 'type': 0};
      case '/api/storage/select':
        expect(request.headers['authorization'], 'token-$userId');
        if (storageFailed) throw const ApiException('Network error');
        data = remoteStorages;
      default:
        fail('Unexpected request: ${request.url}');
    }
    return http.Response(jsonEncode({'code': 200, 'data': data}), 200);
  }

  /// 在模拟 HTTP 客户端中执行真实登录服务。
  Future<void> login() => http.runWithClient(() async {
    final user = await AuthService(database: database).login(
      endpoint: 'https://example.test/',
      username: 'tester',
      password: 'password',
    );
    expect(user.userId, userId);
    expect(user.endpoint, 'https://example.test');
  }, () => MockClient(respond));

  test('首次登录读取并缓存远端存储，创建使用 local 的 0–200 MB 默认规则', () async {
    final userChanges = UserService.changes.value;
    final storageChanges = StorageService.changes.value;
    await login();
    expect(requests, ['/api/login', '/api/user/info', '/api/storage/select']);
    expect((await users.get())!.token, 'token-a');
    expect((await storages.list()).map((storage) => storage.id), [
      'cloud',
      'local',
    ]);
    expect((await storages.list()).last.name, 'Local disk');
    final rule = (await rules.list()).single;
    expect(rule.name, 'Default Rule');
    expect(rule.userId, 'a');
    final item = rule.items.single;
    expect(item.pid, rule.id);
    expect(item.id, isNot(rule.id));
    expect(item.fileMinSize, 0);
    expect(item.fileMaxSize, 200 * 1024 * 1024);
    expect(item.fileType, RuleFileType.any);
    expect(item.storageId, 'local');
    expect(UserService.changes.value, userChanges + 1);
    expect(StorageService.changes.value, storageChanges + 1);
  });

  test('重登刷新存储但保留自定义规则，其他账户独立创建默认规则', () async {
    await login();
    final original = (await rules.list()).single;
    await rules.remove(original.id);
    final customId = await rules.add(
      name: 'Custom',
      fileType: RuleFileType.video,
      fileMinSize: 1,
      fileMaxSize: 10,
      storageId: 'cloud',
    );
    final before = (await (await database.database).query('rule_item')).single;
    await users.remove('a');
    remoteStorages = [
      {'storageId': 'local', 'name': 'Renamed disk', 'type': 1},
    ];
    await login();
    expect((await rules.list()).single.id, customId);
    expect((await rules.list()).single.name, 'Custom');
    expect((await (await database.database).query('rule_item')).single, before);
    expect((await storages.list()).single.name, 'Renamed disk');
    await users.remove('a');
    userId = 'b';
    await login();
    expect((await rules.list()).single.name, 'Default Rule');
    expect((await rules.list()).single.userId, 'b');
    expect(await (await database.database).query('rule'), hasLength(2));
  });

  test('删除所有规则后重新登录会恢复默认规则，连续登录不重复创建', () async {
    await login();
    await rules.remove((await rules.list()).single.id);
    await login();
    final id = (await rules.list()).single.id;
    await login();
    expect((await rules.list()).single.id, id);
    expect(await (await database.database).query('rule_item'), hasLength(1));
  });

  test('远端存储读取失败时保留原账户、缓存及规则，不发布登录通知', () async {
    await login();
    final oldRuleId = (await rules.list()).single.id;
    final userChanges = UserService.changes.value;
    final storageChanges = StorageService.changes.value;
    userId = 'b';
    storageFailed = true;
    await expectLater(login(), throwsA(isA<ApiException>()));
    expect((await users.get())!.userId, 'a');
    expect((await storages.list()).map((storage) => storage.id), [
      'cloud',
      'local',
    ]);
    expect((await rules.list()).single.id, oldRuleId);
    expect(UserService.changes.value, userChanges);
    expect(StorageService.changes.value, storageChanges);
  });

  test('默认子规则保存失败时回滚用户与存储，重试后完整保存', () async {
    final db = await database.database;
    await db.execute('''
CREATE TRIGGER reject_rule_item BEFORE INSERT ON rule_item
BEGIN SELECT RAISE(ABORT, 'test failure'); END;
''');
    final userChanges = UserService.changes.value;
    final storageChanges = StorageService.changes.value;
    await expectLater(login(), throwsA(isA<DatabaseException>()));
    for (final table in ['user', 'storage', 'rule', 'rule_item']) {
      expect(await db.query(table), isEmpty);
    }
    expect(UserService.changes.value, userChanges);
    expect(StorageService.changes.value, storageChanges);
    await db.execute('DROP TRIGGER reject_rule_item');
    await login();
    expect((await users.get())!.userId, 'a');
    expect(await storages.list(), hasLength(2));
    expect((await rules.list()).single.items, hasLength(1));
  });
}
