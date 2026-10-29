import 'package:http/http.dart' as http;
import 'package:pixtale_sync/models/storage.dart';
import 'package:pixtale_sync/models/user.dart';
import 'package:pixtale_sync/request/request.dart';

// 统一管理服务端可用存储的查询接口。

/// 查询全部启用的存储，保持服务端排序。
Future<List<Storage>> listStorages(User user, {http.Client? client}) =>
    post<List<Storage>>(
      '/api/storage/select',
      baseUrl: user.endpoint,
      token: user.token,
      client: client,
      decode: (data) => (data as List)
          .map((item) => Storage.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
