import 'package:flutter/services.dart';

/// 按页向 MediaStore 读取文件体积，并一次查出带最新修改时间的相册。
class MediaStoreQuery {
  static const _channel = MethodChannel('pixtale_sync/media_store');

  /// 一次查询一批资产 ID 对应的字节数。
  static Future<Map<String, int>> querySizes(List<String> ids) async {
    if (ids.isEmpty) return const {};
    final result = await _channel.invokeMapMethod<String, Object>(
      'querySizes',
      {'ids': ids},
    );
    return {
      for (final entry in (result ?? const {}).entries)
        entry.key: (entry.value as num).toInt(),
    };
  }

  /// 一次扫出全部图片和视频相册，已按最新修改时间从新到旧排序。
  static Future<List<MediaStoreAlbum>> queryAlbums() async {
    final rows = await _channel.invokeListMethod<Object>('queryAlbums') ?? const [];
    return [
      for (final row in rows)
        if (row is Map)
          MediaStoreAlbum(
            id: '${row['id'] ?? ''}',
            name: '${row['name'] ?? ''}',
            modified: (row['modified'] as num?)?.toInt() ?? 0,
          ),
    ];
  }
}

/// MediaStore 相册及其最新修改时间（秒）。
class MediaStoreAlbum {
  /// 创建 MediaStore 相册摘要。
  const MediaStoreAlbum({
    required this.id,
    required this.name,
    required this.modified,
  });

  final String id;
  final String name;
  final int modified;
}
