import 'dart:async';

import 'rule_fixture.dart';

import 'package:pixtale_sync/models/rule.dart';
import 'package:pixtale_sync/services/rule_service.dart';

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pixtale_sync/db/db.dart';
import 'package:pixtale_sync/models/settings.dart';
import 'package:pixtale_sync/models/log.dart';
import 'package:pixtale_sync/models/photo.dart';
import 'package:pixtale_sync/models/sync.dart';
import 'package:pixtale_sync/models/storage.dart';
import 'package:pixtale_sync/models/user.dart';
import 'package:pixtale_sync/request/request.dart';
import 'package:pixtale_sync/request/sync.dart';
import 'package:pixtale_sync/services/photo_service.dart';
import 'package:pixtale_sync/services/log_service.dart';
import 'package:pixtale_sync/services/settings_service.dart';
import 'package:pixtale_sync/services/storage_service.dart';
import 'package:pixtale_sync/services/sync_service.dart';
import 'package:pixtale_sync/services/task_service.dart';
import 'package:pixtale_sync/services/user_service.dart';
import 'package:pixtale_sync/providers/sync_provider.dart';

// 验证相册关联、上传重试、张数进度和停止行为。

/// 执行同步业务测试。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Db database;
  late TaskService tasks;
  late RuleService rules;
  late SettingsService settings;
  late StorageService storages;
  late LogService logs;
  late UserService users;
  late FakePhotos photos;
  late FakeApi api;
  late SyncService service;

  setUp(() async {
    database = Db(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    tasks = _SyncTasks(database);
    rules = RuleService(database: database);
    await saveTestRule(database, testRule(id: 'default', name: 'Default Rule'));
    settings = SettingsService(database: database);
    logs = LogService(database: database);
    users = UserService(database: database);
    storages = StorageService(database: database);
    await users.add(
      const User(
        userId: 'user',
        username: 'tester',
        avatar: '',
        type: 0,
        token: 'token',
        endpoint: 'https://example.test',
      ),
    );
    await settings.updateTaskInterval(0);
    await settings.updateLocale('zh');
    photos = FakePhotos();
    service = SyncService(
      tasks: tasks,
      users: users,
      settings: settings,
      storages: storages,
      rules: rules,
      logs: logs,
      photos: photos,
      apiFactory: (user, client) {
        api = FakeApi(user, client);
        return api;
      },
    );
  });

  tearDown(() async {
    await service.stop();
    await photos.dispose();
    await database.close();
  });

  test('按范围和类型匹配，边界包含，重叠时只使用首条规则，允许超过旧上限', () async {
    const mb = 1024 * 1024;
    final id = await rules.add(
      name: '分流规则',
      fileType: RuleFileType.photo,
      fileMinSize: 10 * mb,
      fileMaxSize: 20 * mb,
      storageId: 's3',
    );
    await rules.addItem(
      pid: id,
      fileType: RuleFileType.video,
      fileMinSize: 10 * mb,
      fileMaxSize: 20 * mb,
      storageId: 'local-id',
    );
    await rules.addItem(
      pid: id,
      fileType: RuleFileType.any,
      fileMinSize: 15 * mb,
      fileMaxSize: 400 * mb,
      storageId: 'local-id',
    );
    photos.albums = {
      'a': [
        localPhoto('min.jpg', size: 10 * mb),
        localPhoto('max.jpg', size: 20 * mb),
        localPhoto('clip.mp4', size: 10 * mb),
        localPhoto('large.jpg', size: 400 * mb),
        localPhoto('small.jpg', size: 10 * mb - 1),
        localPhoto('huge.mp4', size: 400 * mb + 1),
      ],
    };
    photos.headers['clip.mp4'] = const [
      0,
      0,
      0,
      24,
      0x66,
      0x74,
      0x79,
      0x70,
      0x6D,
      0x70,
      0x34,
      0x32,
    ];
    await tasks.add(['a'], rule: (await rules.get(id))!);
    await service.start((_) {});
    expect(api.attempts, {
      'min.jpg': 1,
      'max.jpg': 1,
      'clip.mp4': 1,
      'large.jpg': 1,
    });
    expect(api.uploadTargets, {
      'min.jpg': 's3',
      'max.jpg': 's3',
      'clip.mp4': 'local-id',
      'large.jpg': 'local-id',
    });
    expect(photos.opened, unorderedEquals(api.attempts.keys));
    expect((await tasks.list()).single.completedCount, 4);
  });

  test('不同目标存储统一查重，远端已存在的文件不再上传', () async {
    final id = await rules.add(
      name: '统一查重',
      fileType: RuleFileType.photo,
      fileMinSize: 0,
      fileMaxSize: 1000,
      storageId: 'local-id',
    );
    await rules.addItem(
      pid: id,
      fileType: RuleFileType.video,
      fileMinSize: 0,
      fileMaxSize: 1000,
      storageId: 's3',
    );
    photos.albums = {
      'a': [
        localPhoto('photo.jpg'),
        localPhoto('existing.jpg'),
        localPhoto('clip.mp4'),
        localPhoto('new.jpg'),
      ],
    };
    photos.headers['clip.mp4'] = const [
      0,
      0,
      0,
      24,
      0x66,
      0x74,
      0x79,
      0x70,
      0x6D,
      0x70,
      0x34,
      0x32,
    ];
    service = SyncService(
      tasks: tasks,
      users: users,
      settings: settings,
      storages: storages,
      rules: rules,
      logs: logs,
      photos: photos,
      apiFactory: (user, client) {
        api = FakeApi(user, client)
          ..inventory = [remotePhoto('existing.jpg'), remotePhoto('photo.jpg')];
        return api;
      },
    );
    await tasks.add(['a'], rule: (await rules.get(id))!);
    await service.start((_) {});
    expect(api.albumNames, ['相册 a']);
    expect(api.checkAlbumIds, ['remote-相册 a']);
    expect(api.checkedFiles.single.map((file) => file.name), [
      'photo.jpg',
      'existing.jpg',
      'clip.mp4',
      'new.jpg',
    ]);
    expect(api.uploadTargets, {'new.jpg': 'local-id', 'clip.mp4': 's3'});
    expect((await tasks.list()).single.completedCount, 4);
  });

  test('规则范围外的已同步文件仍计数，仅筛选远端缺失文件上传', () async {
    await rules.updateItem(
      id: 'default-item',
      pid: 'default',
      fileType: RuleFileType.photo,
      fileMinSize: 0,
      fileMaxSize: 200,
      storageId: 'local-id',
    );
    photos.albums = {
      'a': [
        localPhoto('old-large.jpg', size: 300),
        localPhoto('old-video.mp4'),
        localPhoto('new.jpg'),
        localPhoto('new-large.jpg', size: 300),
        localPhoto('new-video.mp4'),
      ],
    };
    await tasks.add(['a']);
    await tasks.updateProgress('a', 12);
    final progress = <SyncProgress>[];
    service = SyncService(
      tasks: tasks,
      users: users,
      settings: settings,
      storages: storages,
      rules: rules,
      logs: logs,
      photos: photos,
      apiFactory: (user, client) {
        api = FakeApi(user, client)
          ..inventory = [
            remotePhoto('old-large.jpg', size: 300),
            remotePhoto('old-video.mp4'),
          ]
          ..onCheck = (_) async {
            expect((await tasks.list()).single.completedCount, 12);
            expect(progress, isEmpty);
          }
          ..onUpload = (_) async {
            expect((await tasks.list()).single.completedCount, 2);
          };
        return api;
      },
    );
    await service.start(progress.add);
    expect(api.checkedFiles.single.map((file) => file.name), [
      'old-large.jpg',
      'old-video.mp4',
      'new.jpg',
      'new-large.jpg',
      'new-video.mp4',
    ]);
    expect(progress.map((item) => item.completed), [2, 3]);
    expect(progress.every((item) => item.total == 5), isTrue);
    expect(api.attempts, {'new.jpg': 1});
    expect(photos.opened, ['new.jpg']);
    expect((await tasks.list()).single.completedCount, 3);
  });

  test('完整扫描后按 995 条分页统一查重，不命中规则也保存已同步总数', () async {
    await rules.updateItem(
      id: 'default-item',
      pid: 'default',
      fileType: RuleFileType.any,
      fileMinSize: 0,
      fileMaxSize: 0,
      storageId: 'local-id',
    );
    final all = List.generate(1005, (index) => localPhoto('$index.jpg'));
    photos.albums = {'a': all};
    await tasks.add(['a']);
    await tasks.updateProgress('a', 777);
    var scanned = 0;
    photos.onPage = (page) async => scanned++;
    final progress = <SyncProgress>[];
    service = SyncService(
      tasks: tasks,
      users: users,
      settings: settings,
      storages: storages,
      rules: rules,
      logs: logs,
      photos: photos,
      apiFactory: (user, client) {
        api = FakeApi(user, client)
          ..inventory = all
              .take(1000)
              .map((photo) => remotePhoto(photo.name))
              .toList()
          ..onCheck = (_) async {
            expect(scanned, 11);
            expect((await tasks.list()).single.completedCount, 777);
            expect(progress, isEmpty);
          };
        return api;
      },
    );
    await service.start(progress.add);
    expect(api.albumNames, ['相册 a']);
    expect(api.checkedFiles.map((page) => page.length), [995, 10]);
    expect(
      api.checkedFiles.expand((page) => page).map((file) => file.name),
      all.map((photo) => photo.name),
    );
    expect(progress.single.completed, 1000);
    expect(progress.single.total, 1005);
    expect((await tasks.list()).single.completedCount, 1000);
    expect(api.attempts, isEmpty);
    expect(photos.opened, isEmpty);
  });

  test('后续查重分页失败时保留旧数量，不上传前页的缺失文件', () async {
    photos.albums = {
      'a': List.generate(1005, (index) => localPhoto('$index.jpg')),
    };
    await tasks.add(['a']);
    await tasks.updateProgress('a', 777);
    final progress = <SyncProgress>[];
    service = SyncService(
      tasks: tasks,
      users: users,
      settings: settings,
      storages: storages,
      rules: rules,
      logs: logs,
      photos: photos,
      apiFactory: (user, client) {
        api = FakeApi(user, client)
          ..onCheck = (_) async {
            if (api.checkedFiles.length == 2) {
              throw const ApiException('后页查重失败', statusCode: 400);
            }
          };
        return api;
      },
    );
    await service.start(progress.add);
    expect(api.checkedFiles.map((page) => page.length), [995, 10]);
    expect(progress, isEmpty);
    expect((await tasks.list()).single.completedCount, 777);
    expect(api.attempts, isEmpty);
    expect(photos.opened, isEmpty);
    expect((await logs.list(failuresOnly: true)).single.event, '远程检测');
  });

  test('每个任务开始时重新读取规则，上一任务期间的编辑立即生效', () async {
    photos.albums = {
      'a': [localPhoto('a.jpg')],
      'b': [localPhoto('b.jpg')],
    };
    await tasks.add(['a', 'b']);
    service = SyncService(
      tasks: tasks,
      users: users,
      settings: settings,
      storages: storages,
      rules: rules,
      logs: logs,
      photos: photos,
      apiFactory: (user, client) {
        api = FakeApi(user, client)
          ..onUpload = (_) async {
            await rules.updateItem(
              id: 'default-item',
              pid: 'default',
              fileType: RuleFileType.any,
              fileMinSize: 0,
              fileMaxSize: 0,
              storageId: 'local-id',
            );
          };
        return api;
      },
    );
    await service.start((_) {});
    expect(api.attempts, {'a.jpg': 1});
    expect(api.albumNames, ['相册 a', '相册 b']);
    expect((await tasks.list()).map((task) => task.completedCount), [1, 0]);
  });

  test('失效规则不核对远端，空规则仍统一查重但不上传', () async {
    final plainTasks = TaskService(database: database);
    await plainTasks.add(['a']);
    await tasks.add(['b'], rule: testRule(id: 'deleted', name: '已删除'));
    final alien = testRule(id: 'alien', name: '其他用户', userId: 'other');
    await saveTestRule(database, alien);
    await tasks.add(['c'], rule: alien);
    final empty = testRule(id: 'empty', name: '空规则');
    await saveTestRule(database, empty);
    await (await database.database).delete(
      'rule_item',
      where: 'pid = ?',
      whereArgs: [empty.id],
    );
    await tasks.add(['d'], rule: empty);
    photos.albums = {
      for (final id in ['a', 'b', 'c', 'd']) id: [localPhoto('$id.jpg')],
    };
    await service.start((_) {});
    expect(api.attempts, isEmpty);
    expect(api.albumNames, ['相册 d']);
    expect(api.checkAlbumIds, ['remote-相册 d']);
    expect(photos.opened, isEmpty);
    final failures = await logs.list(failuresOnly: true);
    expect(failures, hasLength(3));
    expect(failures.every((entry) => entry.event == '读取规则'), isTrue);
  });

  test('没有照片权限时提示并停止同步', () async {
    photos.denyPermission = true;
    photos.albums = {'a': []};
    await tasks.add(['a']);
    await expectLater(
      service.start((_) {}),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Photo access is required',
        ),
      ),
    );
    final failures = await logs.list(failuresOnly: true);
    expect(failures.single.event, '开启同步');
    expect(failures.single.message, 'Photo access is required');
    expect((await settings.get()).taskStatus, 2);
    expect((await logs.list()).any((item) => item.event == '开始同步'), isFalse);
  });

  test('本地相册读取失败后标记失效，其他任务继续，恢复后清除状态', () async {
    photos.albums = {'b': []};
    await tasks.add(['a', 'b']);
    await tasks.updateInfo('a', albumName: '旅行', photoCount: 123);
    await tasks.updateProgress('a', 12);
    await service.start((_) {});
    final records = await tasks.list();
    expect(records.first.isInvalid, isTrue);
    expect(records.first.completedCount, 12);
    expect(records.last.isInvalid, isFalse);
    expect(api.albumNames, isEmpty);
    final failures = await logs.list(failuresOnly: true);
    expect(failures.single.event, '读取相册');
    expect(failures.single.albumName, '旅行');
    photos.albumErrors.clear();
    photos.albums['a'] = [];
    await service.start((_) {});
    expect((await tasks.list()).every((task) => !task.isInvalid), isTrue);
  });

  test('相册张数变化时刷新封面和总数缓存', () async {
    photos.albums = {
      'a': [localPhoto('new.jpg')],
    };
    photos.covers['a'] = Uint8List.fromList([9, 9, 9]);
    await tasks.add(['a']);
    await tasks.updateInfo(
      'a',
      albumName: '旅行',
      photoCount: 123,
      cover: Uint8List.fromList([1, 2, 3]),
    );
    await service.start((_) {});
    final task = (await tasks.list()).single;
    expect(photos.infoReads, 1);
    expect(task.photoCount, 1);
    expect(task.cover, Uint8List.fromList([9, 9, 9]));
    expect(task.albumName, '相册 a');
  });

  test('相册张数不变时不刷新封面', () async {
    photos.albums = {
      'a': [localPhoto('old.jpg')],
    };
    photos.covers['a'] = Uint8List.fromList([9, 9, 9]);
    await tasks.add(['a']);
    final cover = Uint8List.fromList([1, 2, 3]);
    await tasks.updateInfo('a', albumName: '旅行', photoCount: 1, cover: cover);
    await service.start((_) {});
    final task = (await tasks.list()).single;
    expect(photos.infoReads, 0);
    expect(task.photoCount, 1);
    expect(task.cover, cover);
    expect(task.albumName, '旅行');
  });

  test('分页核对期间保留缓存，已完成相册只一次发布完整数量', () async {
    final all = List.generate(205, (index) => localPhoto('$index.jpg'));
    photos.albums = {'a': all};
    await tasks.add(['a']);
    await tasks.updateProgress('a', 205);
    final progress = <SyncProgress>[];
    final pages = <int>[];
    photos.onPage = (page) async {
      pages.add(page);
      expect((await tasks.list()).single.completedCount, 205);
      expect(progress, isEmpty);
    };
    service = SyncService(
      tasks: tasks,
      users: users,
      settings: settings,
      storages: storages,
      rules: rules,
      logs: logs,
      photos: photos,
      apiFactory: (user, client) {
        api = FakeApi(user, client)
          ..inventory = all.map((photo) => remotePhoto(photo.name)).toList();
        return api;
      },
    );
    await service.start(progress.add);
    expect(pages, [0, 1, 2]);
    expect(progress.map((item) => item.completed), [205]);
    expect(progress.single.albumName, '相册 a');
    expect(api.attempts, isEmpty);
    expect((await tasks.list()).single.completedCount, 205);
    final entries = await logs.list();
    expect(entries, hasLength(1));
    expect(entries.single.albumName, '全部相册');
    expect(entries.single.event, '开始同步');
    expect(entries.single.status, LogStatus.success);
    expect(entries.single.message, 'Success');
  });

  test('切换为英语后新日志按英语写入', () async {
    await settings.updateLocale('en');
    photos.albums = {'a': []};
    await tasks.add(['a']);
    await service.start((_) {});
    final entries = await logs.list();
    expect(entries.single.albumName, 'All albums');
    expect(entries.single.event, 'Sync started');
    expect(entries.single.message, 'Success');
  });

  test('核对失败保留旧数量，不提前发布部分扫描结果', () async {
    final all = List.generate(101, (index) => localPhoto('$index.jpg'));
    photos.albums = {'a': all};
    await tasks.add(['a']);
    await tasks.updateProgress('a', 101);
    final progress = <SyncProgress>[];
    photos.onPage = (page) async {
      if (page == 1) throw const ApiException('无法继续读取相册');
    };
    service = SyncService(
      tasks: tasks,
      users: users,
      settings: settings,
      storages: storages,
      rules: rules,
      logs: logs,
      photos: photos,
      apiFactory: (user, client) {
        api = FakeApi(user, client)
          ..inventory = all.map((photo) => remotePhoto(photo.name)).toList();
        return api;
      },
    );
    await service.start(progress.add);
    expect(progress, isEmpty);
    expect((await tasks.list()).single.completedCount, 101);
    expect(api.attempts, isEmpty);
    final entries = await logs.list();
    expect(entries, hasLength(2));
    expect(entries.first.event, '读取相册');
    expect(entries.first.status, LogStatus.failure);
    expect(entries.first.message, '无法继续读取相册');
    expect(entries.last.event, '开始同步');
    expect(entries.last.status, LogStatus.success);
  });

  test('查重失败保留缓存，不发布进度或开始上传', () async {
    photos.albums = {
      'a': [localPhoto('old.jpg'), localPhoto('new.jpg')],
    };
    await tasks.add(['a']);
    await tasks.updateProgress('a', 2);
    final progress = <SyncProgress>[];
    service = SyncService(
      tasks: tasks,
      users: users,
      settings: settings,
      storages: storages,
      rules: rules,
      logs: logs,
      photos: photos,
      apiFactory: (user, client) {
        api = FakeApi(user, client)
          ..inventoryError = const ApiException('查重失败', statusCode: 400);
        return api;
      },
    );

    await service.start(progress.add);

    expect(progress, isEmpty);
    expect(api.attempts, isEmpty);
    expect((await tasks.list()).single.completedCount, 2);
    expect((await logs.list(failuresOnly: true)).single.event, '远程检测');
    expect((await logs.list(failuresOnly: true)).single.message, '查重失败');
  });

  test('重新开启同步时保留上轮进度，直到本轮核对完成', () async {
    photos.albums = {
      'a': [localPhoto('cached.jpg')],
    };
    await tasks.add(['a']);
    service = SyncService(
      tasks: tasks,
      users: users,
      settings: settings,
      storages: storages,
      rules: rules,
      logs: logs,
      photos: photos,
      apiFactory: (user, client) {
        api = FakeApi(user, client)..inventory = [remotePhoto('cached.jpg')];
        return api;
      },
    );
    final provider = SyncProvider(service: service);
    addTearDown(provider.dispose);
    await provider.start();
    expect(provider.progress['a']?.completed, 1);
    var checked = false;
    photos.onPage = (_) async {
      checked = true;
      expect(provider.progress['a']?.completed, 1);
      expect(provider.checking, isTrue);
      expect(provider.currentAlbumName, '相册 a');
    };
    await provider.start();
    expect(checked, isTrue);
    expect(provider.progress['a']?.completed, 1);
    expect(provider.error, isNull);
    final entries = await logs.list();
    expect(entries.map((entry) => entry.event), ['开始同步', '开始同步']);
    expect(entries.every((entry) => entry.status == LogStatus.success), isTrue);
  });

  test('按本地相册名关联已有照片，跨相册仅上传一次并保存张数', () async {
    final existing = localPhoto('old.jpg');
    final missing = localPhoto('new.jpg');
    photos.albums = {
      'a': [existing, missing],
      'b': [missing],
    };
    await tasks.add(['a', 'b']);
    final progress = <SyncProgress>[];
    final activeAlbums = <String?>[];
    photos.onPage = (_) async {
      expect(activeAlbums.last, isNotNull);
      if (activeAlbums.last == 'a') expect(progress, isEmpty);
    };
    service = SyncService(
      tasks: tasks,
      users: users,
      settings: settings,
      storages: storages,
      rules: rules,
      logs: logs,
      photos: photos,
      apiFactory: (user, client) {
        api = FakeApi(user, client)..inventory = [remotePhoto('old.jpg')];
        return api;
      },
    );
    await service.start(progress.add, onAlbumChanged: activeAlbums.add);

    expect(activeAlbums, ['a', 'b', null]);
    expect(api.albumNames, ['相册 a', '相册 b']);
    expect(api.checkAlbumIds, ['remote-相册 a', 'remote-相册 b']);
    expect(api.attempts, {'new.jpg': 1});
    expect(photos.opened, ['new.jpg']);
    final records = await tasks.list();
    expect(records.map((task) => task.completedCount), [2, 1]);
    expect(records.map((task) => task.ruleName).toSet(), {'Default Rule'});
    expect(progress.last.total, 1);
    expect((await settings.get()).taskStatus, 2);
    expect((await settings.get()).lastSyncAt, isNotNull);
    expect((await logs.list()).single.event, '开始同步');
  });

  test('暂时失败重试复用上传锁，重复响应仍补齐相册关联', () async {
    photos.albums = {
      'a': [localPhoto('retry.jpg')],
    };
    await tasks.add(['a']);
    service = SyncService(
      tasks: tasks,
      users: users,
      settings: settings,
      storages: storages,
      rules: rules,
      logs: logs,
      photos: photos,
      apiFactory: (user, client) {
        api = FakeApi(user, client)
          ..failFirst = true
          ..duplicate = true;
        return api;
      },
    );
    await service.start((_) {});
    expect(api.attempts['retry.jpg'], 2);
    expect((await logs.list()).map((entry) => entry.event), ['开始同步']);
    expect(api.locks.toSet(), hasLength(1));
    expect((await tasks.list()).single.completedCount, 1);
  });

  test('单张业务失败不重试，其余照片继续且失败不计入张数', () async {
    photos.albums = {
      'a': [localPhoto('bad.jpg'), localPhoto('good.jpg')],
    };
    await tasks.add(['a']);
    service = SyncService(
      tasks: tasks,
      users: users,
      settings: settings,
      storages: storages,
      rules: rules,
      logs: logs,
      photos: photos,
      apiFactory: (user, client) {
        api = FakeApi(user, client)..badName = 'bad.jpg';
        return api;
      },
    );
    final activeAlbums = <String?>[];
    await service.start((_) {}, onAlbumChanged: activeAlbums.add);
    expect(activeAlbums, ['a', null]);
    expect(api.attempts, {'bad.jpg': 1, 'good.jpg': 1});
    final entries = await logs.list();
    expect(entries, hasLength(2));
    expect(entries.first.event, 'bad.jpg');
    expect(entries.first.albumName, '相册 a');
    expect(entries.first.status, LogStatus.failure);
    expect(entries.first.message, '不支持的图片');
    expect(entries.last.event, '开始同步');
    expect(entries.last.status, LogStatus.success);
    expect((await tasks.list()).single.completedCount, 1);
    expect((await settings.get()).lastSyncAt, isNotNull);
    expect((await settings.get()).taskStatus, 2);
  });

  test('不同文件抛出同一个异常对象时仍分别记录失败', () async {
    photos.albums = {
      'a': [localPhoto('first.jpg'), localPhoto('second.jpg')],
    };
    await tasks.add(['a']);
    service = SyncService(
      tasks: tasks,
      users: users,
      settings: settings,
      storages: storages,
      rules: rules,
      photos: photos,
      logs: logs,
      apiFactory: (user, client) {
        api = FakeApi(user, client)
          ..onUpload = (_) async {
            throw const ApiException('不支持的图片', statusCode: 400);
          };
        return api;
      },
    );
    await service.start((_) {});
    final entries = await logs.list(failuresOnly: true);
    expect(entries.map((entry) => entry.event).toSet(), {
      'first.jpg',
      'second.jpg',
    });
    expect(entries, hasLength(2));
  });

  test('停止正在上传的任务，不领取下一张且不计入取消后的成功', () async {
    photos.albums = {
      'a': [localPhoto('first.jpg'), localPhoto('second.jpg')],
    };
    await tasks.add(['a']);
    final entered = Completer<void>();
    final finish = Completer<void>();
    service = SyncService(
      tasks: tasks,
      users: users,
      settings: settings,
      storages: storages,
      rules: rules,
      logs: logs,
      photos: photos,
      apiFactory: (user, client) {
        api = FakeApi(user, client)
          ..onUpload = (_) async {
            entered.complete();
            await finish.future;
          };
        return api;
      },
    );
    final activeAlbums = <String?>[];
    final operation = service.start((_) {}, onAlbumChanged: activeAlbums.add);
    expect(service.start((_) {}), same(operation));
    await entered.future;
    expect(activeAlbums, ['a']);
    final stopping = service.stop();
    finish.complete();
    await stopping;
    await operation;
    expect(activeAlbums, ['a', null]);
    expect(api.attempts, {'first.jpg': 1});
    expect(await logs.list(failuresOnly: true), isEmpty);
    expect((await logs.list()).map((entry) => entry.event), ['开始同步']);
    expect((await tasks.list()).single.completedCount, 0);
    expect((await settings.get()).taskStatus, 2);
    expect((await settings.get()).lastSyncAt, isNull);
  });

  test('并发上传不超过设置值', () async {
    photos.albums = {
      'a': List.generate(6, (index) => localPhoto('$index.jpg')),
    };
    await tasks.add(['a']);
    await settings.updateUploadConcurrency(3);
    var active = 0;
    var peak = 0;
    service = SyncService(
      tasks: tasks,
      users: users,
      settings: settings,
      storages: storages,
      rules: rules,
      logs: logs,
      photos: photos,
      apiFactory: (user, client) {
        api = FakeApi(user, client)
          ..onUpload = (_) async {
            active++;
            if (active > peak) peak = active;
            await Future<void>.delayed(const Duration(milliseconds: 20));
            active--;
          };
        return api;
      },
    );
    final progress = <SyncProgress>[];
    await service.start(progress.add);
    expect(peak, 3);
    expect(progress.map((item) => item.completed), [0, 1, 2, 3, 4, 5, 6]);
    expect((await tasks.list()).single.completedCount, 6);
  });

  test('上传时后缀和文件头都要在白名单内', () async {
    photos.headers['mismatch.jpg'] = const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ];
    photos.headers['broken.jpg'] = const [1, 2, 3, 4];
    photos.headers['clip.mp4'] = const [
      0x00, 0x00, 0x00, 0x18, //
      0x66, 0x74, 0x79, 0x70, // ftyp
      0x71, 0x74, 0x20, 0x20, // qt
    ];
    photos.headers['bad.mp4'] = const [1, 2, 3, 4];
    photos.headers['phone.heic'] = [0, 0, 0, 24, ...'ftypheic'.codeUnits];
    photos.headers['camera.HIF'] = [0, 0, 0, 24, ...'ftypmif1'.codeUnits];
    photos.headers['photo.HEIF'] = [0, 0, 0, 24, ...'ftypmif1'.codeUnits];
    photos.headers['broken.heic'] = const [1, 2, 3, 4];
    photos.headers['broken.hif'] = const [1, 2, 3, 4];
    photos.headers['broken.heif'] = const [1, 2, 3, 4];
    photos.albums = {
      'a': [
        localPhoto('keep.jpg'),
        localPhoto('mismatch.jpg'),
        localPhoto('broken.jpg'),
        localPhoto('phone.heic'),
        localPhoto('camera.HIF'),
        localPhoto('photo.HEIF'),
        localPhoto('broken.heic'),
        localPhoto('broken.hif'),
        localPhoto('broken.heif'),
        localPhoto('skip.bmp'),
        localPhoto('clip.mp4'),
        localPhoto('bad.mp4'),
        const SyncPhoto(
          name: 'raw',
          size: 123,
          path: 'raw',
          mimeType: 'image/jpeg',
        ),
      ],
    };
    await tasks.add(['a']);
    await service.start((_) {});
    expect(api.attempts.keys, {
      'keep.jpg',
      'mismatch.jpg',
      'phone.heic',
      'camera.HIF',
      'photo.HEIF',
      'clip.mp4',
    });
    expect(
      photos.opened,
      unorderedEquals([
        'keep.jpg',
        'mismatch.jpg',
        'broken.jpg',
        'phone.heic',
        'camera.HIF',
        'photo.HEIF',
        'broken.heic',
        'broken.hif',
        'broken.heif',
        'clip.mp4',
        'bad.mp4',
      ]),
    );
    expect(await logs.list(failuresOnly: true), isEmpty);
    expect((await tasks.list()).single.completedCount, 6);
  });

  test('完成一轮后保持定时开启，停止可立即结束等待', () async {
    photos.albums = {'a': []};
    await tasks.add(['a']);
    await settings.updateTaskInterval(10);
    final waiting = service.activities.firstWhere(
      (activity) => activity.nextSyncAt != null,
    );
    final operation = service.start((_) {});
    final activity = await waiting.timeout(const Duration(seconds: 5));
    final saved = await settings.get();
    expect(
      activity.nextSyncAt,
      DateTime.parse(saved.lastSyncAt!).add(const Duration(minutes: 10)),
    );
    expect((await settings.get()).taskStatus, 1);
    expect((await logs.list()).map((entry) => entry.event), ['开始同步']);
    await service.stop().timeout(const Duration(seconds: 1));
    await operation;
    expect((await settings.get()).taskStatus, 2);
    expect((await logs.list()).map((entry) => entry.event), ['开始同步']);
  });

  for (final hasLastSync in [false, true]) {
    test(
      '读取存储失败后等待下一轮，${hasLastSync ? '旧同步时间不会导致立即重试' : '首次同步也可等待'}',
      () async {
        photos.albums = {
          'a': [localPhoto('pending.jpg')],
        };
        await tasks.add(['a']);
        await tasks.updateProgress('a', 7);
        await storages.save([
          const Storage(id: 'cached', name: '缓存存储', type: 1),
        ], account: (await users.get())!);
        if (hasLastSync) {
          await (await database.database).update(
            'settings',
            {
              'last_sync_at': DateTime.now()
                  .toUtc()
                  .subtract(const Duration(days: 1))
                  .toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: ['setting'],
          );
        }
        await settings.updateTaskInterval(10);
        service = SyncService(
          tasks: tasks,
          users: users,
          settings: settings,
          storages: storages,
          rules: rules,
          logs: logs,
          photos: photos,
          apiFactory: (user, client) {
            api = FakeApi(user, client)
              ..onReadStorages = () async {
                throw const ApiException('Network error');
              };
            return api;
          },
        );
        final waiting = service.activities.firstWhere(
          (activity) => activity.nextSyncAt != null,
        );
        final activeAlbums = <String?>[];
        final progress = <SyncProgress>[];
        final operation = service.start(
          progress.add,
          onAlbumChanged: activeAlbums.add,
        );
        final activity = await waiting.timeout(const Duration(seconds: 5));
        final saved = await settings.get();

        expect(api.storageReads, 3);
        expect(await service.isRunning, isTrue);
        expect(saved.taskStatus, 1);
        expect(
          activity.nextSyncAt,
          DateTime.parse(saved.lastSyncAt!).add(const Duration(minutes: 10)),
        );
        expect(activity.nextSyncAt!.isAfter(DateTime.now().toUtc()), isTrue);
        expect(activeAlbums, ['a', null]);
        expect(progress, isEmpty);
        expect(api.attempts, isEmpty);
        expect((await tasks.list()).single.completedCount, 7);
        expect((await storages.list()).single.id, 'cached');
        final failures = await logs.list(failuresOnly: true);
        expect(failures, hasLength(1));
        expect(failures.single.event, '读取存储');
        expect(failures.single.message, 'Network error');

        await service.stop().timeout(const Duration(seconds: 1));
        await operation;
        expect((await settings.get()).taskStatus, 2);
        expect(await logs.list(failuresOnly: true), hasLength(1));
      },
    );
  }

  for (final recovers in [false, true]) {
    test('读取存储失败后下一轮${recovers ? '恢复并上传' : '仍失败也分别记录日志'}', () async {
      photos.albums = {
        'a': [localPhoto('pending.jpg')],
      };
      await tasks.add(['a']);
      final scheduledSettings = DueSettings(database: database);
      await scheduledSettings.updateTaskInterval(1);
      service = SyncService(
        tasks: tasks,
        users: users,
        settings: scheduledSettings,
        storages: storages,
        rules: rules,
        logs: logs,
        photos: photos,
        apiFactory: (user, client) {
          api = FakeApi(user, client)
            ..onReadStorages = () async {
              if (!recovers || api.storageReads <= 3) {
                throw const ApiException('Network error');
              }
            };
          return api;
        },
      );

      await service.start((_) {}).timeout(const Duration(seconds: 10));

      expect(scheduledSettings.rounds, 2);
      expect(api.storageReads, recovers ? 4 : 6);
      expect(api.attempts, recovers ? {'pending.jpg': 1} : isEmpty);
      expect((await tasks.list()).single.completedCount, recovers ? 1 : 0);
      final failures = await logs.list(failuresOnly: true);
      expect(failures, hasLength(recovers ? 1 : 2));
      expect(failures.every((entry) => entry.event == '读取存储'), isTrue);
      expect(
        (await logs.list()).where((entry) => entry.event == '开始同步'),
        hasLength(2),
      );
    });
  }

  for (final status in [401, 403]) {
    test('读取存储时 $status 登录失效仍终止同步', () async {
      photos.albums = {'a': []};
      await tasks.add(['a']);
      await settings.updateTaskInterval(10);
      service = SyncService(
        tasks: tasks,
        users: users,
        settings: settings,
        storages: storages,
        rules: rules,
        logs: logs,
        photos: photos,
        apiFactory: (user, client) {
          api = FakeApi(user, client)
            ..onReadStorages = () async {
              throw ApiException('Sign in again', statusCode: status);
            };
          return api;
        },
      );

      await expectLater(
        service.start((_) {}),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', status),
        ),
      );

      expect(api.storageReads, 1);
      expect((await settings.get()).taskStatus, 2);
      expect((await settings.get()).lastSyncAt, isNull);
      expect(await logs.list(failuresOnly: true), hasLength(1));
    });
  }

  test('读取存储期间账户退出仍终止同步', () async {
    photos.albums = {'a': []};
    await tasks.add(['a']);
    await settings.updateTaskInterval(10);
    service = SyncService(
      tasks: tasks,
      users: users,
      settings: settings,
      storages: storages,
      rules: rules,
      logs: logs,
      photos: photos,
      apiFactory: (user, client) {
        api = FakeApi(user, client)
          ..onReadStorages = () async {
            await users.remove('user');
            throw const ApiException('Network error');
          };
        return api;
      },
    );

    await expectLater(
      service.start((_) {}),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Account changed, start sync again',
        ),
      ),
    );

    expect((await settings.get()).taskStatus, 2);
    expect((await settings.get()).lastSyncAt, isNull);
    expect(api.attempts, isEmpty);
  });

  test('未登录时阻止访问图库和上传', () async {
    await users.remove('user');
    await expectLater(
      service.start((_) {}),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Sign in first',
        ),
      ),
    );
    expect(photos.checkedPermission, isFalse);
  });

  test('定时下一轮开始时再次记录成功事件，等待期间不重复记录', () async {
    photos.albums = {
      'a': [localPhoto('one.jpg')],
    };
    await tasks.add(['a']);
    final scheduledSettings = DueSettings(database: database);
    await scheduledSettings.updateTaskInterval(1);
    service = SyncService(
      tasks: tasks,
      users: users,
      settings: scheduledSettings,
      storages: storages,
      rules: rules,
      logs: logs,
      photos: photos,
      apiFactory: (user, client) => api = FakeApi(user, client),
    );

    await service.start((_) {});

    expect(scheduledSettings.rounds, 2);
    expect(api.storageReads, 2);
    expect(api.albumNames, ['相册 a', '相册 a']);
    final entries = await logs.list();
    expect(entries.map((entry) => entry.event), ['开始同步', '开始同步']);
    expect(entries.every((entry) => entry.albumName == '全部相册'), isTrue);
    expect(entries.every((entry) => entry.status == LogStatus.success), isTrue);
    expect(entries.every((entry) => entry.message == 'Success'), isTrue);
  });

  for (final missingAlbum in [true, false]) {
    test('${missingAlbum ? '相册失效' : '任务核对失败'}后继续其他任务和下一轮定时同步', () async {
      photos.albums = {
        'a': List.generate(101, (index) => localPhoto('$index.jpg')),
        'b': [localPhoto('good.jpg')],
      };
      if (missingAlbum) {
        photos.albums.remove('a');
      } else {
        photos.onPage = (page) async {
          if (page == 1) throw const ApiException('无法继续读取相册');
        };
      }
      await tasks.add(['a', 'b']);
      await tasks.updateProgress('a', 12);
      final scheduledSettings = DueSettings(database: database);
      await scheduledSettings.updateTaskInterval(1);
      service = SyncService(
        tasks: tasks,
        users: users,
        settings: scheduledSettings,
        storages: storages,
        rules: rules,
        logs: logs,
        photos: photos,
        apiFactory: (user, client) => api = FakeApi(user, client),
      );

      await service.start((_) {}).timeout(const Duration(seconds: 5));

      expect(scheduledSettings.rounds, 2);
      expect(api.storageReads, 2);
      expect(api.albumNames.where((name) => name == '相册 b'), hasLength(2));
      expect(api.attempts, {'good.jpg': 1});
      expect((await tasks.list()).map((task) => task.completedCount), [12, 1]);
      final failures = await logs.list(failuresOnly: true);
      expect(failures, hasLength(2));
      expect(failures.every((entry) => entry.event == '读取相册'), isTrue);
      expect(
        (await logs.list()).where((entry) => entry.event == '开始同步'),
        hasLength(2),
      );
    });
  }

  test('远端差异检查失败只记录一次失败，并保留开始同步事件', () async {
    photos.albums = {
      'a': [localPhoto('one.jpg')],
    };
    await tasks.add(['a']);
    service = SyncService(
      tasks: tasks,
      users: users,
      settings: settings,
      storages: storages,
      rules: rules,
      logs: logs,
      photos: photos,
      apiFactory: (user, client) {
        api = FakeApi(user, client)
          ..inventoryError = const ApiException('远端检查失败', statusCode: 400);
        return api;
      },
    );

    await service.start((_) {});

    final entries = await logs.list();
    expect(entries, hasLength(2));
    expect(entries.first.event, '远程检测');
    expect(entries.first.status, LogStatus.failure);
    expect(entries.first.message, '远端检查失败');
    expect(entries.last.event, '开始同步');
    expect(entries.last.status, LogStatus.success);
  });

  test('按各任务选择的存储上传，保留卡片存储名称', () async {
    photos.albums = {
      'a': [localPhoto('cloud.jpg')],
      'b': [localPhoto('disk.jpg')],
    };
    await saveTestRule(
      database,
      testRule(id: 's3-rule', name: '云端规则', storageId: 's3'),
    );
    await saveTestRule(database, testRule(id: 'local-rule', name: '本地规则'));
    await tasks.add(['a'], rule: testRule(id: 's3-rule', name: '云端规则'));
    await tasks.add(['b'], rule: testRule(id: 'local-rule', name: '本地规则'));
    await service.start((_) {});
    expect(api.storageReads, 1);
    expect(api.uploadStorages, ['s3', 'local-id']);
    final records = await tasks.list();
    expect(records.map((task) => task.ruleName), ['云端规则', '本地规则']);
    expect((await storages.list()).map((item) => item.id), ['local-id', 's3']);
    expect(records.map((task) => task.completedCount), [1, 1]);
  });

  test('所选存储失效时记录失败并跳过，不自动切到其他存储', () async {
    await storages.save([
      const Storage(id: 'deleted', name: '已删除存储', type: 3),
    ], account: (await users.get())!);
    photos.albums = {
      'a': [
        localPhoto('old.jpg'),
        localPhoto('missing.jpg'),
        localPhoto('missing2.jpg'),
      ],
    };
    await saveTestRule(
      database,
      testRule(id: 'deleted-rule', name: '失效存储规则', storageId: 'deleted'),
    );
    await tasks.add(['a'], rule: testRule(id: 'deleted-rule', name: '失效存储规则'));
    await tasks.updateProgress('a', 12);
    service = SyncService(
      tasks: tasks,
      users: users,
      settings: settings,
      storages: storages,
      rules: rules,
      logs: logs,
      photos: photos,
      apiFactory: (user, client) {
        api = FakeApi(user, client)..inventory = [remotePhoto('old.jpg')];
        return api;
      },
    );
    await service.start((_) {});
    expect(api.uploadStorages, isEmpty);
    expect(api.checkedFiles.single, hasLength(3));
    expect((await tasks.list()).single.completedCount, 1);
    final entries = await logs.list();
    expect(entries, hasLength(2));
    expect(entries.first.event, '读取存储');
    expect(entries.first.status, LogStatus.failure);
    expect(entries.first.message, 'Storage unavailable');
    expect(entries.last.event, '开始同步');
    expect(entries.last.status, LogStatus.success);
    expect((await tasks.list()).single.ruleId, 'deleted-rule');
    expect((await tasks.list()).single.ruleName, '失效存储规则');
    expect(
      (await storages.list()).any((item) => item.id == 'deleted'),
      isFalse,
    );
  });
}

