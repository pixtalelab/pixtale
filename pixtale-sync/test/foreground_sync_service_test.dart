import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pixtale_sync/l10n/localizations_en.dart';
import 'package:pixtale_sync/l10n/localizations_zh.dart';
import 'package:pixtale_sync/models/sync.dart';
import 'package:pixtale_sync/models/user.dart';
import 'package:pixtale_sync/models/task.dart';
import 'package:pixtale_sync/providers/sync_provider.dart';
import 'package:pixtale_sync/request/request.dart';
import 'package:pixtale_sync/services/foreground_sync_service.dart';
import 'package:pixtale_sync/services/log_service.dart';
import 'package:pixtale_sync/services/storage_service.dart';
import 'package:pixtale_sync/services/photo_service.dart';
import 'package:pixtale_sync/services/sync_service.dart';
import 'package:pixtale_sync/services/sync_task_handler.dart';
import 'package:pixtale_sync/services/task_service.dart';

// 验证通知状态、通知停止按钮、后台连接恢复和启动期间取消。

/// 使用模拟原生通道验证前台服务，不请求设备权限或访问远端。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  const channel = MethodChannel('flutter_foreground_task/methods');
  final calls = <MethodCall>[];
  var running = true;
  var permission = NotificationPermission.granted;

  setUp(() {
    calls.clear();
    running = true;
    permission = NotificationPermission.granted;
    FlutterForegroundTask.resetStatic();
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.skipServiceResponseCheck = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'test',
        channelName: 'test',
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: syncTaskOptions(),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'isRunningService':
              return running;
            case 'startService':
              running = true;
            case 'stopService':
              running = false;
            case 'checkNotificationPermission':
            case 'requestNotificationPermission':
              return permission.index;
          }
          return null;
        });
  });

  tearDown(() {
    FlutterForegroundTask.resetStatic();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('检查、上传、等待及下一轮通知，等待期间释放唤醒锁', () async {
    final sync = ControlledSync();
    final handler = SyncTaskHandler(
      sync: sync,
      tasks: MemoryTasks(),
      logs: LogService(),
      text: AppLocalizationsEn(),
    );
    addTearDown(() => handler.onDestroy(DateTime.now(), false));
    await handler.onStart(DateTime.now(), TaskStarter.developer);
    await sync.started.future;
    sync.selectAlbum('a');
    handler.onRepeatEvent(DateTime.now());
    await _flush();
    expect(_notification(calls)['notificationContentTitle'], 'Syncing · 相机');
    expect(_notification(calls)['notificationContentText'], 'Checking remotely');

    sync.report(_progress);
    handler.onRepeatEvent(DateTime.now());
    await _flush();
    expect(_notification(calls)['notificationContentTitle'], 'Syncing · 相机');
    expect(_notification(calls)['notificationContentText'], '35 / 123 photos');

    sync.selectAlbum('b');
    await _flush();
    expect(_notification(calls)['notificationContentTitle'], 'Syncing · 旅行');
    expect(_notification(calls)['notificationContentText'], 'Checking remotely');

    sync.selectAlbum(null);
    await _flush();
    expect(_notification(calls)['notificationContentTitle'], 'Syncing · 旅行');

    final next = DateTime.now().copyWith(hour: 14, minute: 30);
    sync.publishActivity(SyncActivity(nextSyncAt: next));
    await _flush();
    expect(_notification(calls)['notificationContentTitle'], 'Waiting for next sync');
    expect(_notification(calls)['notificationContentText'], 'Next sync: 14:30');
    expect(_notification(calls)['allowWakeLock'], false);
    expect(running, true);

    sync.publishActivity(const SyncActivity());
    sync.selectAlbum('a');
    await _flush();
    handler.onRepeatEvent(DateTime.now());
    await _flush();
    expect(_notification(calls)['notificationContentTitle'], 'Syncing · 相机');
    expect(_notification(calls)['allowWakeLock'], true);
  });

  test('中文环境下通知使用中文', () async {
    final sync = ControlledSync();
    final handler = SyncTaskHandler(
      sync: sync,
      tasks: MemoryTasks(),
      logs: LogService(),
      text: AppLocalizationsZh(),
    );
    addTearDown(() => handler.onDestroy(DateTime.now(), false));
    await handler.onStart(DateTime.now(), TaskStarter.developer);
    await sync.started.future;
    sync.selectAlbum('a');
    handler.onRepeatEvent(DateTime.now());
    await _flush();
    expect(_notification(calls)['notificationContentTitle'], '正在同步 · 相机');
    expect(_notification(calls)['notificationContentText'], '正在远程检测');

    sync.report(_progress);
    handler.onRepeatEvent(DateTime.now());
    await _flush();
    expect(_notification(calls)['notificationContentTitle'], '正在同步 · 相机');
    expect(_notification(calls)['notificationContentText'], '35 / 123 张照片');

    sync.selectAlbum(null);
    final next = DateTime.now().copyWith(hour: 14, minute: 30);
    sync.publishActivity(SyncActivity(nextSyncAt: next));
    await _flush();
    expect(_notification(calls)['notificationContentTitle'], '等待下次同步');
    expect(_notification(calls)['notificationContentText'], '下次同步：14:30');
  });

  test('通知停止按钮会取消同步并关闭服务，重复点击不重复停止', () async {
    final sync = ControlledSync();
    final handler = SyncTaskHandler(
      sync: sync,
      tasks: MemoryTasks(),
      logs: LogService(),
      text: AppLocalizationsEn(),
    );
    addTearDown(() => handler.onDestroy(DateTime.now(), false));
    await handler.onStart(DateTime.now(), TaskStarter.developer);
    await sync.started.future;
    handler.onNotificationButtonPressed('stop');
    handler.onNotificationButtonPressed('stop');
    await _flush();
    expect(sync.stops, 1);
    expect(running, false);
    expect(calls.where((call) => call.method == 'stopService'), hasLength(1));
  });

  test('页面重新进入恢复后台快照，页面释放不停止后台任务', () async {
    final proxy = ForegroundSyncService();
    final provider = SyncProvider(service: proxy);
    await _flush();
    expect(provider.active, true);
    expect(calls.where((call) => call.method == 'startService'), isEmpty);
    final next = DateTime.utc(2026, 10, 27, 6, 30);
    _send('snapshot', {
      'albumId': null,
      'activity': SyncActivity(nextSyncAt: next).toJson(),
      'progress': [_progress.toJson()],
    });
    await _flush();
    expect(provider.progress['a']?.completed, 35);
    expect(provider.nextSyncAt, next);
    expect(provider.currentAlbumId, isNull);

    provider.dispose();
    await _flush();
    expect(running, true);
    expect(
      calls.where(
        (call) => call.method == 'sendData' && call.arguments == 'stop',
      ),
      isEmpty,
    );
    expect(calls.where((call) => call.method == 'stopService'), isEmpty);
  });

  test('后台停止消息恢复播放按钮，失败消息传回页面', () async {
    final provider = SyncProvider(service: ForegroundSyncService());
    addTearDown(provider.dispose);
    await _flush();
    _send('activity', {'value': const SyncActivity(stopping: true).toJson()});
    await _flush();
    expect(provider.stopping, true);
    running = false;
    _send('finished', {'error': '网络异常'});
    await _flush();
    expect(provider.active, false);
    expect(provider.stopping, false);
    expect(provider.error, '网络异常');
  });

  test('后台存储、任务更新和重连快照通知主隔离区刷新缓存', () async {
    final proxy = ForegroundSyncService();
    addTearDown(proxy.dispose);
    unawaited(proxy.start((_) {}));
    await _flush();
    final revision = StorageService.changes.value;
    final taskRevision = TaskService.changes.value;
    _send('storages');
    await _flush();
    expect(StorageService.changes.value, revision + 1);
    _send('tasks');
    await _flush();
    expect(TaskService.changes.value, taskRevision + 1);
    _send('snapshot', {
      'albumId': null,
      'activity': const SyncActivity().toJson(),
      'progress': [],
    });
    await _flush();
    expect(StorageService.changes.value, revision + 2);
    expect(TaskService.changes.value, taskRevision + 2);
  });

  test('用户开始时创建通知，包含停止按钮和 dataSync 类型', () async {
    running = false;
    final proxy = ForegroundSyncService(photos: PermissionPhotos());
    addTearDown(proxy.dispose);
    final operation = proxy.start((_) {});
    await _flush();
    final start = calls.singleWhere((call) => call.method == 'startService');
    final arguments = start.arguments as Map;
    expect(arguments['serviceTypes'], [
      ForegroundServiceTypes.dataSync.rawValue,
    ]);
    final button = (arguments['buttons'] as List).single as Map;
    expect(button['id'], 'stop');
    expect(button['text'], 'Stop');
    running = false;
    _send('finished');
    await operation;
  });

  test('启动期间停止不再启动服务，通知权限拒绝时仍继续同步并提示', () async {
    running = false;
    final photos = PermissionPhotos()..pending = Completer<void>();
    final proxy = ForegroundSyncService(photos: photos);
    final operation = proxy.start((_) {});
    await _flush();
    final stopping = proxy.stop();
    photos.pending!.complete();
    await operation;
    await stopping;
    proxy.dispose();
    expect(calls.where((call) => call.method == 'startService'), isEmpty);

    calls.clear();
    permission = NotificationPermission.denied;
    final notices = <String>[];
    final denied = ForegroundSyncService(photos: PermissionPhotos());
    addTearDown(denied.dispose);
    final deniedRun = denied.start((_) {}, onNotice: notices.add);
    await _flush();
    expect(notices.single, 'Notifications are required for background sync');
    expect(calls.where((call) => call.method == 'startService'), isNotEmpty);
    expect(running, isTrue);
    running = false;
    _send('finished');
    await deniedRun;
  });

  test('没有照片权限时不启动同步并返回原因', () async {
    running = false;
    final denied = ForegroundSyncService(
      photos: PermissionPhotos()..deny = true,
    );
    addTearDown(denied.dispose);
    await expectLater(
      denied.start((_) {}),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Photo access is required',
        ),
      ),
    );
    expect(calls.where((call) => call.method == 'startService'), isEmpty);
  });
}

