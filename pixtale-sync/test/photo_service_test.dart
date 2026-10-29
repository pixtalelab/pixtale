import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:pixtale_sync/models/photo.dart';
import 'package:media_store/media_store.dart';
import 'package:pixtale_sync/services/mobile_photo_service.dart';
import 'package:pixtale_sync/services/photo_service.dart';

// 验证照片直接计数与混合媒体封面互不影响。

/// 执行移动端照片数量与封面查询测试。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.fluttercandies/photo_manager');
  const service = PhotoService();
  final calls = <MethodCall>[];
  final cover = Uint8List.fromList([1, 2, 3]);
  var imageCount = 0;
  var mediaCount = 0;
  late AssetPathEntity entity;
  late PhotoAlbum album;

  setUp(() {
    calls.clear();
    imageCount = 0;
    mediaCount = 0;
    entity = AssetPathEntity(
      id: 'isAll',
      name: 'Recent',
      isAll: true,
      filterOption: PhotoService.albumFilter(),
    );
    album = PhotoAlbum(id: entity.id, name: entity.name, entity: entity);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'getAssetCountFromPath':
              return call.arguments['type'] == RequestType.image.value
                  ? imageCount
                  : mediaCount;
            case 'getAssetListRange':
              return {
                'data': [
                  {
                    'id': 'latest-video',
                    'type': AssetType.video.index,
                    'width': 1920,
                    'height': 1080,
                    'duration': 10,
                  },
                ],
              };
            case 'getThumb':
              return cover;
            default:
              throw StateError('不应调用 ${call.method}');
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('Recent 大相册只发起一次照片计数，不读取分页或重新恢复相册', () async {
    imageCount = 25000;
    mediaCount = 30000;

    expect(await service.count(album), 25000);
    expect(calls.map((call) => call.method), ['getAssetCountFromPath']);
    expect(calls.single.arguments['id'], 'isAll');
    expect(calls.single.arguments['type'], RequestType.image.value);
    expect(calls.single.arguments['option'], entity.filterOption!.toMap());
    expect(entity.type, RequestType.common);
    expect(entity.isAll, isTrue);
  });

  test('纯视频相册照片为零，仍从混合媒体中读取最新视频封面', () async {
    mediaCount = 12;
    final info = await service.getInfo(album);

    expect(info.count, 0);
    expect(info.cover, orderedEquals(cover));
    final counts = calls.where(
      (call) => call.method == 'getAssetCountFromPath',
    );
    expect(counts.map((call) => call.arguments['type']), [
      RequestType.image.value,
      RequestType.common.value,
    ]);
    final range = calls.singleWhere(
      (call) => call.method == 'getAssetListRange',
    );
    expect(range.arguments['type'], RequestType.common.value);
    expect(range.arguments['start'], 0);
    expect(range.arguments['end'], 1);
    expect(
      calls.singleWhere((call) => call.method == 'getThumb').arguments['id'],
      'latest-video',
    );
  });

  test('选择列表继续显示照片与视频合计数量', () async {
    imageCount = 3;
    mediaCount = 8;

    expect(await service.countMedia(album), 8);
    final info = await service.getInfo(album, imagesOnly: false);
    expect(info.count, 8);
    expect(info.cover, orderedEquals(cover));
    expect(
      calls
          .where((call) => call.method == 'getAssetCountFromPath')
          .every((call) => call.arguments['type'] == RequestType.common.value),
      isTrue,
    );
  });

  test('非 Android 列出相册时不读取路径修改时间，保持系统返回顺序', () async {
    late Map<dynamic, dynamic> option;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'requestPermissionExtend':
              return 3;
            case 'getAssetPathList':
              option =
                  (call.arguments['option'] as Map)['child']
                      as Map<dynamic, dynamic>;
              return {
                'data': [
                  {'id': 'old', 'name': 'Old', 'isAll': false},
                  {'id': 'new', 'name': 'New', 'isAll': false},
                ],
              };
            default:
              throw StateError('不应调用 ${call.method}');
          }
        });

    final albums = await MobilePhotoService().listAlbums();
    expect(albums.map((album) => album.id), ['old', 'new']);
    expect(option['containsPathModified'], isFalse);
  });

  test('MediaStore 相册按已排好的更新时间转成系统相册实体', () {
    final albums = MobilePhotoService.albumsFromBuckets(const [
      MediaStoreAlbum(id: 'new', name: 'New', modified: 300),
      MediaStoreAlbum(id: 'old', name: 'Old', modified: 100),
    ]);
    expect(albums.map((album) => album.id), ['new', 'old']);
    expect(albums.first.entity?.lastModified, DateTime.fromMillisecondsSinceEpoch(300000));
    expect(albums.last.entity?.lastModified, DateTime.fromMillisecondsSinceEpoch(100000));
  });

  test('照片计数失败交给调用方处理，不回退成包含视频的错误数量', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          throw PlatformException(code: 'count_failed');
        });

    await expectLater(service.count(album), throwsA(isA<PlatformException>()));
    expect(calls.map((call) => call.method), ['getAssetCountFromPath']);
  });
}