/// 为既有同步场景显式关联默认规则。
class _SyncTasks extends TaskService {
  _SyncTasks(Db database) : super(database: database);

  @override
  Future<void> add(List<String> albumIds, {Rule? rule, User? account}) =>
      super.add(
        albumIds,
        rule: rule ?? testRule(id: 'default', name: 'Default Rule'),
        account: account,
      );
}

/// 将第一轮完成时间设为已到期，第二轮后结束定时，避免测试实际等待。
class DueSettings extends SettingsService {
  /// 复用测试数据库。
  DueSettings({required super.database});

  /// 已完成的同步轮数。
  int rounds = 0;

  /// 第一轮完成后返回已到期时间，直接进入下一次定时同步。
  @override
  Future<Settings> get() async {
    final settings = await super.get();
    if (rounds != 1) return settings;
    return settings.copyWith(
      lastSyncAt: DateTime.parse(settings.lastSyncAt!)
          .subtract(const Duration(minutes: 2))
          .toIso8601String(),
    );
  }

  /// 第二轮完成后关闭定时，结束测试流程。
  @override
  Future<void> updateLastSyncAt() async {
    await super.updateLastSyncAt();
    rounds++;
    if (rounds == 2) await updateTaskInterval(0);
  }
}

/// 创建可复用的本地照片样本。
SyncPhoto localPhoto(String name, {int size = 123}) => SyncPhoto(
  asset: AssetEntity(
    id: name,
    typeInt: isAllowedImageName(name) ? 1 : 2,
    width: 10,
    height: 10,
  ),
  name: name,
  size: size,
);

