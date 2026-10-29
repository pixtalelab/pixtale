import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:pixtale_sync/models/sync.dart';
import 'package:pixtale_sync/models/user.dart';
import 'package:pixtale_sync/request/request.dart';
import 'package:pixtale_sync/request/sync.dart';

// 验证同步接口协议、上传表单和 HTTP 错误解析。

/// 执行无需真实服务端的协议测试。
void main() {
  const user = User(
    userId: 'user',
    username: 'tester',
    avatar: '',
    type: 0,
    token: 'session-token',
    endpoint: 'https://example.test/',
  );

  test('查询全部可用存储并携带原始登录凭证', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/storage/select');
      expect(request.method, 'POST');
      expect(request.headers['authorization'], user.token);
      return response([
        {'storageId': 's3', 'name': 'S3', 'type': 3},
        {'storageId': 'disk-42', 'name': '本地照片', 'type': 1},
      ]);
    });
    addTearDown(client.close);
    final storages = await SyncApi(user, client).getStorages();
    expect(storages.map((item) => item.id), ['s3', 'disk-42']);
    expect(storages.map((item) => item.name), ['S3', '本地照片']);
    expect(storages.map((item) => item.type), [3, 1]);
  });

  test('沿用本地相册名，查重提交扫描结果并返回可上传文件', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body);
      switch (request.url.path) {
        case '/api/sync/getConfig':
          expect(body, {
            'albumName': ['旅行'],
            'storageId': 'disk',
          });
          return response({
            'storageExists': true,
            'album': [
              {'albumId': 'album', 'name': '旅行'},
            ],
          });
        case '/api/sync/check':
          expect(body, [
            {'name': 'old.jpg', 'size': 10},
            {'name': 'new.jpg', 'size': 20},
          ]);
          return response([
            {'name': 'new.jpg', 'size': 20},
          ]);
        default:
          fail('意外接口：${request.url.path}');
      }
    });
    addTearDown(client.close);
    final api = SyncApi(user, client);
    expect(await api.getAlbum('旅行', 'disk'), 'album');
    final missing = await api.check(const [
      SyncFile(name: 'old.jpg', size: 10),
      SyncFile(name: 'new.jpg', size: 20),
    ]);
    expect(missing.single.name, 'new.jpg');
    expect(missing.single.size, 20);
  });

  test('上传以文件流发送原名、相册、存储与重试锁', () async {
    final directory = await Directory.systemTemp.createTemp('sync_upload_');
    addTearDown(() => directory.delete(recursive: true));
    final file = await File('${directory.path}/photo.jpg')
        .writeAsBytes([1, 2, 3]);
    var calls = 0;
    final client = MockClient.streaming((request, stream) async {
      final multipart = request as http.MultipartRequest;
      expect(multipart.headers['authorization'], user.token);
      expect(multipart.fields, {
        'lock': 'same-lock',
        'albumId': 'album',
        'storageId': 'disk',
        'lastModified': '123000',
      });
      expect(multipart.files.single.filename, '原图.jpg');
      expect(multipart.files.single.contentType.toString(), 'image/jpeg');
      final bytes = await stream.toBytes();
      expect(bytes, containsAllInOrder([1, 2, 3]));
      calls++;
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({
              'code': 200,
              'data': {'duplicate': true, 'photo': null},
            }),
          ),
        ),
        200,
      );
    });
    addTearDown(client.close);
    final api = SyncApi(user, client);
    final photo = SyncPhoto(asset: TestAsset(), name: '原图.jpg', size: 3);
    for (var attempt = 0; attempt < 2; attempt++) {
      expect(
        await api.uploadPhoto(photo, file, 'album', 'disk', 'same-lock'),
        isNull,
      );
    }
    expect(calls, 2);
  });

  test('401 通知登录失效且并发只处理一次，403 不退出', () async {
    final gate = Completer<void>();
    var calls = 0;
    onUnauthorized = () {
      calls++;
      return gate.future;
    };
    addTearDown(() => onUnauthorized = null);

    Future<void> send(int status) {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'code': status, 'message': 'Unauthorized'}),
          status,
        ),
      );
      addTearDown(client.close);
      return post<dynamic>(
        '/api/sync/getConfig',
        baseUrl: user.endpoint,
        client: client,
      );
    }

    final denied = send(401);
    final again = send(401);
    await expectLater(
      denied,
      throwsA(
        isA<ApiException>().having((error) => error.statusCode, 'status', 401),
      ),
    );
    await expectLater(
      again,
      throwsA(
        isA<ApiException>().having((error) => error.statusCode, 'status', 401),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    gate.complete();
    await Future<void>.delayed(Duration.zero);

    await expectLater(
      send(403),
      throwsA(
        isA<ApiException>().having((error) => error.statusCode, 'status', 403),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
  });

  test('非 JSON 错误保留 HTTP 状态，成功响应仍校验 JSON', () async {
    for (final status in [401, 503, 200]) {
      final client = MockClient((_) async => http.Response('<html/>', status));
      addTearDown(client.close);
      await expectLater(
        post<dynamic>('/test', baseUrl: user.endpoint, client: client),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            status == 200 ? null : status,
          ),
        ),
      );
    }
  });
}

/// 构造服务端统一响应格式。
http.Response response(Object? data) => http.Response(
  jsonEncode({'code': 200, 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// 上传协议测试使用的元数据，不调用平台插件。
class TestAsset extends AssetEntity {
  /// 创建固定修改时间的图片。
  TestAsset()
    : super(
        id: 'asset',
        typeInt: 1,
        width: 1,
        height: 1,
        modifiedDateSecond: 123,
      );

  /// 返回原文件 MIME 类型。
  @override
  Future<String?> get mimeTypeAsync async => 'image/jpeg';
}
