import 'dart:async';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart';
import 'package:pixtale_sync/l10n/locale.dart';
import 'package:pixtale_sync/l10n/localizations.dart';
import 'package:pixtale_sync/models/sync.dart';
import 'package:pixtale_sync/models/log.dart';
import 'package:pixtale_sync/models/storage.dart';
import 'package:pixtale_sync/models/user.dart';
import 'package:pixtale_sync/request/request.dart';
import 'package:pixtale_sync/request/sync.dart';
import 'package:pixtale_sync/services/photo_service.dart';
import 'package:pixtale_sync/services/log_service.dart';
import 'package:pixtale_sync/services/settings_service.dart';
import 'package:pixtale_sync/services/storage_service.dart';
import 'package:pixtale_sync/services/task_service.dart';
import 'package:pixtale_sync/services/user_service.dart';

// 同步业务：顺序处理相册，分页查重并发上传，支持重试和主动停止。

/// 管理一次开启到停止之间的同步和定时检查。
class SyncService {
  /// 创建同步服务，依赖可替换以验证上传和取消行为。
  SyncService({
    TaskService? tasks,
    UserService? users,
    SettingsService? settings,
    PhotoService? photos,
    LogService? logs,
    StorageService? storages,
    SyncApi Function(User, http.Client)? apiFactory,
  }) : _tasks = tasks ?? TaskService.instance,
       _userService = users,
       _settingsService = settings,
       _photos = photos ?? PhotoService.create(),
       _logService = logs,
       _storageService = storages,
       _apiFactory = apiFactory ?? SyncApi.new;

  final TaskService _tasks;
  final UserService? _userService;
  final SettingsService? _settingsService;
  final PhotoService _photos;
  final LogService? _logService;
  final StorageService? _storageService;
  final SyncApi Function(User, http.Client) _apiFactory;

  /// 当前网络连接和系统图库导出请求，用于立即取消。
  http.Client? _client;
  final Set<PMCancelToken> _fileTokens = {};

  /// 复用运行中的流程，停止信号也会唤醒定时等待。
  Future<void>? _operation;
  Completer<void>? _stopSignal;
  bool _stopped = true;

  /// 将等待时间和停止状态交给页面或通知展示。
  final _activities = StreamController<SyncActivity>.broadcast();

  /// 订阅同步活动变化。
  Stream<SyncActivity> get activities => _activities.stream;

  /// 判断是否有可以重新连接的同步任务。
  Future<bool> get isRunning async => _operation != null;

  /// 发布活动状态，避免释放后继续写入消息。
  void publishActivity(SyncActivity value) {
    if (!_activities.isClosed) _activities.add(value);
  }

  /// 页面释放时结束本地同步，后台实现可改为仅断开连接。
  void dispose() {
    unawaited(stop().whenComplete(_activities.close));
  }

  /// 避免同一异常经过上传、相册和全局捕获时重复写入。
  final Set<Object> _loggedErrors = Set<Object>.identity();

  /// 开始同步时才创建默认日志服务。
  LogService get _logs => _logService ?? LogService.instance;

  /// 开始同步后才初始化默认账户服务。
  UserService get _users => _userService ?? UserService.instance;

  /// 开始同步后才初始化默认设置服务。
  SettingsService get _settings => _settingsService ?? SettingsService.instance;

  /// 开启同步；设置了间隔时保持开启并等待下一轮。
  Future<void> start(
    void Function(SyncProgress) onProgress, {
    void Function(String?)? onAlbumChanged,
    void Function(String message)? onNotice,
  }) {
    if (_operation != null) return _operation!;
    _stopped = false;
    _loggedErrors.clear();
    return _operation = runSync(
      onProgress,
      onAlbumChanged: onAlbumChanged,
      onNotice: onNotice,
    ).whenComplete(() => _operation = null);
  }

  /// 在当前隔离区执行同步。前台服务因权限无法启动时仍走这里。
  Future<void> runSync(
    void Function(SyncProgress) onProgress, {
    void Function(String?)? onAlbumChanged,
    void Function(String message)? onNotice,
  }) {
    _stopped = false;
    _stopSignal = Completer<void>();
    return _run(onProgress, onAlbumChanged);
  }