/// 创建与本地元数据匹配的远端照片。
RemotePhoto remotePhoto(String name, {int size = 123}) => RemotePhoto.fromJson({
  'photoId': 'photo-$name',
  'name': name,
  'size': size,
  'takenTime': '2026-10-27T00:00:00Z',
});

/// 提供不依赖系统图库的分页扫描。
class FakePhotos extends PhotoService {
  Map<String, List<SyncPhoto>> albums = {};
  final Map<String, Uint8List> covers = {};
  int infoReads = 0;

  /// 用指定文件头覆盖默认的 JPEG 头。
  final Map<String, List<int>> headers = {};

  /// 模拟相册删除或暂时无法读取。
  final Map<String, Object> albumErrors = {};
  final List<String> opened = [];
  bool checkedPermission = false;
  bool denyPermission = false;
  Future<void> Function(int)? onPage;

  /// 记录权限检查。缺少权限时抛出提示，由同步流程决定是否继续。
  @override
  Future<void> checkPermission() async {
    checkedPermission = true;
    if (denyPermission) throw const ApiException('Photo access is required');
  }

  /// 恢复指定测试相册。没有预设内容时表示相册不存在。
  @override
  Future<AssetPathEntity?> getAlbum(String id) async {
    if (albumErrors.containsKey(id)) throw albumErrors[id]!;
    final photos = albums[id];
    if (photos == null) return null;
    return FakeAlbum(id, photos.length);
  }

