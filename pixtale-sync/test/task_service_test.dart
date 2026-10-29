import 'dart:io';
import 'dart:typed_data';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixtale_sync/services/task_service.dart';
import 'package:pixtale_sync/services/directory_photo_service.dart';
import 'package:pixtale_sync/db/db.dart';
import 'package:pixtale_sync/models/photo.dart';
import 'package:pixtale_sync/models/storage.dart';
import 'package:pixtale_sync/models/user.dart';
import 'package:pixtale_sync/services/photo_service.dart';
import 'package:pixtale_sync/services/user_service.dart';
import 'package:pixtale_sync/request/request.dart';

// 验证任务持久化、去重及排序行为。

/// 执行任务数据库测试。
void main() {
  sqfliteFfiInit();

  test('并发逐张加一不丢计数，核对结果可一次覆盖旧缓存', () async {
    final database = _createDatabase();
    final users = UserService(database: database);
    await users.add(_user);
    await _addStorage(database, const Storage(id: 's3', name: '云存储', type: 3));
    final service = TaskService(database: database);
    await service.add([
      'a',
    ], storage: const Storage(id: 's3', name: '云存储', type: 3));
    await service.updateProgress('a', 120);
    await service.updateProgress('a', 100);
    final counts = await Future.wait(
      List.generate(20, (_) => service.incrementProgress('a')),
    );
    expect(counts.toSet(), {
      for (var count = 101; count <= 120; count++) count,
    });
    final record = (await service.list()).single;
    expect(record.completedCount, 120);
    expect(record.storageId, 's3');
    expect(record.storageName, '云存储');
  });

  test('保存并读取任务相册展示缓存', () async {
    final database = _createDatabase();
    final service = TaskService(database: database);
    await UserService(database: database).add(_user);
    final cover = Uint8List.fromList([1, 2, 3]);
    await service.add(['a']);
    await service.updateInfo(
      'a',
      albumName: '旅行',
      photoCount: 123,
      cover: cover,
    );

    final task = (await service.list()).single;
    expect(task.albumName, '旅行');
    expect(task.photoCount, 123);
    expect(task.cover, cover);
  });

  test('目录删除后记录失效，恢复后解除，保留相册缓存和进度', () async {
    final database = _createDatabase();
    final directory = await Directory.systemTemp.createTemp('task_invalid_');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete();
    });
    await UserService(database: database).add(_user);
    final service = TaskService(database: database);
    final photos = DirectoryPhotoService();
    await service.add(['a']);
    await service.updatePaths({'a': directory.path});
    await service.updateInfo('a', albumName: '旅行', photoCount: 123);
    await service.updateProgress('a', 12);
    final task = (await service.list()).single;
    expect(task.isInvalid, isFalse);
    await service.readAlbum(task, photos);
    await directory.delete();
    await expectLater(
      service.readAlbum(task, photos),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Album does not exist',
        ),
      ),
    );
    final missing = (await service.list()).single;
    expect(missing.isInvalid, isTrue);
    expect(missing.albumName, '旅行');
    expect(missing.photoCount, 123);
    expect(missing.completedCount, 12);
    expect(missing.sortTime, task.sortTime);
    final revision = TaskService.changes.value;
    await service.updateInvalid('a', true);
    expect(TaskService.changes.value, revision);

    await directory.create();
    await service.readAlbum(missing, photos);
    expect((await service.list()).single.isInvalid, isFalse);
  });

  test('读取相册的其他错误不标记失效', () async {
    final database = _createDatabase();
    await UserService(database: database).add(_user);
    final service = TaskService(database: database);
    await service.add(['a']);
    await service.updateInfo('a', albumName: '旅行', photoCount: 123);
    final task = (await service.list()).single;
    await expectLater(
      service.readAlbum(task, _BrokenPhotos()),
      throwsA(isA<ApiException>()),
    );
    expect((await service.list()).single.isInvalid, isFalse);
  });

  test('批量添加跳过重复 ID，并保留原添加时间', () async {
    final database = _createDatabase();
    final service = TaskService(database: database);
    await UserService(database: database).add(_user);
    await service.add(['a', 'b', 'a']);
    final before = await service.list();
    await service.add(['a', 'c']);
    final after = await service.list();
    expect(after.map((record) => record.albumId).toSet(), {'a', 'b', 'c'});
    expect(after.length, 3);
    expect(
      after.singleWhere((record) => record.albumId == 'a').sortTime,
      before.singleWhere((record) => record.albumId == 'a').sortTime,
    );
    await service.add([]);
    expect((await service.list()).length, 3);
  });

  test('排序时间越小越靠前，置顶取最小值减 1', () async {
    final directory = await Directory.systemTemp.createTemp('task_service_');
    final file = File('${directory.path}/test.sqlite');
    var database = Db(factory: databaseFactoryFfi, databasePath: file.path);
    try {
      await UserService(database: database).add(_user);
      var service = TaskService(database: database);
      await service.add(['old']);
      await (await database.database).execute(
        'UPDATE task SET sort_time = ? WHERE album_id = ?',
        [1, 'old'],
      );
      await service.add([
        'new',
      ], storage: const Storage(id: 'cloud', name: '云存储', type: 3));
      await service.updateProgress('new', 12);
      expect((await service.list()).map((row) => row.albumId), ['old', 'new']);
      await database.close();
      database = Db(factory: databaseFactoryFfi, databasePath: file.path);
      service = TaskService(database: database);
      expect((await service.list()).map((row) => row.albumId), ['old', 'new']);
      final restored = (await service.list()).singleWhere(
        (row) => row.albumId == 'new',
      );
      expect(restored.completedCount, 12);
      expect(restored.storageName, isNull);
      expect(restored.storageId, 'cloud');
      await (await database.database).update('task', {'sort_time': 1});
      await service.pin('old');
      final pinned = await service.list();
      expect(pinned.map((row) => row.albumId), ['old', 'new']);
      expect(pinned.first.sortTime.millisecondsSinceEpoch ~/ 1000, 0);
      expect(pinned.first.sortTime.isBefore(pinned.last.sortTime), isTrue);
      expect(pinned.last.completedCount, 12);
      expect(pinned.last.storageId, 'cloud');
      await database.close();
      database = Db(factory: databaseFactoryFfi, databasePath: file.path);
      service = TaskService(database: database);
      expect((await service.list()).first.albumId, 'old');
      await service.remove('old');
      expect((await service.list()).single.albumId, 'new');
      await service.add(['old']);
      expect((await service.list()).map((row) => row.albumId).toSet(), {
        'old',
        'new',
      });
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });

  test('存储 ID 无法关联时返回空名称', () async {
    final database = _createDatabase();
    final service = TaskService(database: database);
    await UserService(database: database).add(_user);
    await service.add([
      'missing',
    ], storage: const Storage(id: 'deleted', name: '已删除', type: 3));

    final record = (await service.list()).single;
    expect(record.storageId, 'deleted');
    expect(record.storageName, isNull);
  });

  test('修改存储只影响指定用户任务，切换时重置进度并保留相册缓存和排序', () async {
    final database = _createDatabase();
    await UserService(database: database).add(_user);
    final service = TaskService(database: database);
    const old = Storage(id: 'old', name: '旧存储', type: 1);
    const next = Storage(id: 'new', name: '新存储', type: 3);
    const other = User(
      userId: 'other',
      username: 'other',
      avatar: '',
      type: 0,
      token: 'other-token',
      endpoint: 'https://example.test',
    );
    await _addStorage(database, old);
    await _addStorage(database, next);
    await service.add(['a'], storage: old);
    await service.add(['a'], storage: old, account: other);
    await service.updateProgress('a', 12);
    final cover = Uint8List.fromList([1, 2, 3]);
    await service.updateInfo(
      'a',
      albumName: '旅行',
      photoCount: 123,
      cover: cover,
    );
    await service.updatePaths({'a': 'D:/photos'});
    final before = (await service.list()).single;

    await service.updateStorage('a', old.id);
    expect((await service.list()).single.completedCount, 12);
    await service.updateStorage('a', next.id);
    final after = (await service.list()).single;
    expect(after.storageId, next.id);
    expect(after.storageName, next.name);
    expect(after.completedCount, 12);
    expect(after.albumName, before.albumName);
    expect(after.photoCount, before.photoCount);
    expect(after.cover, before.cover);
    expect(after.path, before.path);
    expect(after.sortTime, before.sortTime);
    expect((await service.list(account: other)).single.storageId, old.id);
  });

  test('同相册按用户 ID 隔离，修改互不影响，同一用户跨服务器共用任务', () async {
    final database = _createDatabase();
    final users = UserService(database: database);
    final service = TaskService(database: database);
    const otherUser = User(
      userId: 'other',
      username: 'other',
      avatar: '',
      type: 0,
      token: 'other-token',
      endpoint: 'https://example.test',
    );
    const otherServer = User(
      userId: 'user',
      username: 'tester',
      avatar: '',
      type: 0,
      token: 'other-token',
      endpoint: 'https://other.test',
    );
    for (final user in [_user, otherUser]) {
      await users.add(user);
      expect(await service.list(), isEmpty);
      await service.add([
        'same',
      ], storage: const Storage(id: 'disk', name: '', type: 1));
      await (await database.database).insert('storage', {
        'user_id': user.userId,
        'storage_id': 'disk',
        'name': user.username,
        'type': 1,
      });
    }
    await service.updatePaths({'same': 'D:/photos'});
    await service.updateInvalid('same', true);
    await service.updateInfo('same', albumName: '旅行', photoCount: 10);
    await service.updateProgress('same', 5);
    expect(await service.incrementProgress('same'), 6);
    await service.pin('same');

    // 模拟旧账户上传返回，此时当前账户已经切换。
    await service.incrementProgress('same', account: _user);
    final old = (await service.list(account: _user)).single;
    expect(old.completedCount, 1);
    expect(old.isInvalid, isFalse);
    expect(old.photoCount, 0);
    expect(old.path, isNull);
    expect(old.albumName, '');
    expect(old.storageName, 'tester');
    final current = (await service.list()).single;
    expect(current.storageName, 'other');
    expect(current.isInvalid, isTrue);
    expect(current.completedCount, 6);
    expect(current.photoCount, 10);
    expect(current.path, 'D:/photos');
    expect(current.albumName, '旅行');
    await service.remove('same');
    expect(await service.list(), isEmpty);
    expect((await service.list(account: _user)).length, 1);
    expect(await service.list(account: otherUser), isEmpty);
    await users.add(otherServer);
    expect((await service.list()).single.completedCount, 1);
    expect((await service.list()).single.storageName, 'tester');
    await service.add(['same']);
    expect((await service.list()).length, 1);
    await users.remove(otherServer.userId);
    await users.remove(otherUser.userId);
    expect(await service.list(), isEmpty);
    await expectLater(service.add(['new']), throwsA(isA<ApiException>()));
    await users.add(_user);
    expect((await service.list()).single.completedCount, 1);
  });
}

Db _createDatabase() {
  final database = Db(
    factory: databaseFactoryFfi,
    databasePath: inMemoryDatabasePath,
  );
  addTearDown(database.close);
  return database;
}

const _user = User(
  userId: 'user',
  username: 'tester',
  avatar: '',
  type: 0,
  token: 'token',
  endpoint: 'https://example.test',
);

/// 写入测试账户的存储缓存。
Future<void> _addStorage(Db database, Storage storage) async {
  await (await database.database).insert('storage', {
    'user_id': _user.userId,
    'storage_id': storage.id,
    'name': storage.name,
    'type': storage.type,
  });
}

/// 读取相册时抛出与相册不存在无关的错误。
class _BrokenPhotos extends PhotoService {
  /// 模拟权限或通道失败。
  @override
  Future<PhotoAlbum?> getPhotoAlbum(String id, {String? path}) async {
    throw const ApiException('无法读取本地相册');
  }
}
