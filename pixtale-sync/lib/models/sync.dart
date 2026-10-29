import 'dart:io';
import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';

// 同步使用的本地照片、远端配置及进度数据。

/// 电脑筛选和手机上传都接受的图片扩展名。
const allowedImageExtensions = {
  '.jpg',
  '.jpeg',
  '.png',
  '.jfif',
  '.webp',
  '.gif',
};

/// 文件头识别结果里允许上传的 MIME。
const _allowedImageMimeTypes = {
  'image/jpeg',
  'image/png',
  'image/gif',
  'image/webp',
};

/// 按文件名判断扩展名是否在白名单内。
bool isAllowedImageName(String name) =>
    allowedImageExtensions.contains(p.extension(name).toLowerCase());

/// 读取图片开头，长度足够匹配 mime 的全部文件头。
Future<Uint8List> readImageHeader(File file) async {
  final handle = await file.open();
  try {
    return await handle.read(defaultMagicNumbersMaxLength);
  } finally {
    await handle.close();
  }
}

/// 文件头是否属于白名单中的图片。扩展名和真实类型可以不同。
bool isAllowedImageHeader(List<int> bytes) {
  final mimeType = lookupMimeType('header', headerBytes: bytes);
  return _allowedImageMimeTypes.contains(mimeType);
}

/// 扫描出的本地照片，文件大小仅用于本轮查重。
class SyncPhoto {
  /// 创建待核对照片。
  const SyncPhoto({
    this.asset,
    required this.name,
    required this.size,
    this.path,
    this.modifiedDateTime,
    this.mimeType = 'application/octet-stream',
  });

  final AssetEntity? asset;
  final String name;
  final int size;
  final String? path;
  final DateTime? modifiedDateTime;
  final String mimeType;

  /// 返回移动端实体 ID 或桌面文件路径。
  String get id => asset?.id ?? path!;

  /// 返回上传时使用的修改时间。
  DateTime get effectiveModifiedDateTime =>
      modifiedDateTime ?? asset!.modifiedDateTime;

  /// 与服务端照片匹配的文件标识。
  String get key => '$name\u0000$size';
}

/// 远端查重使用的文件名和体积。
class SyncFile {
  /// 创建查重记录。
  const SyncFile({required this.name, required this.size});

  /// 从服务端响应解析缺失文件。
  factory SyncFile.fromJson(Map<String, dynamic> json) => SyncFile(
    name: json['name'] as String,
    size: (json['size'] as num).toInt(),
  );

  final String name;
  final int size;

  /// 与本地照片匹配的文件标识。
  String get key => '$name\u0000$size';

  /// 转换为查重请求体。
  Map<String, dynamic> toJson() => {'name': name, 'size': size};
}

/// 远端照片索引，保留相册关联所需的照片 ID。
class RemotePhoto {
  /// 从服务端响应解析照片。
  RemotePhoto.fromJson(Map<String, dynamic> json)
    : id = json['photoId'] as String,
      name = json['name'] as String,
      size = (json['size'] as num).toInt(),
      takenTime = json['takenTime'] as String;

  final String id;
  final String name;
  final int size;
  final String takenTime;

  /// 与本地照片匹配的文件标识。
  String get key => '$name\u0000$size';
}

/// 单个相册的实时同步进度。
class SyncProgress {
  /// 创建进度快照。
  const SyncProgress({
    required this.albumId,
    required this.completed,
    required this.total,
    required this.storageName,
  });

  final String albumId;
  final int completed;
  final int total;
  final String storageName;

  /// 从后台服务消息恢复进度。
  factory SyncProgress.fromJson(Map<String, dynamic> json) => SyncProgress(
    albumId: json['albumId'] as String,
    completed: json['completed'] as int,
    total: json['total'] as int,
    storageName: json['storageName'] as String,
  );

  /// 转换为可跨隔离区传递的进度数据。
  Map<String, dynamic> toJson() => {
    'albumId': albumId,
    'completed': completed,
    'total': total,
    'storageName': storageName,
  };
}

/// 同步的定时等待或停止状态，不改变卡片已缓存的进度。
class SyncActivity {
  /// 创建同步活动状态。
  const SyncActivity({this.nextSyncAt, this.stopping = false});

  final DateTime? nextSyncAt;
  final bool stopping;

  /// 从后台消息恢复活动状态。
  factory SyncActivity.fromJson(Map<String, dynamic> json) => SyncActivity(
    nextSyncAt: DateTime.tryParse(json['nextSyncAt'] as String? ?? ''),
    stopping: json['stopping'] == true,
  );

  /// 转换为后台消息使用的数据。
  Map<String, dynamic> toJson() => {
    'nextSyncAt': nextSyncAt?.toIso8601String(),
    'stopping': stopping,
  };
}