  /// 停止领取新照片并取消网络请求和文件导出。
  Future<void> stop() async {
    if (_operation == null) return;
    requestStop();
    await _operation;
  }

  /// 标记停止并取消进行中的请求，不等待同步流程退出。
  void requestStop() {
    _stopped = true;
    publishActivity(const SyncActivity(stopping: true));
    if (_stopSignal?.isCompleted == false) _stopSignal!.complete();
    _client?.close();
    for (final token in _fileTokens.toList()) {
      unawaited(token.cancelRequest().catchError((Object _) {}));
    }
  }

  /// 验证账户与权限，执行同步并在退出时恢复关闭状态。
  Future<void> _run(
    void Function(SyncProgress) onProgress,
    void Function(String?)? onAlbumChanged,
  ) async {
    _client = http.Client();
    try {
      final user = await _users.get();
      if (user == null) throw const ApiException('Sign in first');
      if ((await _tasks.list(account: user)).isEmpty) {
        throw const ApiException('Add an album first');
      }
      await _photos.checkPermission();
      _checkStopped();
      await _settings.updateTaskStatus(1);
      final api = _apiFactory(user, _client!);
      do {
        publishActivity(const SyncActivity());
        await _checkAccount(user);
        await _record(event: _LogEvent.startSync, status: LogStatus.success);
        _checkStopped();
        await _syncAlbums(api, onProgress, onAlbumChanged);
        _checkStopped();
        await _settings.updateLastSyncAt();
      } while (await _waitForNext());
    } catch (error) {
      if (!_stopped) {
        await _recordFailure(error, event: _LogEvent.openSync);
        rethrow;
      }
    } finally {
      _client?.close();
      _client = null;
      _stopped = true;
      await _settings.updateTaskStatus(2);
      publishActivity(const SyncActivity());
    }
  }

