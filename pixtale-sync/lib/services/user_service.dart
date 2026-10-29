import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:pixtale_sync/db/db.dart';
import 'package:pixtale_sync/models/user.dart';
import 'package:pixtale_sync/request/user.dart' as user_request;

// 管理登录用户与头像缓存，网络接口统一由 request 提供。

/// 读取、保存和删除最近登录用户。
class UserService {
  /// 创建用户服务，测试可注入数据库和头像请求。
  UserService({Db? database, Future<List<int>> Function(User)? fetchAvatar})
    : _database = database ?? Db(),
      _fetchAvatar = fetchAvatar ?? _downloadAvatar;

  static final UserService instance = UserService();

  /// 通知页面重新加载账户数据，登录和退出成功后递增。
  static final changes = ValueNotifier<int>(0);
  final Db _database;
  final Future<List<int>> Function(User) _fetchAvatar;

  /// 读取最近登录的用户及本地头像。
  Future<User?> get() async {
    final rows = await (await _database.database).query(
      'user',
      orderBy: 'rowid DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return User(
      userId: row['user_id'] as String,
      username: row['username'] as String,
      avatar: row['avatar'] as String? ?? '',
      type: row['type'] as int? ?? 0,
      token: row['token'] as String,
      endpoint: row['endpoint'] as String,
      avatarBytes: row['avatar_bytes'] as Uint8List?,
    );
  }

  /// 保存登录信息，同一用户头像标识不变时保留图片缓存。
  Future<void> add(User user) async {
    await (await _database.database).transaction((txn) async {
      final rows = await txn.query(
        'user',
        columns: ['avatar', 'avatar_bytes'],
        where: 'user_id = ?',
        whereArgs: [user.userId],
      );
      final cached = rows.firstOrNull;
      await txn.insert('user', {
        'user_id': user.userId,
        'username': user.username,
        'avatar': user.avatar,
        'type': user.type,
        'token': user.token,
        'endpoint': user.endpoint,
        'avatar_bytes': user.avatar.isEmpty
            ? null
            : user.avatarBytes ??
                  (cached != null && cached['avatar'] == user.avatar
                      ? cached['avatar_bytes']
                      : null),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    changes.value++;
  }

  /// 异步刷新头像，内容未变时复用图片，失效会话的请求不写入缓存。
  Future<Uint8List?> refreshAvatar(User user) async {
    if (user.avatar.isEmpty) return null;
    final bytes = Uint8List.fromList(await _fetchAvatar(user));
    if (bytes.isEmpty) return user.avatarBytes;
    final unchanged = listEquals(bytes, user.avatarBytes);
    final updated = await (await _database.database).update(
      'user',
      {'avatar_bytes': bytes},
      where: 'user_id = ? AND avatar = ? AND endpoint = ? AND token = ?',
      whereArgs: [user.userId, user.avatar, user.endpoint, user.token],
    );
    if (updated == 0) return null;
    return unchanged ? user.avatarBytes : bytes;
  }

  /// 下载当前用户的头像，沿用统一请求层的认证和错误处理。
  static Future<List<int>> _downloadAvatar(User user) =>
      user_request.getUserAvatar(user.avatar, user.endpoint, user.token);

  /// 退出登录时删除用户信息及其头像缓存。
  Future<void> remove(String userId) async {
    await (await _database.database).delete(
      'user',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    changes.value++;
  }
}
