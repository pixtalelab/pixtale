import 'dart:async';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pixtale_sync/l10n/localizations.dart';
import 'package:pixtale_sync/components/album/album_desktop_picker.dart';
import 'package:pixtale_sync/components/album/album_mobile_picker.dart';
import 'package:pixtale_sync/components/common/app_notice.dart';
import 'package:pixtale_sync/components/task/task_card.dart';
import 'package:pixtale_sync/models/photo.dart';
import 'package:pixtale_sync/models/task.dart';
import 'package:pixtale_sync/models/task_preview.dart';
import 'package:pixtale_sync/models/storage.dart';
import 'package:pixtale_sync/models/user.dart';
import 'package:pixtale_sync/providers/sync_provider.dart';
import 'package:pixtale_sync/providers/storage_provider.dart';
import 'package:pixtale_sync/services/photo_service.dart';
import 'package:pixtale_sync/services/foreground_sync_service.dart';
import 'package:pixtale_sync/services/storage_service.dart';
import 'package:pixtale_sync/services/sync_service.dart';
import 'package:pixtale_sync/services/task_service.dart';
import 'package:pixtale_sync/services/user_service.dart';

// 任务列表及来源相册选择界面。

/// 任务页面，展示用户添加的相册任务。
class TaskPage extends StatefulWidget {
  /// 创建任务页面。
  const TaskPage({
    super.key,
    this.taskService,
    this.storageService,
    this.syncService,
    this.sync,
  });

  /// 可注入的持久化服务。
  final TaskService? taskService;

  /// 可注入的存储缓存与刷新服务。
  final StorageService? storageService;

  /// 可注入的同步服务。
  final SyncService? syncService;

  /// 与设置页共用的同步状态。为空时页面自己创建。
  final SyncProvider? sync;

  /// 创建任务页面状态。
  @override
  State<TaskPage> createState() => _TaskPageState();
}

/// 加载、刷新和展示任务来源相册。
class _TaskPageState extends State<TaskPage> {
  // 状态与依赖

  /// 任务卡片及来源相册预览。
  final List<TaskPreview> _tasks = [];

  /// 当前是否正从系统图库读取数据。
  bool _loading = false;

  /// 正在保存卡片操作，避免重复操作与同步同时开始。
  bool _editing = false;

  /// 页面使用的任务持久化服务。
  late final TaskService _service = widget.taskService ?? TaskService.instance;

  /// 页面进入和弹窗打开时刷新可选存储。
  late final StorageProvider _storages = StorageProvider(
    widget.storageService ?? StorageService(),
  );

  /// 同步启停和卡片实时进度。外部传入时由上层释放。
  late final SyncProvider _sync =
      widget.sync ??
      SyncProvider(
        service:
            widget.syncService ?? ForegroundSyncService.create(tasks: _service),
      );

  /// 是否由本页创建同步状态。
  late final bool _ownsSync = widget.sync == null;

  /// 当前平台的本地照片来源。
  late final PhotoService _photos = PhotoService.create();

  /// 当前列表所属账户。
  User? _account;

  /// 账户变化时递增，防止旧异步结果覆盖新账户。
  int _taskVersion = 0;

  /// 已经提示过的权限失败，避免同步状态刷新时重复弹出。
  String? _permissionNotice;

  // 生命周期

  /// 启动时恢复已保存的任务。
  @override
  void initState() {
    super.initState();
    _sync.addListener(_onSyncChanged);
    UserService.changes.addListener(_onAccountChanged);
    StorageService.changes.addListener(_onTaskStateChanged);
    TaskService.changes.addListener(_onTaskStateChanged);
    _restoreTasks();
    unawaited(_storages.load());
  }

  /// 页面释放时取消同步并移除状态监听。
  @override
  void dispose() {
    _sync.removeListener(_onSyncChanged);
    UserService.changes.removeListener(_onAccountChanged);
    StorageService.changes.removeListener(_onTaskStateChanged);
    TaskService.changes.removeListener(_onTaskStateChanged);
    if (_ownsSync) _sync.dispose();
    _storages.dispose();
    super.dispose();
  }

