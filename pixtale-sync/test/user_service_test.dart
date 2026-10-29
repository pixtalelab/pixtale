import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pixtale_sync/db/db.dart';
import 'package:pixtale_sync/models/user.dart';
import 'package:pixtale_sync/request/request.dart';
import 'package:pixtale_sync/services/user_service.dart';

// 验证头像缓存、静默刷新及账户切换后的请求隔离。

/// 执行用户头像缓存测试。
void main() {
  sqfliteFfiInit();
  late Db database;

  setUp(() {
    database = Db(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
  });
  tearDown(() => database.close());

  test('先读取旧头像，远端刷新后持久化，相同图片复用缓存对象', () async {
    var bytes = [1, 2, 3];
    final users = UserService(
      database: database,
      fetchAvatar: (_) async => bytes,
    );
    await users.add(_account());
    expect((await users.get())!.avatarBytes, isNull);
    await users.refreshAvatar((await users.get())!);
    final cached = (await users.get())!;
    expect(cached.avatarBytes, [1, 2, 3]);
    expect(await users.refreshAvatar(cached), same(cached.avatarBytes));
    bytes = [4, 5, 6];
    expect(await users.refreshAvatar(cached), [4, 5, 6]);
    expect((await users.get())!.avatarBytes, [4, 5, 6]);
  });

  test('头像请求失败或返回空数据时保留旧缓存', () async {
    var failed = false;
    var bytes = [1, 2, 3];
    final users = UserService(
      database: database,
      fetchAvatar: (_) async {
        if (failed) throw const ApiException('网络异常');
        return bytes;
      },
    );
    await users.add(_account());
    await users.refreshAvatar((await users.get())!);
    final cached = (await users.get())!;
    failed = true;
    await expectLater(
      users.refreshAvatar(cached),
      throwsA(isA<ApiException>()),
    );
    expect((await users.get())!.avatarBytes, [1, 2, 3]);
    failed = false;
    bytes = [];
    expect(await users.refreshAvatar(cached), same(cached.avatarBytes));
    expect((await users.get())!.avatarBytes, [1, 2, 3]);
  });

  test('同一用户同一头像保留缓存，更换或移除头像时清除旧图', () async {
    final users = UserService(
      database: database,
      fetchAvatar: (_) async => [1, 2, 3],
    );
    await users.add(_account());
    await users.refreshAvatar((await users.get())!);
    await users.add(_account(endpoint: 'https://other.test'));
    expect((await users.get())!.avatarBytes, [1, 2, 3]);
    await users.add(_account(avatar: 'new'));
    expect((await users.get())!.avatarBytes, isNull);
    await users.refreshAvatar((await users.get())!);
    await users.add(_account(avatar: ''));
    expect((await users.get())!.avatarBytes, isNull);
    expect(await users.refreshAvatar((await users.get())!), isNull);
  });

  test('不同用户同名头像不共用图片，退出后不保留登录用户头像', () async {
    final users = UserService(
      database: database,
      fetchAvatar: (_) async => [1, 2, 3],
    );
    await users.add(_account());
    await users.refreshAvatar((await users.get())!);
    await users.add(_account(userId: 'other'));
    expect((await users.get())!.avatarBytes, isNull);
    await users.remove('other');
    expect((await users.get())!.avatarBytes, [1, 2, 3]);
    await users.remove('user');
    expect(await users.get(), isNull);
    await users.add(_account());
    expect((await users.get())!.avatarBytes, isNull);
  });

  test('请求过程中重新登录，旧会话图片不能覆盖新缓存', () async {
    final pending = Completer<List<int>>();
    final started = Completer<void>();
    final users = UserService(
      database: database,
      fetchAvatar: (_) {
        started.complete();
        return pending.future;
      },
    );
    await users.add(_account());
    final operation = users.refreshAvatar((await users.get())!);
    await started.future;
    await users.add(_account(token: 'new-token'));
    pending.complete([1, 2, 3]);
    expect(await operation, isNull);
    expect((await users.get())!.avatarBytes, isNull);
  });

  test('退出期间完成的头像请求不会重新创建用户记录', () async {
    final pending = Completer<List<int>>();
    final started = Completer<void>();
    final users = UserService(
      database: database,
      fetchAvatar: (_) {
        started.complete();
        return pending.future;
      },
    );
    await users.add(_account());
    final operation = users.refreshAvatar((await users.get())!);
    await started.future;
    await users.remove('user');
    pending.complete([1, 2, 3]);
    expect(await operation, isNull);
    expect(await users.get(), isNull);
  });
}

/// 创建具有可变头像、账户及会话的测试用户。
User _account({
  String userId = 'user',
  String avatar = 'avatar',
  String endpoint = 'https://example.test',
  String token = 'token',
}) => User(
  userId: userId,
  username: 'tester',
  avatar: avatar,
  type: 0,
  token: token,
  endpoint: endpoint,
);
