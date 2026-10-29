import 'dart:io';
import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

// 本地照片来源和相册的跨平台数据结构。

/// 本地相册来源，移动端保存系统实体，桌面端保存目录。
class PhotoAlbum {
  /// 创建本地相册来源。
  const PhotoAlbum({
    required this.id,
    required this.name,
    this.path,
    this.entity,
    this.directory,
  });

  final String id;
  final String name;
  final String? path;
  final AssetPathEntity? entity;
  final Directory? directory;
}

/// 相册列表或任务卡片需要的本地媒体摘要。
class PhotoAlbumInfo {
  /// 创建本地相册摘要。
  const PhotoAlbumInfo({required this.album, required this.count, this.cover});

  final PhotoAlbum album;
  final int count;
  final Uint8List? cover;
}
