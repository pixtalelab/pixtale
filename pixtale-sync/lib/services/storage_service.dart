import 'package:flutter/foundation.dart';
import 'package:pixtale_sync/db/db.dart';
import 'package:pixtale_sync/models/storage.dart';
import 'package:pixtale_sync/models/user.dart';
import 'package:pixtale_sync/request/request.dart';
import 'package:pixtale_sync/request/storage.dart' as storage_request;
import 'package:pixtale_sync/services/user_service.dart';

// 读取存储缓存，并以远端最新列表事务替换本地记录。

/// 管理当前账户的存储列表。
class StorageService {
  /// 存储落库后通知任务卡片，后台通过消息转发到主隔离区。
  static final changes = ValueNotifier<int>(0);

  /// 通知当前隔离区重新读取已保存的存储信息。
  static void notifyChanged() => changes.value++;

  /// 创建可注入数据库、账户及远端查询的存储服务。
  StorageService({
    Db? database,
    UserService? users,
    Future<List<Storage>> Function(User)? fetch,
  }) : _database = database ?? Db(),
       _users = users ?? UserService(database: database),
       _fetch = fetch ?? storage_request.listStorages;

  final Db _database;
  final UserService _users;
  final Future<List<Storage>> Function(User) _fetch;

  /// 返回当前账户缓存，未登录时不显示其他账户数据。
  Future<List<Storage>> list() async {
    final user = await _users.get();
    if (user == null) return [];
    final rows = await (await _database.database).query(
      'storage',
      where: 'user_id = ?',
      whereArgs: [user.userId],
      orderBy: 'rowid ASC',
    );
    return rows
        .map(
          (row) => Storage(
            id: row['storage_id'] as String,
            name: row['name'] as String,
            type: row['type'] as int,
          ),
        )
        .toList();
  }

  /// 获取最新存储并保存，失败时保留旧缓存。
  Future<List<Storage>> refresh() async {
    final user = await _users.get();
    if (user == null) throw const ApiException('Sign in first');
    final items = await _fetch(user);
    await save(items, account: user);
    return items;
  }

  /// 保存已有的远程列表，避免同步时重复请求，并拒绝旧会话结果。
  Future<void> save(List<Storage> items, {required User account}) async {
    final current = await _users.get();
    if (current?.userId != account.userId ||
        current?.endpoint != account.endpoint ||
        current?.token != account.token) {
      throw const ApiException('Account changed, try again');
    }
    await (await _database.database).transaction((txn) async {
      await txn.delete(
        'storage',
        where: 'user_id = ?',
        whereArgs: [account.userId],
      );
      for (final item in items) {
        await txn.insert('storage', {
          'user_id': account.userId,
          'storage_id': item.id,
          'name': item.name,
          'type': item.type,
        });
      }
    });
    notifyChanged();
  }
}