  // 事件处理

  /// 刷新存储关联及失效状态，保留卡片封面、统计和同步进度。
  Future<void> _onTaskStateChanged() async {
    final account = _account;
    if (account == null) return;
    final version = _taskVersion;
    try {
      final records = await _service.list(account: account);
      if (!mounted || version != _taskVersion || !_isCurrentAccount(account)) {
        return;
      }
      final byId = {for (final task in records) task.albumId: task};
      setState(() {
        for (var index = 0; index < _tasks.length; index++) {
          final current = _tasks[index];
          final task = byId[current.albumId];
          if (task == null) continue;
          _tasks[index] = TaskPreview(
            albumId: current.albumId,
            albumName: current.albumName,
            count: current.count,
            cover: current.cover,
            completedCount: current.completedCount,
            storageName: _storageName(task),
            storageMissing: _storageMissing(task),
            path: current.path,
            isInvalid: task.isInvalid,
          );
        }
      });
    } catch (error, stackTrace) {
      developer.log(
        'Cannot refresh task storage',
        name: 'pixtale_sync.gallery',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// 账户变化时立即清空旧卡片，停止同步后恢复当前账户任务。
  Future<void> _onAccountChanged() async {
    final version = ++_taskVersion;
    setState(() {
      _account = null;
      _tasks.clear();
      _sync.progress.clear();
      _loading = true;
    });
    await _sync.stop();
    if (!mounted || version != _taskVersion) return;
    _sync.progress.clear();
    await _restoreTasks();
  }

  /// 通过同一个按钮开启或停止全部相册同步。
  Future<void> _toggleSync() async {
    if (_loading || _editing || _sync.restoring) return;
    if (_sync.active) {
      await _sync.stop();
    } else {
      await _sync.start();
    }
  }

  /// 空闲时编辑存储、置顶或删除任务。
  Future<void> _onTaskAction(String albumId, TaskAction action) async {
    if (_sync.active || _sync.restoring || _loading || _editing) return;
    final account = _account;
    if (account == null) return;
    setState(() => _editing = true);
    try {
      switch (action) {
        case TaskAction.edit:
          await _editTask(albumId, account);
          return;
        case TaskAction.pin:
          await _service.pin(albumId, account: account);
        case TaskAction.remove:
          await _service.remove(albumId, account: account);
          _sync.progress.remove(albumId);
      }
      if (!mounted || !_isCurrentAccount(account)) return;
      await _refreshTasks();
    } catch (_) {
      if (mounted) _showMessage(AppLocalizations.of(context).actionFailed);
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  /// 复用存储选择弹窗，保存目标存储后静默更新卡片。
  Future<void> _editTask(String albumId, User account) async {
    final records = await _service.list(account: account);
    if (!mounted || !_isCurrentAccount(account)) return;
    final task = records.where((item) => item.albumId == albumId).firstOrNull;
    if (task == null) return;
    _storages.select(task.storageId);
    unawaited(_storages.load());
    final storage = await showDialog<Storage>(
      context: context,
      builder: (_) => _TaskStorageDialog(storages: _storages, editing: true),
    );
    if (storage == null ||
        storage.id == task.storageId ||
        !mounted ||
        !_isCurrentAccount(account)) {
      return;
    }
    await _service.updateStorage(albumId, storage.id, account: account);
    if (!mounted || !_isCurrentAccount(account)) return;
    setState(() {
      final index = _tasks.indexWhere((item) => item.albumId == albumId);
      if (index == -1) return;
      final current = _tasks[index];
      _tasks[index] = TaskPreview(
        albumId: current.albumId,
        albumName: current.albumName,
        count: current.count,
        cover: current.cover,
        completedCount: current.completedCount,
        storageName: storage.name,
        storageMissing: false,
        path: current.path,
        isInvalid: current.isInvalid,
      );
    });
    await _onTaskStateChanged();
  }

  /// 刷新同步图标和进度。开始同步时权限被拒，用底部提示告诉用户。
  void _onSyncChanged() {
    if (!mounted) return;
    final message = _sync.error;
    if (message != null && _isPermissionMessage(message)) {
      if (_permissionNotice != message) {
        _permissionNotice = message;
        _showMessage(_visiblePermissionMessage(message));
      }
    } else {
      _permissionNotice = null;
    }
    setState(() {});
  }

  /// 先选择目标存储，再打开由页面自行加载数据的相册选择页。
  Future<void> _openAddTask() async {
    if (_sync.active || _sync.restoring) {
      _showSyncNotice();
      return;
    }
    final account = _account;
    if (account == null) {
      _showMessage(AppLocalizations.of(context).signInFirst);
      return;
    }
    _storages.select(null);
    unawaited(_storages.load());
    final storage = await showDialog<Storage>(
      context: context,
      builder: (_) => _TaskStorageDialog(storages: _storages),
    );
    if (storage == null || !mounted || !_isCurrentAccount(account)) return;
    await _openAlbumPicker(storage, account);
  }

  /// 打开相册选择页，并为选中的存储添加相册任务。
  Future<void> _openAlbumPicker(Storage storage, User account) async {
    final isDesktop =
        Platform.environment['FLUTTER_TEST'] != 'true' &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    if (isDesktop) {
      await _openDesktopAlbumPicker(storage, account);
      return;
    }

    final selected = await Navigator.of(context).push<List<PhotoAlbum>>(
      MaterialPageRoute(
        builder: (_) => AlbumMobilePicker(
          selectedIds: _tasks.map((preview) => preview.albumId).toSet(),
          photoService: _photos,
        ),
      ),
    );
    if (selected == null || !mounted || !_isCurrentAccount(account)) return;

    // Navigator 返回结果早于反向动画完成，延后刷新避免和转场争用主线程。
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted || !_isCurrentAccount(account)) return;
    setState(() => _editing = true);
    try {
      await _service.add(
        selected.map((album) => album.id).toList(),
        storage: storage,
        account: account,
      );
      final paths = <String, String?>{
        for (final album in selected)
          if (album.path != null) album.id: album.path,
      };
      await _service.updatePaths(paths, account: account);
      if (!mounted || !_isCurrentAccount(account)) return;
      await _refreshTasks();
    } catch (error, stackTrace) {
      developer.log(
        'Failed to save selected photo albums',
        name: 'pixtale_sync.gallery',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) _showMessage(AppLocalizations.of(context).addAlbumsFailed);
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  /// 在桌面端直接选择一个媒体文件夹并保存为任务。
  Future<void> _openDesktopAlbumPicker(Storage storage, User account) async {
    final selected = await AlbumDesktopPicker.pickAlbums(
      selectedIds: _tasks.map((preview) => preview.albumId).toSet(),
    );
    if (selected.isEmpty || !mounted || !_isCurrentAccount(account)) return;

    setState(() => _editing = true);
    try {
      await _service.add(
        selected.map((album) => album.id).toList(),
        storage: storage,
        account: account,
      );
      await _service.updatePaths({
        for (final album in selected) album.id: album.path,
      }, account: account);
      for (final album in selected) {
        if (!mounted || !_isCurrentAccount(account)) return;
        await _service.updateInfo(
          album.id,
          albumName: album.name,
          photoCount: 0,
          cover: null,
          account: account,
        );
        try {
          final info = await _photos.getInfo(album);
          await _service.updateInfo(
            album.id,
            albumName: album.name,
            photoCount: info.count,
            cover: info.cover,
            account: account,
          );
        } catch (error, stackTrace) {
          developer.log(
            'Cannot load selected folder preview ${album.path}',
            name: 'pixtale_sync.gallery',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
      if (!mounted || !_isCurrentAccount(account)) return;
      await _refreshTasks();
    } catch (error, stackTrace) {
      developer.log(
        'Failed to save selected desktop folders',
        name: 'pixtale_sync.gallery',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) _showMessage(AppLocalizations.of(context).addFolderFailed);
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  // 内部方法

  /// 确认选择和异步刷新仍属于当前登录会话。
  bool _isCurrentAccount(User account) =>
      _account?.endpoint == account.endpoint &&
      _account?.userId == account.userId &&
      _account?.token == account.token;

  /// 先恢复任务缓存，再在后台刷新系统相册信息。
  Future<void> _restoreTasks() async {
    final version = _taskVersion;
    setState(() => _loading = true);
    try {
      await _refreshTasks();
    } catch (error, stackTrace) {
      developer.log(
        'Failed to restore tasks',
        name: 'pixtale_sync.gallery',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (mounted && version == _taskVersion) {
        setState(() => _loading = false);
      }
    }
  }

  /// 从数据库读取任务缓存并立即渲染，再异步刷新最新信息。
  Future<void> _refreshTasks() async {
    final version = _taskVersion;
    final account = await _service.currentUser();
    final records = account == null
        ? <Task>[]
        : await _service.list(account: account);
    if (mounted && version == _taskVersion) {
      setState(() {
        _account = account;
        _tasks
          ..clear()
          ..addAll(records.map(_previewFromTask));
      });
      if (account != null) {
        unawaited(_refreshLatestTasks(records, account, version));
      }
    }
  }

  /// 逐项读取系统相册并静默更新本地缓存和当前卡片。
  Future<void> _refreshLatestTasks(
    List<Task> records,
    User account,
    int version,
  ) async {
    if (records.isEmpty) return;
    try {
      await _photos.checkPermission();
    } catch (_) {
      return;
    }

    for (final record in records) {
      if (!mounted || version != _taskVersion) return;
      try {
        final album = await _service.readAlbum(
          record,
          _photos,
          account: account,
        );
        final info = await _photos.getInfo(album);
        if (!mounted || version != _taskVersion) return;
        await _service.updateInfo(
          record.albumId,
          albumName: info.album.name,
          photoCount: info.count,
          cover: info.cover,
          account: account,
        );
        if (!mounted || version != _taskVersion) return;
        final index = _tasks.indexWhere(
          (item) => item.albumId == record.albumId,
        );
        if (index == -1) continue;
        final current = _tasks[index];
        final next = TaskPreview(
          albumId: info.album.id,
          albumName: info.album.name,
          count: info.count,
          cover: _sameCover(current.cover, info.cover)
              ? current.cover
              : info.cover,
          completedCount: current.completedCount,
          storageName: current.storageName,
          storageMissing: current.storageMissing,
          path: info.album.path,
        );
        if (_samePreview(current, next)) continue;
        setState(() => _tasks[index] = next);
      } catch (error, stackTrace) {
        // 已删除或无法访问的相册不阻断其他记录刷新。
        developer.log(
          'Cannot refresh saved album ${record.albumId}',
          name: 'pixtale_sync.gallery',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// 将任务表中的缓存转换为可直接渲染的卡片数据。
  TaskPreview _previewFromTask(Task task) => TaskPreview(
    albumId: task.albumId,
    albumName: task.albumName,
    count: task.photoCount,
    cover: task.cover,
    completedCount: task.completedCount,
    storageName: _storageName(task),
    storageMissing: _storageMissing(task),
    path: task.path,
    isInvalid: task.isInvalid,
  );

  /// 将任务的存储关联结果转换为卡片显示名称。
  String _storageName(Task task) {
    final l10n = AppLocalizations.of(context);
    if (task.storageId == null) return l10n.localStorage;
    return task.storageName ?? l10n.storageUnavailable;
  }

  /// 判断任务是否因存储关联失败而需要红色提示。
  bool _storageMissing(Task task) =>
      task.storageId != null && task.storageName == null;

  /// 判断封面字节是否相同，避免相同图片重新创建图片源。
  bool _sameCover(Uint8List? first, Uint8List? second) {
    if (identical(first, second)) return true;
    if (first == null || second == null || first.length != second.length) {
      return false;
    }
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  /// 判断后台刷新是否真的改变了卡片展示内容。
  bool _samePreview(TaskPreview first, TaskPreview second) {
    return first.albumName == second.albumName &&
        first.count == second.count &&
        first.isInvalid == second.isInvalid &&
        _sameCover(first.cover, second.cover);
  }

  /// 添加和卡片操作共用一条同步拦截提示。
  void _showSyncNotice() {
    _showMessage(AppLocalizations.of(context).stopSyncFirst);
  }

  /// 同步失败文案用固定英文识别，界面再翻成当前语言。
  bool _isPermissionMessage(String message) {
    final text = message.toLowerCase();
    return text.contains('permission') || text.contains('photo access');
  }

  /// 把捕获到的权限失败翻成当前语言，其他原文不改。
  String _visiblePermissionMessage(String message) {
    final l10n = AppLocalizations.of(context);
    final text = message.toLowerCase();
    if (text.contains('notification')) {
      return l10n.notificationPermissionRequired;
    }
    if (text.contains('photo access')) {
      return l10n.photoAccessRequired;
    }
    return message;
  }

  /// 显示简短提示。
  void _showMessage(String message) {
    AppNotice.show(context, message);
  }

  // 页面渲染

  /// 构建任务页面及卡片列表。
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).tasks),
        actions: [
          IconButton(
            onPressed: _editing ? null : _openAddTask,
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _tasks.isEmpty
          ? const SizedBox.shrink()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: _tasks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final preview = _tasks[index];
                final progress = _sync.progress[preview.albumId];
                return TaskCard(
                  key: ValueKey(preview.albumId),
                  preview: preview,
                  completed: progress?.completed ?? preview.completedCount,
                  total: progress?.total ?? preview.count,
                  storageName: preview.storageName,
                  storageMissing: preview.storageMissing,
                  syncing: _sync.currentAlbumId == preview.albumId,
                  enabled:
                      !_sync.active &&
                      !_sync.restoring &&
                      !_loading &&
                      !_editing,
                  onBlocked: _sync.active || _sync.restoring
                      ? _showSyncNotice
                      : null,
                  onSelected: (action) =>
                      _onTaskAction(preview.albumId, action),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _sync.active
            ? const Color(0xFFF97810)
            : const Color(0xFF9C9C9C),
        foregroundColor: Colors.white,
        onPressed:
            _loading ||
                _editing ||
                _tasks.isEmpty ||
                _sync.stopping ||
                _sync.restoring
            ? null
            : _toggleSync,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Icon(
          _sync.active ? Icons.stop : Icons.play_arrow,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}

// 私有组件

/// 添加或编辑任务时共用的存储选择弹窗。
class _TaskStorageDialog extends StatelessWidget {
  /// 创建共享页面存储缓存的弹窗。
  const _TaskStorageDialog({required this.storages, this.editing = false});

  /// 缓存列表、远端刷新状态与当前单选项。
  final StorageProvider storages;

  /// 编辑时保存存储，添加时继续选择相册。
  final bool editing;

  /// 切换目标存储。
  void _selectStorage(String? id) => storages.select(id);

  /// 返回选定存储供页面保存或继续选择相册。
  void _confirm(BuildContext context) =>
      Navigator.of(context).pop(storages.selected);

  /// 构建存储选择框和右下角文字按钮。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: storages,
      builder: (context, _) => AlertDialog(
        title: Text(editing ? l10n.editTask : l10n.addTask),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InputDecorator(
                decoration: InputDecoration(labelText: l10n.storage),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: storages.selectedId,
                    isExpanded: true,
                    hint: Text(
                      storages.items.isEmpty && !storages.loading
                          ? l10n.noStorageAvailable
                          : l10n.chooseStorage,
                    ),
                    items: [
                      for (final storage in storages.items)
                        DropdownMenuItem(
                          value: storage.id,
                          child: Text(
                            storage.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _selectStorage,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (storages.error != null)
                Text(
                  storages.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          if (editing)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
          TextButton(
            onPressed: storages.selected == null
                ? null
                : () => _confirm(context),
            child: Text(editing ? l10n.save : l10n.chooseAlbums),
          ),
        ],
      ),
    );
  }
}