  /// 建立本轮远端索引，单个任务失败记录日志后跳过，不中断定时同步。
  Future<void> _syncAlbums(
    SyncApi api,
    void Function(SyncProgress) onProgress,
    void Function(String?)? onAlbumChanged,
  ) async {
    final tasks = await _tasks.list(account: api.user);
    if (tasks.isEmpty) return;
    String? currentAlbumId;
    void setCurrentAlbum(String? albumId) {
      if (currentAlbumId == albumId) return;
      currentAlbumId = albumId;
      onAlbumChanged?.call(albumId);
    }

    setCurrentAlbum(tasks.first.albumId);
    var remoteEvent = _LogEvent.readStorage;
    try {
      final storages = await _retry(api.getStorages);
      _checkStopped();
      await (_storageService ?? StorageService()).save(
        storages,
        account: api.user,
      );

      for (var index = 0; index < tasks.length; index++) {
        final task = tasks[index];
        _loggedErrors.clear();
        _checkStopped();
        await _checkAccount(api.user);
        var event = _LogEvent.readStorage;
        var albumName = task.albumName.isEmpty ? task.albumId : task.albumName;
        try {
          setCurrentAlbum(task.albumId);
          final storage = storages
              .where(
                (item) => task.storageId == null
                    ? item.type == 1
                    : item.id == task.storageId,
              )
              .firstOrNull;
          if (storage == null) {
            throw const ApiException('Storage unavailable');
          }
          event = _LogEvent.readAlbum;
          final album = await _tasks.readAlbum(
            task,
            _photos,
            account: api.user,
          );
          final name = album.name.trim();
          if (name.isEmpty) throw const ApiException('Local album name is empty');
          albumName = name;
          event = _LogEvent.remoteCheck;
          final locals = <SyncPhoto>[];
          await for (final page in _photos.scanAlbum(
            album,
            isStopped: () => _stopped,
          )) {
            _checkStopped();
            await _checkAccount(api.user);
            locals.addAll(page);
          }
          _checkStopped();
          final missingFiles = <SyncFile>[];
          if (locals.isEmpty) {
            missingFiles.addAll(await _retry(() => api.check(const [])));
          } else {
            for (
              var start = 0;
              start < locals.length;
              start += SyncApi.checkPageSize
            ) {
              _checkStopped();
              missingFiles.addAll(
                await _retry(
                  () => api.check([
                    for (final photo in locals
                        .skip(start)
                        .take(SyncApi.checkPageSize))
                      SyncFile(name: photo.name, size: photo.size),
                  ]),
                ),
              );
            }
          }
          final missingCounts = <String, int>{};
          for (final file in missingFiles) {
            missingCounts[file.key] = (missingCounts[file.key] ?? 0) + 1;
          }
          final missing = <SyncPhoto>[];
          for (final photo in locals) {
            final count = missingCounts[photo.key] ?? 0;
            if (count == 0) continue;
            missingCounts[photo.key] = count - 1;
            missing.add(photo);
          }
          var total = await _photos.count(album);
          var completed = (locals.length - missing.length).clamp(0, total);
          final storageName = storage.name;

          /// 仅发布已经持久化的完成数量。
          void publishProgress() {
            onProgress(
              SyncProgress(
                albumId: task.albumId,
                completed: completed,
                total: total,
                storageName: storageName,
              ),
            );
          }

          _checkStopped();
          await _tasks.updateProgress(
            task.albumId,
            completed,
            account: api.user,
          );
          publishProgress();
          if (missing.isEmpty) continue;
          event = _LogEvent.getRemoteAlbum;
          final albumId = await _retry(() => api.getAlbum(name, storage.id));
          _checkStopped();
          var next = 0;

          /// 从待上传列表领取下一张照片，直到全部完成或同步停止。
          Future<void> worker() async {
            while (!_stopped && next < missing.length) {
              _checkStopped();
              final photo = missing[next++];
              if (!isAllowedImageName(photo.name)) continue;
              if (storage.type == 3 && photo.size > 20 * 1024 * 1024) continue;
              try {
                await _checkAccount(api.user);
                final accepted = await _upload(
                  api,
                  photo,
                  albumId,
                  storage,
                );
                if (!accepted) continue;
                _checkStopped();
                completed = await _tasks.incrementProgress(
                  task.albumId,
                  account: api.user,
                );
                publishProgress();
              } catch (error) {
                _checkStopped();
                await _recordFailure(
                  error,
                  eventText: photo.name,
                  albumName: albumName,
                  deduplicate: false,
                );
                if (error is ApiException && error.statusCode == 401) rethrow;
              }
            }
          }

          event = _LogEvent.readSyncSettings;
          final concurrency = (await _settings.get()).uploadConcurrency.clamp(
            1,
            20,
          );
          await Future.wait(
            List.generate(
              missing.length.clamp(0, concurrency),
              (_) => worker(),
            ),
          );
          _checkStopped();
          event = _LogEvent.updateCount;
          // 同步期间图库可能变化，完成后刷新分母并限制有效范围。
          final latestTotal = await _photos.count(album);
          if (latestTotal != total) {
            total = latestTotal;
            completed = completed.clamp(0, total);
            _checkStopped();
            await _tasks.updateProgress(
              task.albumId,
              completed,
              account: api.user,
            );
            publishProgress();
          }
        } catch (error) {
          _checkStopped();
          await _recordFailure(error, event: event, albumName: albumName);
          if (error is ApiException && error.statusCode == 401) rethrow;
        } finally {
          // 直接切到下一个相册。只有本轮最后一个任务结束才清空，避免间隔里显示空闲。
          final next = index + 1 < tasks.length ? tasks[index + 1].albumId : null;
          setCurrentAlbum(next);
        }
      }
    } catch (error) {
      _checkStopped();
      await _recordFailure(error, event: remoteEvent);
      rethrow;
    } finally {
      setCurrentAlbum(null);
    }
  }

  /// 按当前界面语言取出日志文案。写入时再解析，手动切换后新日志会跟上。
  Future<AppLocalizations> _logL10n() async {
    var saved = '';
    try {
      saved = (await _settings.get()).locale;
    } catch (_) {}
    return AppLocale.strings(saved: saved);
  }

  String _logEventLabel(AppLocalizations text, _LogEvent event) {
    return switch (event) {
      _LogEvent.startSync => text.logEventStartSync,
      _LogEvent.openSync => text.logEventOpenSync,
      _LogEvent.readStorage => text.logEventReadStorage,
      _LogEvent.readAlbum => text.logEventReadAlbum,
      _LogEvent.remoteCheck => text.logEventRemoteCheck,
      _LogEvent.getRemoteAlbum => text.logEventGetRemoteAlbum,
      _LogEvent.readSyncSettings => text.logEventReadSyncSettings,
      _LogEvent.updateCount => text.logEventUpdateCount,
    };
  }

