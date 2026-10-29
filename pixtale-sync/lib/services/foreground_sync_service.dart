import 'dart:async';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:pixtale_sync/l10n/locale.dart';
import 'package:pixtale_sync/l10n/localizations.dart';
import 'package:pixtale_sync/models/sync.dart';
import 'package:pixtale_sync/request/request.dart';
import 'package:pixtale_sync/services/log_service.dart';
import 'package:pixtale_sync/services/photo_service.dart';
import 'package:pixtale_sync/services/settings_service.dart';
import 'package:pixtale_sync/services/storage_service.dart';
import 'package:pixtale_sync/services/sync_service.dart';
import 'package:pixtale_sync/services/sync_task_handler.dart';
import 'package:pixtale_sync/services/task_service.dart';
import 'package:pixtale_sync/services/user_service.dart';

// Android 同步代理：启动前台服务、连接已有任务并转发页面消息。

/// 页面只连接服务，离开页面不会终止 Android 同步。
class ForegroundSyncService extends SyncService {
  /// 创建前台服务代理，可替换照片权限检查以测试启动流程。
  ForegroundSyncService({PhotoService? photos})
    : _photos = photos ?? PhotoService.create();

  /// 主隔离区只初始化一次通信端口。
  static bool _initialized = false;

  /// 当前只有 Android 使用前台服务，测试沿用可注入的本地实现。
  static bool get supported =>
      Platform.isAndroid && Platform.environment['FLUTTER_TEST'] != 'true';

  /// 根据平台创建同步执行方式。
  static SyncService create({TaskService? tasks}) =>
      supported ? ForegroundSyncService() : SyncService(tasks: tasks);

  /// 按已保存语言取通知文案。未指定语言时跟随系统。
  static AppLocalizations noticeText() {
    return AppLocale.strings(saved: AppLocale.instance.locale?.languageCode);
  }

