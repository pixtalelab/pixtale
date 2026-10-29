import 'dart:io';

import 'package:media_store/media_store.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:pixtale_sync/models/photo.dart';
import 'package:pixtale_sync/models/sync.dart';
import 'package:pixtale_sync/request/request.dart';
import 'package:pixtale_sync/services/directory_photo_service.dart';
import 'package:pixtale_sync/services/mobile_photo_service.dart';

// 定义本地照片来源的统一接口和移动端兼容基础能力。

/// 本地照片来源的统一接口。
class PhotoService {
  /// 创建照片服务。
  const PhotoService();

  /// 创建当前平台的照片服务。
  static PhotoService create() {
    if (Platform.environment['FLUTTER_TEST'] == 'true') {
      return MobilePhotoService();
    }
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return DirectoryPhotoService();
    }
    return MobilePhotoService();
  }

  /// 创建按文件更新时间倒序读取相册内容的筛选配置。
  static FilterOptionGroup albumFilter() {
    return FilterOptionGroup(
      orders: const [OrderOption(type: OrderOptionType.updateDate, asc: false)],
    );
  }

  /// 检查照片访问权限。
  Future<void> checkPermission() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.hasAccess) {
      throw const ApiException(
        'Photo access is required',
        code: ApiException.photoPermission,
      );
    }
  }

  /// 读取当前平台可选的本地相册。
  Future<List<PhotoAlbum>> listAlbums() async =>
      MobilePhotoService().listAlbums();

  /// 恢复保存的相册。系统或目录中不存在时返回空。
  Future<PhotoAlbum?> getPhotoAlbum(String id, {String? path}) async {
    final album = await getAlbum(id);
    if (album == null) return null;
    return PhotoAlbum(
      id: album.id,
      name: album.name,
      entity: album,
      path: path,
    );
  }

  /// 读取相册数量和最新封面。
  Future<PhotoAlbumInfo> getInfo(
    PhotoAlbum album, {
    bool imagesOnly = true,
  }) async {
    final entity = album.entity;
    if (entity == null) throw const ApiException("Couldn't read the local album");
    final count = imagesOnly
        ? await countImages(entity)
        : await entity.assetCountAsync;
    final assets = await entity.getAssetListRange(start: 0, end: 1);
    return PhotoAlbumInfo(
      album: album,
      count: count,
      cover: assets.isEmpty
          ? null
          : await assets.first.thumbnailDataWithSize(
              const ThumbnailSize(240, 240),
            ),
    );
  }

  /// 只读取照片和视频的合计数量，供选择列表排序，不加载封面。
  Future<int> countMedia(PhotoAlbum album) async {
    final entity = album.entity;
    if (entity == null) throw const ApiException("Couldn't read the local album");
    return entity.assetCountAsync;
  }

  /// 扫描相册中的图片。
  Stream<List<SyncPhoto>> scanAlbum(
    PhotoAlbum album, {
    required bool Function() isStopped,
  }) {
    final entity = album.entity;
    if (entity == null) {
      return Stream.error(const ApiException("Couldn't read the local album"));
    }
    return scan(entity, isStopped: isStopped);
  }

  /// 统计相册中的图片。
  Future<int> count(PhotoAlbum album) async {
    final entity = album.entity;
    if (entity == null) throw const ApiException("Couldn't read the local album");
    return countImages(entity);
  }

  /// 根据已保存的系统 ID 恢复相册。系统查不到该相册时返回空。
  Future<AssetPathEntity?> getAlbum(String id) {
    return AssetPathEntity(
      id: id,
      name: '',
      type: RequestType.common,
      filterOption: albumFilter(),
    ).fetchPathProperties(filterOptionGroup: albumFilter());
  }

  /// 由系统直接统计照片数量，保留原相册的混合媒体封面来源。
  static Future<int> countImages(AssetPathEntity album) {
    final images = album.type == RequestType.image
        ? album
        : album.copyWith(type: RequestType.image, albumType: album.albumType);
    return images.assetCountAsync;
  }

  /// 本地扫描每页张数，同时作为 Android 体积批量查询上限。
  static const scanPageSize = 995;

  /// 分页读取文件名和大小。Android 用本页 MediaStore 结果，不再逐张查询。
  Stream<List<SyncPhoto>> scan(
    AssetPathEntity album, {
    required bool Function() isStopped,
  }) async* {
    for (var page = 0; ; page++) {
      if (isStopped()) return;
      final assets = await album.getAssetListPaged(
        page: page,
        size: scanPageSize,
        type: RequestType.image,
      );
      if (assets.isEmpty) return;
      var useAndroidPage = Platform.isAndroid;
      var sizes = const <String, int>{};
      if (useAndroidPage) {
        try {
          sizes = await MediaStoreQuery.querySizes([
            for (final asset in assets) asset.id,
          ]);
        } catch (_) {
          useAndroidPage = false;
        }
      }
      final photos = <SyncPhoto>[];
      for (final asset in assets) {
        if (isStopped()) return;
        var name = useAndroidPage ? (asset.title ?? '').trim() : '';
        if (name.isEmpty) name = (await asset.titleAsync).trim();
        var size = useAndroidPage ? (sizes[asset.id] ?? 0) : 0;
        if (size <= 0) size = await asset.fileSize;
        if (name.isEmpty || size <= 0) {
          throw const ApiException(
            "Couldn't read the photo name or size. Check that the photo is accessible.",
          );
        }
        photos.add(SyncPhoto(asset: asset, name: name, size: size));
      }
      yield photos;
    }
  }

  /// 读取移动端资产或桌面本地文件。
  Future<File> getFile(SyncPhoto photo, PMCancelToken cancelToken) async {
    final asset = photo.asset;
    if (asset == null) {
      final file = File(photo.path!);
      if (!await file.exists() || await file.length() != photo.size) {
        throw ApiException('Photo changed, sync again: ${photo.name}');
      }
      return file;
    }
    final file = await asset.loadFile(cancelToken: cancelToken);
    if (file == null || await file.length() != photo.size) {
      throw ApiException('Photo changed, sync again: ${photo.name}');
    }
    return file;
  }
}
