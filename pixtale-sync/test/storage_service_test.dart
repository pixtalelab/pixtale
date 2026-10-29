import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pixtale_sync/db/db.dart';
import 'package:pixtale_sync/models/storage.dart';
import 'package:pixtale_sync/models/user.dart';
import 'package:pixtale_sync/providers/storage_provider.dart';
import 'package:pixtale_sync/request/request.dart';
import 'package:pixtale_sync/services/storage_service.dart';
import 'package:pixtale_sync/services/user_service.dart';

// 验证存储缓存、远端替换、账户隔离及单选状态。

/// 执行存储业务和页面状态测试。
void main() {
  sqfliteFfiInit();
  const old = Storage(id: 'old', name: '旧存储', type: 1);
  const latest = Storage(id: 'cloud', name: '云存储', type: 3);
  late Db database;
  late UserService users;

  setUp(() async {
    database = Db(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    users = UserService(database: database);
    await users.add(account());
  });
  tearDown(() => database.close());

  test('缓存保持远端排序，刷新完整替换，网络失败保留旧缓存', () async {
    var values = [latest, old];
    var failed = false;
    final service = StorageService(
      database: database,
      fetch: (_) async {
        if (failed) throw const ApiException('网络异常');
        return values;
      },
    );
    await service.refresh();
    expect((await service.list()).map((item) => item.id), ['cloud', 'old']);
    values = [old];
    await service.refresh();
    failed = true;
    await expectLater(service.refresh(), throwsA(isA<ApiException>()));
    expect((await service.list()).single.name, '旧存储');
    failed = false;
    values = [];
    await service.refresh();
    expect(await service.list(), isEmpty);
  });

  test('同一用户跨端点共用缓存，切换端点后丢弃旧请求', () async {
    final pending = Completer<List<Storage>>();
    final requested = Completer<void>();
    var fetch = () async => [old];
    final service = StorageService(database: database, fetch: (_) => fetch());
    await service.refresh();
    await users.remove('user');
    await users.add(account(endpoint: 'https://other.test'));
    expect((await service.list()).single.id, 'old');
    fetch = () {
      requested.complete();
      return pending.future;
    };
    final refresh = service.refresh();
    final rejected = expectLater(refresh, throwsA(isA<ApiException>()));
    await requested.future;
    await users.remove('user');
    await users.add(account());
    pending.complete([latest]);
    await rejected;
    expect((await service.list()).single.id, 'old');
    await users.remove('user');
    expect(await service.list(), isEmpty);
  });

  test('不同用户缓存独立，刷新只替换当前用户的数据', () async {
    var values = [old];
    final service = StorageService(
      database: database,
      fetch: (_) async => values,
    );
    await service.refresh();
    await users.remove('user');
    await users.add(account(userId: 'other'));
    expect(await service.list(), isEmpty);
    values = [latest];
    await service.refresh();
    expect((await service.list()).single.id, 'cloud');
    await users.remove('other');
    await users.add(account(endpoint: 'https://other.test'));
    expect((await service.list()).single.id, 'old');
    values = [];
    await service.refresh();
    expect(await service.list(), isEmpty);
    await users.remove('user');
    await users.add(account(userId: 'other'));
    expect((await service.list()).single.id, 'cloud');
  });

  test('先发布缓存并默认选择首项，刷新保留有效选择，移除后选择新首项', () async {
    final seeded = StorageService(
      database: database,
      fetch: (_) async => [old],
    );
    await seeded.refresh();
    var pending = Completer<List<Storage>>();
    final service = StorageService(
      database: database,
      fetch: (_) => pending.future,
    );
    final provider = StorageProvider(service);
    addTearDown(provider.dispose);
    final cached = Completer<void>();
    provider.addListener(() {
      if (provider.items.isNotEmpty && !cached.isCompleted) cached.complete();
    });
    final loading = provider.load();
    expect(provider.load(), same(loading));
    await cached.future;
    expect(provider.items.single.name, '旧存储');
    expect(provider.selected?.id, 'old');
    expect(provider.loading, isTrue);
    provider.select('old');
    pending.complete([const Storage(id: 'old', name: '新名称', type: 1), latest]);
    await loading;
    expect(provider.selected?.name, '新名称');
    expect((await service.list()).map((item) => item.name), ['新名称', '云存储']);
    pending = Completer<List<Storage>>();
    final removing = provider.load();
    pending.complete([latest]);
    await removing;
    expect(provider.selected?.id, 'cloud');
    expect(provider.items.single.id, 'cloud');
  });

  test('刷新失败不清空可选缓存', () async {
    await StorageService(
      database: database,
      fetch: (_) async => [old],
    ).refresh();
    final provider = StorageProvider(
      StorageService(
        database: database,
        fetch: (_) async => throw const ApiException('网络异常'),
      ),
    );
    addTearDown(provider.dispose);
    await provider.load();
    expect(provider.items.single.id, 'old');
    expect(provider.error, '网络异常');
    expect(provider.loading, isFalse);
  });
}

/// 创建存储缓存测试使用的登录账户。
User account({
  String endpoint = 'https://example.test',
  String userId = 'user',
}) => User(
  userId: userId,
  username: 'tester',
  avatar: '',
  type: 0,
  token: 'token',
  endpoint: endpoint,
);
