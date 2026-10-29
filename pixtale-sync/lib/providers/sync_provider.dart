import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pixtale_sync/models/sync.dart';
import 'package:pixtale_sync/services/foreground_sync_service.dart';
import 'package:pixtale_sync/services/sync_service.dart';

// 保存页面展示的同步状态和实时进度，业务交由同步服务执行。

/// 为任务页提供启停状态和相册进度。
class SyncProvider extends ChangeNotifier {
  /// 创建页面状态，可注入同步服务用于测试。
  SyncProvider({SyncService? service})
    : _service = service ?? ForegroundSyncService.create() {
    _activities = _service.activities.listen(_updateActivity);
    unawaited(_restore());
  }

  final SyncService _service;

  /// 本轮已经更新的相册进度。
  final Map<String, SyncProgress> progress = {};

  /// 当前正在核对或上传的相册，定时等待时为空。
  String? currentAlbumId;

  /// 是否已开启同步，包括定时等待阶段。
  bool active = false;

  /// 是否正在等待当前请求停止。
  bool stopping = false;

  /// 初次进入时连接已有后台任务，防止重复点击开始。
  bool restoring = true;

  /// 定时等待期间的下次同步时间和服务状态订阅。
  DateTime? nextSyncAt;
  StreamSubscription<SyncActivity>? _activities;

  /// 最近一次同步失败，供页面显示简短提示。
  String? error;
  bool _disposed = false;

  /// 页面重建时连接已有服务，不自动启动新的同步。
  Future<void> _restore() async {
    try {
      if (await _service.isRunning && !_disposed) unawaited(start());
    } catch (failure) {
      error = '$failure';
    } finally {
      restoring = false;
      _notify();
    }
  }

  /// 开启同步并监听进度，失败时恢复播放按钮。
  Future<void> start() async {
    if (active) return;
    active = true;
    error = null;
    _notify();
    try {
      await _service.start(
        _updateProgress,
        onAlbumChanged: _updateCurrentAlbum,
        onNotice: _showNotice,
      );
    } catch (failure) {
      error = '$failure';
    } finally {
      active = false;
      stopping = false;
      currentAlbumId = null;
      nextSyncAt = null;
      _notify();
    }
  }

  /// 显示停止状态并等待当前同步退出。
  Future<void> stop() async {
    if (!active || stopping) return;
    stopping = true;
    _notify();
    await _service.stop();
  }

  /// 显示权限提示，同步保持开启。
  void _showNotice(String message) {
    error = message;
    _notify();
  }

  /// 保存最新相册进度并刷新页面。
  void _updateProgress(SyncProgress value) {
    progress[value.albumId] = value;
    _notify();
  }

  /// 切换当前处理的相册，不改变缓存进度。
  void _updateCurrentAlbum(String? albumId) {
    currentAlbumId = albumId;
    _notify();
  }

  /// 接收等待时间及通知按钮触发的停止状态。
  void _updateActivity(SyncActivity value) {
    nextSyncAt = value.nextSyncAt;
    stopping = value.stopping;
    _notify();
  }

  /// 状态释放后不再通知已经卸载的页面。
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// 页面释放时移除监听，Android 服务仍继续同步。
  @override
  void dispose() {
    _disposed = true;
    unawaited(_activities?.cancel());
    _service.dispose();
    super.dispose();
  }
}
