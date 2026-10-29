import 'dart:typed_data';

// 任务卡片和相册选择列表共用的相册展示数据。

/// 保存照片封面数据，避免构建列表时重复读取缩略图。
class TaskPreview {
  /// 创建相册预览。
  const TaskPreview({
    required this.albumId,
    required this.albumName,
    required this.count,
    this.cover,
    this.completedCount = 0,
    this.storageName = 'Local storage',
    this.storageMissing = false,
    this.path,
    this.isInvalid = false,
  });

  /// 设备相册标识。
  final String albumId;

  /// 相册显示名称。
  final String albumName;

  /// 相册照片数量。
  final int count;

  /// 首张照片的缩略图。
  final Uint8List? cover;

  /// 上次保存的已同步张数。
  final int completedCount;

  /// 添加任务时选择的存储名称。
  final String storageName;

  /// 当前任务的存储 ID 无法关联到当前账户的存储缓存。
  final bool storageMissing;

  /// 桌面相册目录路径。
  final String? path;

  /// 本地相册无法读取时在名称前显示失效标签。
  final bool isInvalid;
}