  /// 返回当前张数和预设封面，供同步在数量变化时刷新缓存。
  @override
  Future<PhotoAlbumInfo> getInfo(
    PhotoAlbum album, {
    bool imagesOnly = false,
  }) async {
    infoReads++;
    final photos = albums[album.id] ?? [];
    return PhotoAlbumInfo(
      album: album,
      count: photos.length,
      cover: covers[album.id],
    );
  }

  /// 按页提供预设照片。
  @override
  Stream<List<SyncPhoto>> scan(
    AssetPathEntity album, {
    required bool Function() isStopped,
  }) async* {
    final all = albums[album.id]!;
    for (var start = 0; start < all.length; start += 100) {
      if (isStopped()) return;
      await onPage?.call(start ~/ 100);
      if (isStopped()) return;
      yield all.sublist(start, (start + 100).clamp(0, all.length));
    }
  }

  /// 记录只为缺失文件读取原图，并写入可识别的文件头。
  @override
  Future<File> getFile(SyncPhoto photo, PMCancelToken cancelToken) async {
    opened.add(photo.name);
    directory ??= await Directory.systemTemp.createTemp('sync_photo_');
    final file = File(
      '${directory!.path}${Platform.pathSeparator}${photo.name}',
    );
    final header = headers[photo.name] ?? const [0xFF, 0xD8, 0xFF];
    final length = photo.size.clamp(header.length, 1024);
    final bytes = List<int>.filled(length, 0);
    bytes.setRange(0, header.length, header);
    await file.writeAsBytes(bytes);
    return file;
  }

