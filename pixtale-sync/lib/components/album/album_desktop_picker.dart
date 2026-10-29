import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:pixtale_sync/models/photo.dart';

// 提供桌面端目录选择能力，不负责绘制界面。

/// 桌面端媒体文件夹选择器。
class AlbumDesktopPicker {
  /// 选择一个媒体文件夹，取消或选择重复目录时返回空列表。
  static Future<List<PhotoAlbum>> pickAlbums({
    Set<String> selectedIds = const {},
  }) async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null || path.isEmpty) return const [];

    final directory = Directory(path);
    final normalizedPath = directory.absolute.path;
    if (selectedIds.contains(normalizedPath)) return const [];

    return [
      PhotoAlbum(
        id: normalizedPath,
        name: p.basename(p.normalize(normalizedPath)),
        path: normalizedPath,
        directory: directory,
      ),
    ];
  }
}
