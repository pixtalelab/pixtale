import 'dart:typed_data';

// 本地任务记录，保存来源相册和添加时间。

/// 已添加的相册任务。
class Task {
  /// 创建任务记录。
  const Task({
    required this.albumId,
    required this.sortTime,
    this.completedCount = 0,
    this.storageId,
    this.storageName,
    this.path,
    this.albumName = '',
    this.photoCount = 0,
    this.cover,
    this.isInvalid = false,
  });

  /// 设备相册标识。
  final String albumId;

  /// 添加时的 UTC 时间。
  final DateTime sortTime;

  /// 最近一次核对并关联到远端相册的照片张数。
  final int completedCount;

  /// 添加任务时选择的存储，旧任务为空。
  final String? storageId;

  /// 按当前账户关联到的存储名称，未关联时为空。
  final String? storageName;

  /// 桌面任务对应的目录路径，移动端为空。
  final String? path;

  /// 缓存的本地相册名称。
  final String albumName;

  /// 缓存的照片数量，不包含视频。
  final int photoCount;

  /// 缓存的相册封面。
  final Uint8List? cover;

  /// 本地相册已无法读取，恢复可读取后解除失效。
  final bool isInvalid;
}