  /// 删除测试期间写出的临时图片。
  Future<void> dispose() async {
    final current = directory;
    directory = null;
    if (current != null && await current.exists()) {
      await current.delete(recursive: true);
    }
  }

  Directory? directory;
}

/// 使用固定张数替代平台相册查询。
class FakeAlbum extends AssetPathEntity {
  /// 创建测试相册。
  FakeAlbum(String id, this.count)
    : super(id: id, name: '相册 $id', type: RequestType.image);

  final int count;

  /// 返回本地照片总数。
  @override
  Future<int> get assetCountAsync async => count;
}

/// 模拟服务端查重、关联、重试和并发上传。
class FakeApi extends SyncApi {
  /// 复用本轮账户和网络客户端。
  FakeApi(super.user, super.client);

  List<RemotePhoto> inventory = [];
  final Map<String, int> attempts = {};
  final List<String> albumNames = [];
  final List<String> checkAlbumIds = [];
  final List<String> locks = [];
  final List<String> uploadStorages = [];
  final Map<String, String> uploadTargets = {};
  final List<List<SyncFile>> checkedFiles = [];
  List<Storage> storages = [
    const Storage(id: 'local-id', name: '本地照片', type: 1),
    const Storage(id: 's3', name: '云存储', type: 3),
  ];
  int storageReads = 0;
  bool failFirst = false;
  bool duplicate = false;
  String? badName;
  ApiException? inventoryError;
  Future<void> Function()? onReadStorages;
  Future<void> Function(List<SyncFile>)? onCheck;
  Future<void> Function(SyncPhoto)? onUpload;

