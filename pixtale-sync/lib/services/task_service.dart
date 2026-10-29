import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:pixtale_sync/db/db.dart';
import 'package:pixtale_sync/models/task.dart';
import 'package:pixtale_sync/models/storage.dart';
import 'package:pixtale_sync/models/user.dart';
import 'package:pixtale_sync/models/photo.dart';
import 'package:pixtale_sync/request/request.dart';
import 'package:pixtale_sync/services/user_service.dart';
import 'package:pixtale_sync/services/photo_service.dart';

// 任务添加、缓存查询和排序服务。

/// 提供任务的批量添加和排序查询。
class TaskService {
  /// 创建服务，可注入数据库用于测试。
  TaskService({Db? database}) : _database = database ?? Db();

  /// 应用共享的任务服务。
  static final TaskService instance = TaskService();

  /// 任务失效状态落库后通知卡片，后台通过消息转发。
  static final changes = ValueNotifier<int>(0);

  /// 通知当前隔离区刷新任务状态。
  static void notifyChanged() => changes.value++;

  /// 本地数据库连接。
  final Db _database;

  /// 读取任务所属的当前登录账户。
  Future<User?> currentUser() => UserService(database: _database).get();

  /// 取得操作账户，异步任务可传入启动时的账户，避免跨账户写入。
  Future<User> _account(User? account) async {
    final user = account ?? await currentUser();
    if (user == null) throw const ApiException('Sign in first');
    return user;
  }