/// 固定上传进度，用于验证通知和页面恢复。
const _progress = SyncProgress(
  albumId: 'a',
  completed: 35,
  total: 123,
  storageName: '本地存储',
);

/// 等待隔离区消息、服务回调和模拟通道完成。
Future<void> _flush() => Future<void>.delayed(const Duration(milliseconds: 20));

/// 读取最近一次通知更新。
Map<dynamic, dynamic> _notification(List<MethodCall> calls) =>
    calls.lastWhere((call) => call.method == 'updateService').arguments as Map;

/// 模拟后台通过通信端口发送消息。
void _send(String type, [Map<String, Object?> values = const {}]) {
  FlutterForegroundTask.sendDataToMain({
    'source': 'sync',
    'type': type,
    ...values,
  });
}

/// 提供任务名缓存，不访问 SQLite。
class MemoryTasks extends TaskService {
  /// 返回测试相册。
  @override
  Future<List<Task>> list({User? account}) async => [
    Task(albumId: 'a', sortTime: DateTime.utc(2026), albumName: '相机'),
    Task(albumId: 'b', sortTime: DateTime.utc(2026, 1, 2), albumName: '旅行'),
  ];
}

/// 可控制权限完成时机的照片服务。
class PermissionPhotos extends PhotoService {
  Completer<void>? pending;
  bool deny = false;

  /// 模拟前台取得或拒绝图库权限。
  @override
  Future<void> checkPermission() async {
    await pending?.future;
    if (deny) throw const ApiException('Photo access is required');
  }
}

/// 可独立控制上传进度和定时等待的同步服务。
class ControlledSync extends SyncService {
  final started = Completer<void>();
  final finished = Completer<void>();
  void Function(SyncProgress)? _onProgress;
  void Function(String?)? _onAlbum;
  int stops = 0;

  /// 等待测试指令，不访问图库或网络。
  @override
  Future<void> start(
    void Function(SyncProgress) onProgress, {
    void Function(String?)? onAlbumChanged,
    void Function(String message)? onNotice,
  }) async {
    _onProgress = onProgress;
    _onAlbum = onAlbumChanged;
    started.complete();
    await finished.future;
  }

  /// 切换核对中的相册。
  void selectAlbum(String? id) => _onAlbum?.call(id);

  /// 发布本轮上传进度。
  void report(SyncProgress progress) => _onProgress?.call(progress);

  /// 模拟取消后台同步。
  @override
  Future<void> stop() async {
    stops++;
    if (!finished.isCompleted) finished.complete();
  }
}