  /// 返回固定的本地存储。
  @override
  Future<List<Storage>> getStorages() async {
    storageReads++;
    await onReadStorages?.call();
    return storages;
  }

  /// 保存实际使用的本地相册名称。
  @override
  Future<String> getAlbum(String name) async {
    albumNames.add(name);
    return 'remote-$name';
  }

  /// 返回远端还不存在的文件，供上传队列使用。
  @override
  Future<List<SyncFile>> check(String albumId, List<SyncFile> files) async {
    checkAlbumIds.add(albumId);
    checkedFiles.add(files);
    await onCheck?.call(files);
    if (inventoryError != null) throw inventoryError!;
    final keys = {for (final photo in inventory) photo.key};
    return [
      for (final file in files)
        if (!keys.contains(file.key)) file,
    ];
  }

  /// 模拟成功、暂时性失败和业务失败。
  @override
  Future<RemotePhoto?> uploadPhoto(
    SyncPhoto photo,
    File file,
    String albumId,
    String storageId,
    String lock,
  ) async {
    uploadStorages.add(storageId);
    uploadTargets[photo.name] = storageId;
    attempts.update(photo.name, (value) => value + 1, ifAbsent: () => 1);
    locks.add(lock);
    if (photo.name == badName) {
      throw const ApiException('不支持的图片', statusCode: 400);
    }
    if (failFirst && attempts[photo.name] == 1) {
      throw const ApiException('网络异常');
    }
    await onUpload?.call(photo);
    if (duplicate) return null;
    final uploaded = remotePhoto(photo.name, size: photo.size);
    inventory.add(uploaded);
    return uploaded;
  }
}
