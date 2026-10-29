import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:pixtale_sync/l10n/localizations.dart';
import 'package:pixtale_sync/models/photo.dart';
import 'package:pixtale_sync/models/task_preview.dart';
import 'package:pixtale_sync/request/request.dart';
import 'package:pixtale_sync/services/photo_service.dart';

// 从设备相册中勾选需要添加的任务来源。

/// 从设备相册中勾选需要添加的任务来源。
class AlbumMobilePicker extends StatefulWidget {
  /// 创建相册选择页。
  const AlbumMobilePicker({
    super.key,
    required this.selectedIds,
    this.photoService,
  });

  /// 已添加的相册 ID，选择页不提供删除操作。
  final Set<String> selectedIds;

  /// 可替换的本地照片服务。
  final PhotoService? photoService;

  /// 创建相册选择页状态。
  @override
  State<AlbumMobilePicker> createState() => _AlbumMobilePickerState();
}

/// 管理相册选择页的勾选状态和预览加载。
class _AlbumMobilePickerState extends State<AlbumMobilePicker> {
  // 状态与依赖

  /// 可选相册预览。
  final List<TaskPreview> _albums = [];

  /// 相册 ID 与系统相册实体的对应关系，供列表项按需读取预览。
  final Map<String, PhotoAlbum> _albumEntities = {};

  /// 正在读取封面和数量的相册 ID。
  final Set<String> _loadingPreviewIds = {};

  /// 等待读取预览的相册，越新越靠前，优先当前屏幕。
  final List<String> _pendingPreviewIds = [];

  /// 同时读取封面的数量，避免快速滑动时把后面的请求堵在前面。
  static const _maxPreviewLoads = 12;

  /// 尚未开始的预览请求上限，只保留最近进入视口的相册。
  static const _maxPendingPreviews = 48;

  /// 已完成首次预览读取的相册 ID，避免列表重建时重复请求。
  final Set<String> _loadedPreviewIds = {};

  /// 已知的媒体数量，排序时无需加载所有封面。
  final Map<String, int> _counts = {};

  /// 名称对应的小写无声调拼音，切换排序时复用转换结果。
  final Map<String, String> _nameKeys = {};

  /// 当前排序方式，默认保留服务返回的原始顺序。
  _AlbumSort _sort = _AlbumSort.original;

  /// 合并重复的数量读取请求。
  Future<void>? _countOperation;

  /// 当前勾选的相册 ID。
  late final Set<String> _selectedIds = Set.of(widget.selectedIds);

  /// 是否正在读取系统相册。
  bool _loading = true;

  /// 读取相册失败时显示的错误信息。
  String? _error;

  // 生命周期

  /// 进入页面后立即开始读取相册数据。
  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  // 事件处理

  /// 取消选择并返回任务页。
  void _cancel() => Navigator.of(context).pop();

  /// 确认勾选并返回任务页。
  void _confirm() {
    final selected = _albums
        .where((album) => _selectedIds.contains(album.albumId))
        .map((album) => _albumEntities[album.albumId])
        .whereType<PhotoAlbum>()
        .toList();
    Navigator.of(context).pop(selected);
  }