  /// 每个最终失败只写入一次，主动停止不会写入失败日志。
  Future<void> _recordFailure(
    Object error, {
    _LogEvent? event,
    String? eventText,
    String? albumName,
    bool deduplicate = true,
  }) async {
    if (_stopped) return;
    final recorded = !_loggedErrors.add(error);
    if (deduplicate && recorded) return;
    await _record(
      event: event,
      eventText: eventText,
      albumName: albumName,
      status: LogStatus.failure,
      message: '$error',
    );
  }

  /// 日志写入失败只输出诊断信息，不改变同步结果和已上传数量。
  Future<void> _record({
    _LogEvent? event,
    String? eventText,
    String? albumName,
    required int status,
    String? message,
  }) async {
    try {
      final text = await _logL10n();
      await _logs.add(
        albumName: albumName ?? text.logAlbumAll,
        event: eventText ?? _logEventLabel(text, event!),
        status: status,
        message:
            message ??
            (status == LogStatus.success ? text.logStatusSuccess : null),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Cannot save sync log',
        name: 'pixtale_sync.sync',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// 上传照片。重复文件视为已成功，文件头不在白名单时跳过。
  Future<bool> _upload(
    SyncApi api,
    SyncPhoto photo,
    String albumId,
    Storage storage,
  ) async {
    final token = PMCancelToken();
    _fileTokens.add(token);
    try {
      final file = await _photos.getFile(photo, token);
      _checkStopped();
      if (!isAllowedImageHeader(await readImageHeader(file))) return false;
      // 重试保留相同锁，防止服务端并行处理同一份上传。
      final lock = '${DateTime.now().microsecondsSinceEpoch}-${photo.id}';
      await _retry(
        () => api.uploadPhoto(photo, file, albumId, storage.id, lock),
      );
      return true;
    } finally {
      _fileTokens.remove(token);
    }
  }

  /// 对暂时性失败额外重试两次，停止及业务错误不重试。
  Future<T> _retry<T>(Future<T> Function() action) async {
    for (var attempt = 0; ; attempt++) {
      _checkStopped();
      try {
        final result = await action();
        _checkStopped();
        return result;
      } catch (error) {
        _checkStopped();
        if (attempt == 2 ||
            (error is ApiException &&
                error.statusCode != null &&
                error.statusCode! >= 400 &&
                error.statusCode! < 500)) {
          rethrow;
        }
        await _pause(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
  }

  /// 在定时间隔到达前检查最新设置，停止时立即退出等待。
  Future<bool> _waitForNext() async {
    while (!_stopped) {
      final settings = await _settings.get();
      if (settings.taskInterval == 0) return false;
      final last = DateTime.parse(settings.lastSyncAt!);
      final next = last.add(Duration(minutes: settings.taskInterval));
      final remaining = next.difference(DateTime.now().toUtc());
      if (remaining <= Duration.zero) return true;
      publishActivity(SyncActivity(nextSyncAt: next));
      await _pause(
        remaining < const Duration(minutes: 1)
            ? remaining
            : const Duration(minutes: 1),
      );
    }
    return false;
  }

  /// 等待退避或定时检查，停止信号会提前结束等待。
  Future<void> _pause(Duration duration) =>
      _stopSignal!.future.timeout(duration, onTimeout: () {});

  /// 防止同步过程中切换账户后继续使用旧凭证。
  Future<void> _checkAccount(User expected) async {
    _checkStopped();
    final current = await _users.get();
    if (current?.userId != expected.userId ||
        current?.endpoint != expected.endpoint ||
        current?.token != expected.token) {
      throw const ApiException('Account changed, start sync again');
    }
  }

  /// 在网络请求和文件处理之间响应停止。
  void _checkStopped() {
    if (_stopped) throw const ApiException('Sync stopped');
  }
}

/// 写入日志的步骤。具体文字在记录时按当前语言生成。
enum _LogEvent {
  startSync,
  openSync,
  readStorage,
  readAlbum,
  remoteCheck,
  getRemoteAlbum,
  readSyncSettings,
  updateCount,
}
