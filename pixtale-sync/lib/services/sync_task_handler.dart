import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:pixtale_sync/l10n/locale.dart';
import 'package:pixtale_sync/l10n/localizations.dart';
import 'package:pixtale_sync/models/sync.dart';
import 'package:pixtale_sync/request/request.dart';
import 'package:pixtale_sync/services/log_service.dart';
import 'package:pixtale_sync/services/mobile_photo_service.dart';
import 'package:pixtale_sync/services/settings_service.dart';
import 'package:pixtale_sync/services/storage_service.dart';
import 'package:pixtale_sync/services/sync_service.dart';
import 'package:pixtale_sync/services/task_service.dart';
import 'package:pixtale_sync/services/user_service.dart';

// Android 前台服务入口，执行同步并维护进度、等待时间和通知停止按钮。

/// 进入插件创建的后台隔离区并自动注册原生插件。
@pragma('vm:entry-point')
void startSyncTask() {
  FlutterForegroundTask.setTaskHandler(SyncTaskHandler());
}

/// 上传时保持 CPU 运行，等待时释放唤醒锁，不自动重启已结束的同步。
ForegroundTaskOptions syncTaskOptions({bool waiting = false}) =>
    ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(1000),
      allowWakeLock: !waiting,
      allowAutoRestart: false,
      stopWithTask: false,
    );

/// 服务是 Android 同步的唯一执行者，页面只连接状态和发送命令。
class SyncTaskHandler extends TaskHandler {
  /// 创建服务处理器，可注入依赖验证通知和停止行为。
  SyncTaskHandler({
    SyncService? sync,
    TaskService? tasks,
    LogService? logs,
    AppLocalizations? text,
  }) : _sync = sync ?? SyncService(photos: MobilePhotoService(background: true)),
       _tasks = tasks ?? TaskService.instance,
       _logService = logs ?? LogService.instance,
       _text = text;

  /// 后台复用业务服务，照片权限已由页面请求。
  final SyncService _sync;
  final TaskService _tasks;
  final LogService _logService;

  /// 测试固定文案。正式运行时按设置和系统语言读取。
  final AppLocalizations? _text;

  /// 页面断开后保留进度快照，检查期间也不归零已完成数量。
  final Map<String, SyncProgress> _progress = {};
  final Map<String, String> _names = {};
  String? _albumId;
  SyncActivity _activity = const SyncActivity();
  bool _comparing = true;

  /// 后台执行、订阅和通知节流状态。
  Future<void>? _operation;
  Future<void> Function()? _expiredSession;
  StreamSubscription<SyncActivity>? _activities;
  StreamSubscription<void>? _logs;
  bool _dirty = true;
  bool _updating = false;
  bool _destroyed = false;
  bool _ended = false;
  bool _stopping = false;
  String? _error;