  /// 切换相册勾选状态，已添加的相册保持选中。
  void _toggleAlbum(String id) {
    if (widget.selectedIds.contains(id)) return;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  /// 切换排序；数量补齐后统一重排，避免每读完一个相册就跳动。
  Future<void> _changeSort(_AlbumSort sort) async {
    setState(() {
      _sort = sort;
      if (!sort.byCount) _sortAlbums();
    });
    if (!sort.byCount || _loading) return;
    await (_countOperation ??= _loadCounts().whenComplete(() {
      _countOperation = null;
    }));
    if (mounted && _sort.byCount) setState(_sortAlbums);
  }

  /// 打开或关闭排序菜单。
  void _toggleSortMenu(MenuController controller) {
    if (controller.isOpen) {
      controller.close();
    } else {
      controller.open();
    }
  }

  // 内部方法

  /// 缓存中文拼音和英文小写名称，原始相册名仍用于展示。
  String _nameKey(String name) => _nameKeys.putIfAbsent(
    name,
    () => PinyinHelper.getPinyinE(
      name,
      separator: '',
      format: PinyinFormat.WITHOUT_TONE,
    ).toLowerCase(),
  );

  /// 默认恢复服务返回的顺序；其他排序将空名称放末尾，再按规则比较。
  void _sortAlbums() {
    if (_sort == _AlbumSort.original) {
      final previews = {for (final album in _albums) album.albumId: album};
      _albums
        ..clear()
        ..addAll(_albumEntities.keys.map((id) => previews[id]!));
      return;
    }
    _albums.sort((first, second) {
      if (first.albumName.isEmpty != second.albumName.isEmpty) {
        return first.albumName.isEmpty ? 1 : -1;
      }
      if (_sort.byCount) {
        final firstCount = _counts[first.albumId];
        final secondCount = _counts[second.albumId];
        if (firstCount == null && secondCount != null) return 1;
        if (firstCount != null && secondCount == null) return -1;
        if (firstCount != null && secondCount != null) {
          final result = firstCount.compareTo(secondCount);
          if (result != 0) {
            return _sort == _AlbumSort.countAscending ? result : -result;
          }
        }
      }
      final result = _nameKey(first.albumName)
          .compareTo(_nameKey(second.albumName));
      if (result == 0) return first.albumId.compareTo(second.albumId);
      return _sort == _AlbumSort.nameDescending ? -result : result;
    });
  }

  /// 最多同时读取四个相册的统计，不提前读取屏幕外的封面。
  Future<void> _loadCounts() async {
    final pending = _albumEntities.values
        .where((album) => !_counts.containsKey(album.id))
        .iterator;

    /// 每个读取者取下一个相册，页面关闭后停止追加请求。
    Future<void> readNext() async {
      while (mounted && pending.moveNext()) {
        final album = pending.current;
        try {
          final count = await _photoService.countMedia(album);
          if (!mounted) return;
          setState(() => _counts[album.id] = count);
        } catch (error, stackTrace) {
          developer.log(
            'Failed to count album ${album.name}',
            name: 'pixtale_sync.gallery',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
    }

    await Future.wait(List.generate(4, (_) => readNext()));
  }

  /// 请求权限并加载相册名称，预览信息由列表项按需读取。
  Future<void> _loadAlbums() async {
    try {
      final albums = await _photoService.listAlbums();
      if (!mounted) return;
      setState(() {
        _albums
          ..clear()
          ..addAll(
            albums.map(
              (album) => TaskPreview(
                albumId: album.id,
                albumName: album.name,
                count: 0,
              ),
            ),
          );
        _albumEntities
          ..clear()
          ..addEntries(albums.map((album) => MapEntry(album.id, album)));
        _loadingPreviewIds.clear();
        _pendingPreviewIds.clear();
        _loadedPreviewIds.clear();
        _counts.clear();
        _nameKeys.clear();
        _sortAlbums();
        _loading = false;
      });
      if (_sort.byCount) unawaited(_changeSort(_sort));
    } catch (error, stackTrace) {
      developer.log(
        'Failed to load photo albums',
        name: 'pixtale_sync.gallery',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _error = ApiException.isPhotoPermissionError(error)
              ? l10n.photoAccessRequired
              : l10n.albumsLoadFailed;
          _loading = false;
        });
      }
    }
  }

  /// 为已进入列表视口的相册排队读取预览，最新进入的优先。
  void _loadPreviewIfNeeded(String albumId) {
    if (_loadingPreviewIds.contains(albumId) ||
        _loadedPreviewIds.contains(albumId)) {
      return;
    }
    if (_albumEntities[albumId] == null) return;
    _pendingPreviewIds.remove(albumId);
    _pendingPreviewIds.insert(0, albumId);
    if (_pendingPreviewIds.length > _maxPendingPreviews) {
      _pendingPreviewIds.removeRange(
        _maxPendingPreviews,
        _pendingPreviewIds.length,
      );
    }
    _pumpPreviewLoads();
  }

  /// 最多同时读取十个封面，完成后继续领取当前优先队列。
  void _pumpPreviewLoads() {
    while (mounted &&
        _loadingPreviewIds.length < _maxPreviewLoads &&
        _pendingPreviewIds.isNotEmpty) {
      final albumId = _pendingPreviewIds.removeAt(0);
      if (_loadingPreviewIds.contains(albumId) ||
          _loadedPreviewIds.contains(albumId)) {
        continue;
      }
      final album = _albumEntities[albumId];
      if (album == null) continue;
      _loadingPreviewIds.add(albumId);
      unawaited(_loadPreview(albumId, album));
    }
  }

  /// 更新单个相册的数量和封面，不阻塞整个选择列表。
  Future<void> _loadPreview(String albumId, PhotoAlbum album) async {
    try {
      final preview = await _createPreview(album);
      if (!mounted) return;
      final index = _albums.indexWhere((item) => item.albumId == albumId);
      if (index == -1) return;
      setState(() {
        _albums[index] = preview;
        _counts[albumId] = preview.count;
      });
    } catch (error, stackTrace) {
      developer.log(
        'Failed to load album preview for ${album.name}',
        name: 'pixtale_sync.gallery',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _loadingPreviewIds.remove(albumId);
      _loadedPreviewIds.add(albumId);
      if (mounted) {
        setState(() {});
        _pumpPreviewLoads();
      }
    }
  }

  /// 读取单个相册的媒体数量和最新封面。
  Future<TaskPreview> _createPreview(PhotoAlbum album) async {
    final info = await _photoService.getInfo(album, imagesOnly: false);
    return TaskPreview(
      albumId: info.album.id,
      albumName: info.album.name,
      count: info.count,
      cover: info.cover,
      path: info.album.path,
    );
  }

  /// 当前页面使用的照片服务。
  late final PhotoService _photoService =
      widget.photoService ?? PhotoService.create();

  // 页面渲染

  /// 构建相册选择列表。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chooseAlbums),
        leading: IconButton(
          onPressed: _cancel,
          icon: const Icon(Icons.close),
        ),
        actions: [
          MenuAnchor(
            menuChildren: [
              for (final sort in _AlbumSort.values)
                MenuItemButton(
                  onPressed: () => _changeSort(sort),
                  trailingIcon: _sort == sort
                      ? const Icon(Icons.check, size: 18)
                      : const SizedBox(width: 18),
                  child: Text(sort.label(l10n)),
                ),
            ],
            builder: (context, controller, _) => IconButton(
              onPressed: _loading ? null : () => _toggleSortMenu(controller),
              icon: const Icon(Icons.sort),
            ),
          ),
          TextButton(onPressed: _confirm, child: Text(l10n.done)),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _albums.isEmpty
          ? Center(child: Text(l10n.noPhotoAlbums))
          : ListView.separated(
              itemCount: _albums.length,
              findItemIndexCallback: (key) {
                final index = _albums.indexWhere(
                  (album) => ValueKey(album.albumId) == key,
                );
                return index == -1 ? null : index;
              },
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 84),
              itemBuilder: (context, index) {
                final preview = _albums[index];
                _loadPreviewIfNeeded(preview.albumId);
                final coverReady = _loadedPreviewIds.contains(preview.albumId);
                final selected = _selectedIds.contains(preview.albumId);
                final alreadyAdded = widget.selectedIds.contains(
                  preview.albumId,
                );
                return ListTile(
                  key: ValueKey(preview.albumId),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: SizedBox.square(
                    dimension: 56,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: !coverReady
                          ? const ColoredBox(color: Colors.white)
                          : preview.cover == null
                          ? const ColoredBox(
                              color: Color(0xFFE9ECEF),
                              child: Icon(Icons.photo_outlined),
                            )
                          : Image.memory(
                              preview.cover!,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                    ),
                  ),
                  title: Text(
                    preview.albumName.isEmpty
                        ? l10n.unnamedAlbum
                        : preview.albumName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // 空白文字保留相同的行高和基线，数量加载后名称不位移。
                  subtitle: Text(
                    _counts.containsKey(preview.albumId)
                        ? '${_counts[preview.albumId]}'
                        : ' ',
                  ),
                  trailing: Checkbox(
                    value: selected,
                    onChanged: alreadyAdded
                        ? null
                        : (_) => _toggleAlbum(preview.albumId),
                  ),
                  onTap: alreadyAdded
                      ? null
                      : () => _toggleAlbum(preview.albumId),
                );
              },
            ),
    );
  }
}

/// 相册选择列表支持的排序方式。
enum _AlbumSort {
  original,
  nameAscending,
  nameDescending,
  countAscending(byCount: true),
  countDescending(byCount: true);

  /// 定义是否需要统计数量。
  const _AlbumSort({this.byCount = false});

  final bool byCount;

  /// 当前语言下的菜单文字。
  String label(AppLocalizations l10n) => switch (this) {
    original => l10n.sortDefault,
    nameAscending => l10n.sortNameAsc,
    nameDescending => l10n.sortNameDesc,
    countAscending => l10n.sortCountAsc,
    countDescending => l10n.sortCountDesc,
  };
}