  /// 配置通知通道和隔离区通信，不在应用启动时请求权限。
  static void initialize() {
    if (!supported || _initialized) return;
    final text = noticeText();
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'photo_sync',
        channelName: text.syncNoticeChannel,
        channelDescription: text.syncNoticeChannelDescription,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: syncTaskOptions(),
    );
    _initialized = true;
  }

  /// 当前页面连接、结束信号和系统服务状态检查。
  final PhotoService _photos;
  Future<void>? _operation;
  Completer<String?>? _finished;
  Timer? _watchdog;
  bool _checking = false;
  bool _received = false;
  bool _stopRequested = false;
  bool _detached = false;

  /// 页面接收进度、当前相册和权限提示的回调。
  void Function(SyncProgress)? _onProgress;
  void Function(String?)? _onAlbumChanged;
  void Function(String message)? _onNotice;

  /// 通知权限不足时改为在当前隔离区同步。
  bool _localSync = false;

  /// 查询系统服务，不依赖上一次页面是否仍存在。
  @override
  Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  /// 连接已有服务，或在用户点击开始后取得权限并启动服务。
  @override
  Future<void> start(
    void Function(SyncProgress) onProgress, {
    void Function(String?)? onAlbumChanged,
    void Function(String message)? onNotice,
  }) {
    if (_operation != null) return _operation!;
    _stopRequested = false;
    _detached = false;
    _localSync = false;
    _onProgress = onProgress;
    _onAlbumChanged = onAlbumChanged;
    _onNotice = onNotice;
    return _operation = _connect().whenComplete(() {
      _detach();
      _operation = null;
    });
  }

  /// 启动或连接后台执行者，并等待同步完成或主动停止。
  Future<void> _connect() async {
    initialize();
    _finished = Completer<String?>();
    _received = false;
    FlutterForegroundTask.addTaskDataCallback(_onData);
    if (!await isRunning) {
      await _photos.checkPermission();
      if (_stopRequested) return;
      var permission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (permission != NotificationPermission.granted) {
        permission =
            await FlutterForegroundTask.requestNotificationPermission();
      }
      if (_stopRequested) return;
      final notificationGranted = permission == NotificationPermission.granted;
      if (!notificationGranted) {
        _onNotice?.call('Notifications are required for background sync');
      }
      final text = noticeText();
      final result = await FlutterForegroundTask.startService(
        serviceId: 1001,
        serviceTypes: const [ForegroundServiceTypes.dataSync],
        notificationTitle: text.syncNoticePreparing,
        notificationText: text.syncNoticeReading,
        notificationIcon: const NotificationIcon(metaDataName: 'sync_icon'),
        notificationButtons: [
          NotificationButton(id: 'stop', text: text.syncNoticeStop),
        ],
        callback: startSyncTask,
      );
      if (result is ServiceRequestFailure && !_finished!.isCompleted) {
        if (_stopRequested) return;
        if (notificationGranted) {
          throw ApiException("Couldn't start background sync: ${result.error}");
        }
        await _runLocally();
        return;
      }
    }
    if (!_detached) {
      FlutterForegroundTask.sendDataToTask('snapshot');
      if (_stopRequested) FlutterForegroundTask.sendDataToTask('stop');
      _watchdog = Timer.periodic(
        const Duration(seconds: 2),
        (_) => unawaited(_checkService()),
      );
    }
    final error = await _finished!.future;
    // 收到结束消息后等待原生服务退出，避免紧接着开始时连到旧服务。
    if (!_detached && await isRunning) {
      await FlutterForegroundTask.stopService();
    }
    if (error != null) throw ApiException(error);
  }

  /// 前台服务因通知权限没有启动时，在当前隔离区继续同步。
  Future<void> _runLocally() async {
    _localSync = true;
    final onProgress = _onProgress;
    if (onProgress == null) return;
    await runSync(
      onProgress,
      onAlbumChanged: _onAlbumChanged,
      onNotice: _onNotice,
    );
  }

  /// 转发进度和活动快照，后台日志变更仅通知页面重新读取。
  void _onData(Object data) {
    if (data is! Map || data['source'] != 'sync') return;
    _received = true;
    switch (data['type']) {
      case 'progress':
        _onProgress?.call(
          SyncProgress.fromJson(
            Map<String, dynamic>.from(data['value'] as Map),
          ),
        );
      case 'album':
        _onAlbumChanged?.call(data['id'] as String?);
      case 'activity':
        publishActivity(
          SyncActivity.fromJson(
            Map<String, dynamic>.from(data['value'] as Map),
          ),
        );
      case 'snapshot':
        StorageService.notifyChanged();
        TaskService.notifyChanged();
        for (final value in data['progress'] as List) {
          _onProgress?.call(
            SyncProgress.fromJson(Map<String, dynamic>.from(value as Map)),
          );
        }
        _onAlbumChanged?.call(data['albumId'] as String?);
        publishActivity(
          SyncActivity.fromJson(
            Map<String, dynamic>.from(data['activity'] as Map),
          ),
        );
      case 'logs':
        LogService.instance.notifyChanged();
      case 'storages':
        StorageService.notifyChanged();
      case 'tasks':
        TaskService.notifyChanged();
      case 'account':
        UserService.changes.value++;
      case 'finished':
        if (_finished?.isCompleted == false) {
          _finished!.complete(data['error'] as String?);
        }
    }
  }

  /// 系统终止服务后恢复页面按钮，初始化期间重发快照或停止命令。
  Future<void> _checkService() async {
    if (_checking || _finished?.isCompleted != false) return;
    _checking = true;
    try {
      if (!await isRunning) {
        await SettingsService.instance.updateTaskStatus(2);
        if (_finished?.isCompleted == false) {
          _finished!.complete('Background sync stopped. Start again.');
        }
      } else {
        if (!_received) FlutterForegroundTask.sendDataToTask('snapshot');
        if (_stopRequested) FlutterForegroundTask.sendDataToTask('stop');
      }
    } catch (_) {
      // 系统服务查询暂时失败时保留连接，下一次检查重试。
    } finally {
      _checking = false;
    }
  }

  /// 等待服务取消请求并保存结束状态，启动途中停止也会生效。
  @override
  Future<void> stop() async {
    if (_operation == null) return;
    _stopRequested = true;
    if (_localSync) {
      requestStop();
      await _operation;
      return;
    }
    publishActivity(const SyncActivity(stopping: true));
    FlutterForegroundTask.sendDataToTask('stop');
    await _operation;
  }

  /// 断开页面连接，保留后台同步和定时等待。
  @override
  void dispose() {
    _detached = true;
    _detach();
    if (_finished?.isCompleted == false) _finished!.complete(null);
  }

  /// 移除页面回调和定时检查，允许页面重新连接。
  void _detach() {
    _watchdog?.cancel();
    _watchdog = null;
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    _onProgress = null;
    _onAlbumChanged = null;
    _onNotice = null;
    _localSync = false;
  }
}
