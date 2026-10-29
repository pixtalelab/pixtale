import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_store/media_store.dart';

// 验证相册列表走 MediaStore 通道，并保持从新到旧的顺序。

/// 执行 MediaStore 相册查询测试。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pixtale_sync/media_store');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('一次查出相册并保留插件返回的更新时间顺序', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'queryAlbums');
          return [
            {'id': '2', 'name': '相机', 'modified': 300},
            {'id': '1', 'name': 'QQ', 'modified': 200},
          ];
        });

    final albums = await MediaStoreQuery.queryAlbums();
    expect(albums.map((album) => album.id), ['2', '1']);
    expect(albums.first.name, '相机');
    expect(albums.first.modified, 300);
  });
}
