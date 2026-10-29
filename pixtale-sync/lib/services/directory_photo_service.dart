import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:pixtale_sync/models/photo.dart';
import 'package:pixtale_sync/models/sync.dart';
import 'package:pixtale_sync/request/request.dart';
import 'package:pixtale_sync/services/photo_service.dart';

// 使用文件系统读取 Windows、macOS 和 Linux 的本地图片目录。

/// 桌面端目录扫描实现。
class DirectoryPhotoService extends PhotoService {
  /// 创建目录照片服务。
  DirectoryPhotoService();

  /// 桌面端不需要系统图库权限。
  @override
  Future<void> checkPermission() async {}

  /// 选择一个目录作为本地相册。
  Future<PhotoAlbum?> pickAlbum() async {
    final selected = await FilePicker.platform.getDirectoryPath();
    if (selected == null || selected.isEmpty) return null;
    final directory = Directory(selected);
    return PhotoAlbum(
      id: directory.path,
      name: p.basename(p.normalize(directory.path)),
      path: directory.path,
      directory: directory,
    );
  }

  /// 桌面端选择页显示当前选择的目录。
  @override
  Future<List<PhotoAlbum>> listAlbums() async {
    final album = await pickAlbum();
    return album == null ? const [] : [album];
  }

  /// 由保存的目录路径恢复相册。目录不存在时返回空。
  @override
  Future<PhotoAlbum?> getPhotoAlbum(String id, {String? path}) async {
    final directoryPath = path ?? id;
    final directory = Directory(directoryPath);
    if (!await directory.exists()) return null;
    return PhotoAlbum(
      id: id,
      name: p.basename(p.normalize(directoryPath)),
      path: directoryPath,
      directory: directory,
    );
  }

  /// 读取目录中的图片数量和最新修改图片的缩略封面。
  @override
  Future<PhotoAlbumInfo> getInfo(
    PhotoAlbum album, {
    bool imagesOnly = true,
  }) async {
    final photos = await _files(album);
    return PhotoAlbumInfo(
      album: album,
      count: photos.length,
      cover: photos.isEmpty ? null : await _readCover(photos.first),
    );
  }

  /// 将封面等比缩至最长边 256 像素，以 PNG 缓存且不放大小图。
  Future<Uint8List> _readCover(File file) async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final landscape = descriptor.width >= descriptor.height;
      codec = await descriptor.instantiateCodec(
        targetWidth: landscape && descriptor.width > 256 ? 256 : null,
        targetHeight: !landscape && descriptor.height > 256 ? 256 : null,
      );
      image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw const ApiException("Couldn't create an album cover");
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  /// 统计目录中的图片数量。
  @override
  Future<int> count(PhotoAlbum album) async => (await _files(album)).length;

  /// 分页扫描目录图片，并按修改时间倒序返回。
  @override
  Stream<List<SyncPhoto>> scanAlbum(
    PhotoAlbum album, {
    required bool Function() isStopped,
  }) async* {
    final files = await _files(album);
    for (
      var start = 0;
      start < files.length;
      start += PhotoService.scanPageSize
    ) {
      if (isStopped()) return;
      final page = <SyncPhoto>[];
      for (final file in files.skip(start).take(PhotoService.scanPageSize)) {
        if (isStopped()) return;
        final stat = await file.stat();
        page.add(
          SyncPhoto(
            name: p.basename(file.path),
            size: stat.size,
            path: file.path,
            modifiedDateTime: stat.modified,
            mimeType: imageMimeType(file.path),
          ),
        );
      }
      if (page.isNotEmpty) yield page;
    }
  }

  /// 收集当前目录下的图片并按修改时间倒序排列。
  Future<List<File>> _files(PhotoAlbum album) async {
    final directory = album.directory;
    if (directory == null) {
      throw const ApiException("Couldn't read the local folder");
    }
    final files = <File>[];
    await for (final entity in directory.list(
      recursive: false,
      followLinks: false,
    )) {
      if (entity is! File || !isAllowedImageName(entity.path)) continue;
      if (!isAllowedImageHeader(await readImageHeader(entity))) continue;
      files.add(entity);
    }
    final stats = <String, FileStat>{
      for (final file in files) file.path: await file.stat(),
    };
    files.sort(
      (first, second) =>
          stats[second.path]!.modified.compareTo(stats[first.path]!.modified),
    );
    return files;
  }
}

/// 根据文件扩展名提供上传 MIME 类型。
String imageMimeType(String filePath) {
  switch (p.extension(filePath).toLowerCase()) {
    case '.jpg':
    case '.jpeg':
    case '.jfif':
      return 'image/jpeg';
    case '.png':
      return 'image/png';
    case '.gif':
      return 'image/gif';
    case '.webp':
      return 'image/webp';
    default:
      return 'application/octet-stream';
  }
}
