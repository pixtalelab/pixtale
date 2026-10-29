import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pixtale_sync/models/sync.dart';
import 'package:pixtale_sync/models/storage.dart';
import 'package:pixtale_sync/models/user.dart';
import 'package:pixtale_sync/request/request.dart';
import 'package:pixtale_sync/request/storage.dart' as storage_request;

// 统一管理同步接口的路径、参数、上传表单和响应解析。

/// 使用本轮固定账户和客户端发送同步请求。
class SyncApi {
  /// 创建可取消的同步接口。
  SyncApi(this.user, this.client);

  /// 远程检测每次提交的本地文件数量。
  static const checkPageSize = 995;

  final User user;
  final http.Client client;

  /// 查询当前可用存储，沿用本轮可取消的连接。
  Future<List<Storage>> getStorages() =>
      storage_request.listStorages(user, client: client);

  /// 按本地相册名取得或创建远端相册。
  Future<String> getAlbum(String name, String storageId) async {
    final config = await _post<Map<String, dynamic>>('/api/sync/getConfig', {
      'albumName': [name],
      'storageId': storageId,
    });
    if (config['storageExists'] != true) {
      throw const ApiException('Selected storage is unavailable');
    }
    final albums = (config['album'] as List).cast<Map<String, dynamic>>();
    return albums.singleWhere((item) => item['name'] == name)['albumId']
        as String;
  }

  /// 提交本页扫描到的文件名和体积，返回远端还不存在、可以上传的文件。
  Future<List<SyncFile>> check(List<SyncFile> files) async {
    final data = await _post<List<dynamic>>(
      '/api/sync/check',
      files.map((file) => file.toJson()).toList(),
    );
    return data
        .map((item) => SyncFile.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// 上传原文件并返回新照片，重复上传时由调用方重新查询。
  Future<RemotePhoto?> uploadPhoto(
    SyncPhoto photo,
    File file,
    String albumId,
    String storageId,
    String lock,
  ) async {
    final mimeType =
        photo.asset == null || photo.mimeType != 'application/octet-stream'
        ? photo.mimeType
        : await photo.asset!.mimeTypeAsync ?? photo.mimeType;
    final data = await upload(
      '/api/photo/add',
      baseUrl: user.endpoint,
      token: user.token,
      client: client,
      fields: {
        'lock': lock,
        'albumId': albumId,
        'storageId': storageId,
        'lastModified':
            '${photo.effectiveModifiedDateTime.millisecondsSinceEpoch}',
      },
      file: await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: photo.name,
        contentType: http.MediaType.parse(mimeType),
      ),
    ) as Map<String, dynamic>;
    final item = data['photo'];
    return item == null
        ? null
        : RemotePhoto.fromJson(item as Map<String, dynamic>);
  }

  /// 携带本轮账户信息调用统一 JSON 请求。
  Future<T> _post<T>(String path, [Object? body]) => post<T>(
    path,
    baseUrl: user.endpoint,
    token: user.token,
    client: client,
    body: body,
  );
}
