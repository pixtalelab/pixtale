import 'dart:io';

import 'package:media_store/media_store.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:pixtale_sync/models/photo.dart';
import 'package:pixtale_sync/request/request.dart';
import 'package:pixtale_sync/services/photo_service.dart';

// 使用 photo_manager 读取 Android 和 iOS 系统相册。

/// 移动端系统相册实现。
class MobilePhotoService extends PhotoService {
  /// 创建移动端照片服务。
  MobilePhotoService({this.background = false});

  /// 后台只使用用户已授予的权限，不从无界面的服务弹出授权窗口。
  final bool background;

  /// 前台请求图库权限，后台关闭插件的 Activity 权限检查。
  @override
  Future<void> checkPermission() async {
    if (background) {
      await PhotoManager.setIgnorePermissionCheck(true);
    } else {
      await super.checkPermission();
    }
  }

  /// 读取系统相册。Android 一次 MediaStore 查询并按更新时间倒序。
  @override
  Future<List<PhotoAlbum>> listAlbums() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.hasAccess) {
      throw const ApiException(
        'Photo access is required to choose albums',
        code: ApiException.photoPermission,
      );
    }
    if (Platform.isAndroid) {
      return albumsFromBuckets(await MediaStoreQuery.queryAlbums());
    }
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      filterOption: PhotoService.albumFilter(),
    );
    return albums
        .map(
          (album) => PhotoAlbum(id: album.id, name: album.name, entity: album),
        )
        .toList();
  }

  /// 把 MediaStore 相册转成选择页使用的系统相册实体。
  static List<PhotoAlbum> albumsFromBuckets(List<MediaStoreAlbum> albums) {
    return [
      for (final album in albums)
        PhotoAlbum(
          id: album.id,
          name: album.name,
          entity: AssetPathEntity(
            id: album.id,
            name: album.name,
            lastModified: album.modified <= 0
                ? null
                : DateTime.fromMillisecondsSinceEpoch(album.modified * 1000),
            type: RequestType.common,
            filterOption: PhotoService.albumFilter(),
          ),
        ),
    ];
  }
}