  /// 按当前账户和相册 ID 批量添加，已存在时保留原添加时间。
  Future<void> add(
    List<String> albumIds, {
    Storage? storage,
    User? account,
  }) async {
    final user = await _account(account);
    final db = await _database.database;
    final sortTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.transaction((txn) async {
      for (final id in albumIds.toSet()) {
        final existing = await txn.query(
          'task',
          columns: ['album_id'],
          where: 'user_id = ? AND album_id = ?',
          whereArgs: [user.userId, id],
          limit: 1,
        );
        if (existing.isNotEmpty) continue;
        await txn.insert('task', {
          'user_id': user.userId,
          'album_id': id,
          'sort_time': sortTime,
          'storage_id': storage?.id,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  /// 写入已添加任务对应的桌面目录路径。
  Future<void> updatePaths(Map<String, String?> paths, {User? account}) async {
    if (paths.isEmpty) return;
    final user = await _account(account);
    final db = await _database.database;
    await db.transaction((txn) async {
      for (final entry in paths.entries) {
        await txn.update(
          'task',
          {'path': entry.value},
          where: 'user_id = ? AND album_id = ?',
          whereArgs: [user.userId, entry.key],
        );
      }
    });
  }

  /// 按排序时间从小到大返回任务。置顶后的值更小，排在前面。
  Future<List<Task>> list({User? account}) async {
    final user = account ?? await currentUser();
    if (user == null) return [];
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
SELECT
  task.album_id,
  task.sort_time,
  task.completed_count,
  task.storage_id,
  task.path,
  task.album_name,
  task.photo_count,
  task.cover,
  task.is_invalid,
  storage.name AS resolved_storage_name
FROM task
LEFT JOIN storage
  ON storage.storage_id = task.storage_id
 AND storage.user_id = task.user_id
WHERE task.user_id = ?
ORDER BY task.sort_time ASC
''',
      [user.userId],
    );
    return rows
        .map(
          (row) => Task(
            albumId: row['album_id'] as String,
            sortTime: DateTime.fromMillisecondsSinceEpoch(
              (row['sort_time'] as int) * 1000,
              isUtc: true,
            ),
            completedCount: row['completed_count'] as int,
            storageId: row['storage_id'] as String?,
            storageName: row['resolved_storage_name'] as String?,
            path: row['path'] as String?,
            albumName: row['album_name'] as String,
            photoCount: row['photo_count'] as int,
            cover: _readCover(row['cover']),
            isInvalid: row['is_invalid'] == 1,
          ),
        )
        .toList();
  }

  /// 读取本地相册，并保存失效或恢复状态。
  Future<PhotoAlbum> readAlbum(
    Task task,
    PhotoService photos, {
    User? account,
  }) async {
    final user = await _account(account);
    final album = await photos.getPhotoAlbum(task.albumId, path: task.path);
    if (album == null) {
      await updateInvalid(task.albumId, true, account: user);
      throw const ApiException('Album does not exist');
    }
    await updateInvalid(task.albumId, false, account: user);
    return album;
  }

  /// 仅在状态变化时写入并通知，不改变相册缓存和同步进度。
  Future<void> updateInvalid(
    String albumId,
    bool isInvalid, {
    User? account,
  }) async {
    final user = await _account(account);
    final value = isInvalid ? 1 : 0;
    final changed = await (await _database.database).update(
      'task',
      {'is_invalid': value},
      where: 'user_id = ? AND album_id = ? AND is_invalid != ?',
      whereArgs: [user.userId, albumId, value],
    );
    if (changed > 0) notifyChanged();
  }

  /// 更新任务对应相册的展示缓存，不改变排序和同步进度。
  Future<void> updateInfo(
    String albumId, {
    required String albumName,
    required int photoCount,
    Uint8List? cover,
    User? account,
  }) async {
    final user = await _account(account);
    await (await _database.database).update(
      'task',
      {'album_name': albumName, 'photo_count': photoCount, 'cover': cover},
      where: 'user_id = ? AND album_id = ?',
      whereArgs: [user.userId, albumId],
    );
  }

  /// 修改目标存储，保留任务已有的完成数量。
  Future<void> updateStorage(
    String albumId,
    String storageId, {
    User? account,
  }) async {
    final user = await _account(account);
    await (await _database.database).update(
      'task',
      {'storage_id': storageId},
      where: 'user_id = ? AND album_id = ? AND storage_id IS NOT ?',
      whereArgs: [user.userId, albumId, storageId],
    );
  }

  /// 把任务排到最前：取当前最小排序值再减 1。
  Future<void> pin(String albumId, {User? account}) async {
    final user = await _account(account);
    final db = await _database.database;
    await db.transaction((txn) async {
      final rows = await txn.rawQuery(
        'SELECT MIN(sort_time) AS value FROM task WHERE user_id = ?',
        [user.userId],
      );
      final minimum = rows.first['value'] as int? ?? 0;
      await txn.update(
        'task',
        {'sort_time': minimum - 1},
        where: 'user_id = ? AND album_id = ?',
        whereArgs: [user.userId, albumId],
      );
    });
  }

  /// 仅移除本地任务记录，保留设备和远端照片。
  Future<void> remove(String albumId, {User? account}) async {
    final user = await _account(account);
    await (await _database.database).delete(
      'task',
      where: 'user_id = ? AND album_id = ?',
      whereArgs: [user.userId, albumId],
    );
  }

  /// 保存已同步张数，不改变任务关联的存储。
  Future<void> updateProgress(
    String albumId,
    int completedCount, {
    User? account,
  }) async {
    final user = await _account(account);
    await (await _database.database).update(
      'task',
      {'completed_count': completedCount},
      where: 'user_id = ? AND album_id = ?',
      whereArgs: [user.userId, albumId],
    );
  }

  /// 单张同步成功后原子加一，返回持久化后的完成数量。
  Future<int> incrementProgress(String albumId, {User? account}) async {
    final user = await _account(account);
    return (await _database.database).transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE task SET completed_count = completed_count + 1 '
        'WHERE user_id = ? AND album_id = ?',
        [user.userId, albumId],
      );
      final rows = await txn.query(
        'task',
        columns: ['completed_count'],
        where: 'user_id = ? AND album_id = ?',
        whereArgs: [user.userId, albumId],
      );
      return rows.single['completed_count'] as int;
    });
  }

  /// 将 SQLite 返回的二进制字段转换为封面数据。
  static Uint8List? _readCover(Object? value) {
    if (value == null) return null;
    if (value is Uint8List) return value;
    return Uint8List.fromList((value as List).cast<int>());
  }
}