  /// 监听等待时间和日志变化后开始同步，不阻塞插件启动回调。
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _activities = _sync.activities.listen(_onActivity);
    _logs = _logService.changes.listen((_) => _send('logs'));
    StorageService.changes.addListener(_onStoragesChanged);
    TaskService.changes.addListener(_onTasksChanged);
    _expiredSession = _logoutExpiredSession;
    onUnauthorized = _expiredSession;
    _operation = _run();
  }

  /// 后台请求登录失效时删除用户，并通知页面刷新账户。
  Future<void> _logoutExpiredSession() async {
    final user = await UserService.instance.get();
    if (user != null) await UserService.instance.remove(user.userId);
    _send('account');
    await _stop();
  }

  /// 存储已落库，通知主隔离区刷新任务卡片。
  void _onStoragesChanged() => _send('storages');

  /// 任务失效状态落库后通知主隔离区刷新卡片。
  void _onTasksChanged() => _send('tasks');

  /// 读取任务名称缓存并执行现有的重试、同步和定时间隔逻辑。
  Future<void> _run() async {
    try {
      for (final task in await _tasks.list()) {
        _names[task.albumId] = task.albumName;
      }
      if (_destroyed || _stopping) return;
      await _sync.start(_onProgress, onAlbumChanged: _onAlbumChanged);
    } catch (error) {
      _error = '$error';
    } finally {
      _ended = true;
      _send('finished', {'error': _error});
      if (!_destroyed) unawaited(FlutterForegroundTask.stopService());
    }
  }

  /// 立即发布已落库进度，系统通知则合并为最多每秒更新一次。
  void _onProgress(SyncProgress value) {
    _progress[value.albumId] = value;
    _comparing = false;
    _dirty = true;
    _send('progress', {'value': value.toJson()});
  }

  /// 轮到相册时立刻更新通知标题，保留上轮进度供页面继续展示。
  void _onAlbumChanged(String? id) {
    _albumId = id;
    _comparing = true;
    _dirty = true;
    _send('album', {'id': id});
    unawaited(_updateNotification());
  }

  /// 等待时展示下次同步时间，通知停止按钮持续可用。
  void _onActivity(SyncActivity value) {
    _activity = value;
    _dirty = true;
    _send('activity', {'value': value.toJson()});
    unawaited(_updateNotification());
  }

  /// 合并上传进度更新，避免高并发上传时频繁刷新通知。
  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_updateNotification());
  }

  /// 显示检查、上传、等待或停止中的通知，服务销毁后不再更新。
  Future<void> _updateNotification() async {
    if (!_dirty || _updating || _destroyed || _ended) return;
    _dirty = false;
    _updating = true;
    try {
      final text = await _noticeText();
      final next = _activity.nextSyncAt?.toLocal();
      final progress = _comparing ? null : _progress[_albumId];
      final syncing = _albumId != null && !_stopping;
      final waiting = !_stopping && !syncing && next != null;
      // 相册切换的空档还没进入定时等待，保持上一条通知。
      if (!_stopping && !syncing && !waiting) return;
      final title = _stopping
          ? text.syncNoticeStopping
          : syncing
          ? _withAlbum(text.syncNoticeSyncing, _names[_albumId])
          : text.syncNoticeWaiting;
      final body = _stopping
          ? text.syncNoticeCancelling
          : syncing
          ? progress == null
                ? text.syncNoticeChecking
                : text.photoCount(progress.completed, progress.total)
          : next != null
          ? text.syncNoticeNext(_formatTime(next))
          : text.syncNoticeWaiting;
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: body,
        foregroundTaskOptions: syncTaskOptions(
          waiting: !syncing && next != null,
        ),
      );
    } finally {
      _updating = false;
      if (_dirty && !_destroyed && !_ended) unawaited(_updateNotification());
    }
  }

  /// 后台隔离区读取保存的语言，没有记录时跟随系统。
  Future<AppLocalizations> _noticeText() async {
    final fixed = _text;
    if (fixed != null) return fixed;
    var saved = '';
    try {
      saved = (await SettingsService.instance.get()).locale;
    } catch (_) {}
    return AppLocale.strings(saved: saved);
  }

  /// 相册名跟在动作后面，没有名称时只显示动作。
  String _withAlbum(String action, String? name) {
    if (name == null || name.isEmpty) return action;
    return '$action · $name';
  }

  /// 本地时分展示下次时间，跨日期时同时显示月日。
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final clock =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    if (time.year == now.year &&
        time.month == now.month &&
        time.day == now.day) {
      return clock;
    }
    return '${time.month}/${time.day} $clock';
  }

  /// 页面重新进入时返回完整快照，停止命令与通知使用同一路径。
  @override
  void onReceiveData(Object data) {
    if (data == 'stop') {
      unawaited(_stop());
    } else if (data == 'snapshot') {
      _send('snapshot', {
        'albumId': _albumId,
        'activity': _activity.toJson(),
        'progress': _progress.values.map((value) => value.toJson()).toList(),
      });
      if (_ended) _send('finished', {'error': _error});
    }
  }

  /// 点击通知停止按钮时取消同步。
  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') unawaited(_stop());
  }

  /// 先取消请求，待同步保存结束状态后关闭服务。
  Future<void> _stop() async {
    if (_stopping || _ended || _destroyed) return;
    _stopping = true;
    _onActivity(const SyncActivity(stopping: true));
    await _sync.stop();
  }

  /// 标记消息来源并限制为可跨隔离区传递的数据。
  void _send(String type, [Map<String, Object?> values = const {}]) {
    FlutterForegroundTask.sendDataToMain({
      'source': 'sync',
      'type': type,
      ...values,
    });
  }

  /// 系统超时或销毁时取消请求并解除监听，不主动重启。
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _destroyed = true;
    if (identical(onUnauthorized, _expiredSession)) onUnauthorized = null;
    if (isTimeout) {
      _error = 'Background sync reached the system time limit and stopped';
    }
    await _sync.stop();
    await _operation;
    await _activities?.cancel();
    await _logs?.cancel();
    StorageService.changes.removeListener(_onStoragesChanged);
    TaskService.changes.removeListener(_onTasksChanged);
    _sync.dispose();
  }
}
