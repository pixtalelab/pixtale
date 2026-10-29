import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

// 统一处理 JSON 请求、文件上传和服务端错误。
// 服务端鉴权失败同时返回 HTTP 401 和业务 code 401；403 只表示无权限。

/// 当前隔离区在登录失效时停止同步并删除本地用户。
Future<void> Function()? onUnauthorized;

bool _unauthorizedPending = false;

/// 同一批并发 401 只处理一次，处理结束后允许下一次失效再退出。
void notifyUnauthorized() {
  final handler = onUnauthorized;
  if (handler == null || _unauthorizedPending) return;
  _unauthorizedPending = true;
  scheduleMicrotask(() async {
    try {
      await handler();
    } finally {
      _unauthorizedPending = false;
    }
  });
}

/// 服务端业务请求异常。
class ApiException implements Exception {
  /// 创建包含状态码的请求异常。
  const ApiException(this.message, {this.statusCode, this.code});

  /// 照片访问被拒绝，界面按文案匹配时不要依赖翻译后的句子。
  static const photoPermission = 'photoPermission';

  final String message;
  final int? statusCode;

  /// 稳定错误码。界面捕获权限失败时优先看这个，而不是中文句子。
  final String? code;

  /// 是否为照片权限失败。旧调用只抛中文时仍能识别。
  bool get isPhotoPermission =>
      code == photoPermission ||
      message.contains('Photo access') ||
      message.contains('照片访问权限');

  /// 从任意捕获对象判断是否为照片权限失败。
  static bool isPhotoPermissionError(Object error) {
    if (error is ApiException) return error.isPhotoPermission;
    return '$error'.contains('Photo access') ||
        '$error'.contains('照片访问权限');
  }

  /// 返回可直接显示的错误信息。
  @override
  String toString() => message;
}

/// 统一 JSON POST 请求，处理 HTTP 状态和服务端业务状态。
Future<T> post<T>(
  String path, {
  required String baseUrl,
  Object? body,
  String? token,
  http.Client? client,
  T Function(dynamic data)? decode,
}) async {
  final connection = client ?? http.Client();
  final abort = Completer<void>();
  try {
    final endpoint = '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}$path';
    final request =
        http.AbortableRequest(
            'POST',
            Uri.parse(endpoint),
            abortTrigger: abort.future,
          )
          ..headers.addAll({
            HttpHeaders.contentTypeHeader: 'application/json',
            HttpHeaders.acceptHeader: 'application/json',
            if (token != null && token.isNotEmpty)
              HttpHeaders.authorizationHeader: token,
          });
    if (body != null) request.body = jsonEncode(body);
    final response = await connection
        .send(request)
        .then(http.Response.fromStream)
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            abort.complete();
            throw const ApiException('Request timed out');
          },
        );
    final data = _responseData(response);
    return decode == null ? data as T : decode(data);
  } on ApiException {
    rethrow;
  } on SocketException {
    throw const ApiException('Network error');
  } on http.ClientException {
    throw const ApiException('Network error');
  } on TimeoutException {
    throw const ApiException('Request timed out');
  } on FormatException {
    throw const ApiException('Invalid response');
  } finally {
    if (client == null) connection.close();
  }
}

/// 以文件流发送 multipart 表单，交由调用方管理请求取消。
Future<dynamic> upload(
  String path, {
  required String baseUrl,
  required String token,
  required http.Client client,
  required Map<String, String> fields,
  required http.MultipartFile file,
}) async {
  final endpoint = '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}$path';
  final abort = Completer<void>();
  final request =
      http.AbortableMultipartRequest(
          'POST',
          Uri.parse(endpoint),
          abortTrigger: abort.future,
        )
        ..headers[HttpHeaders.authorizationHeader] = token
        ..fields.addAll(fields)
        ..files.add(file);
  try {
    final response = await client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(
          const Duration(minutes: 3),
          onTimeout: () {
            abort.complete();
            throw const ApiException('Upload timed out');
          },
        );
    return _responseData(response);
  } on http.ClientException {
    throw const ApiException('Network error');
  } on SocketException {
    throw const ApiException('Network error');
  } on TimeoutException {
    throw const ApiException('Upload timed out');
  } on FormatException {
    throw const ApiException('Invalid response');
  }
}

/// 统一二进制 GET 请求。
Future<List<int>> getBytes(
  String path, {
  required String baseUrl,
  String? token,
}) async {
  final client = HttpClient();
  try {
    final endpoint = '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}$path';
    final request = await client.getUrl(Uri.parse(endpoint));
    request.headers.set(HttpHeaders.acceptHeader, '*/*');
    if (token != null && token.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, token);
    }
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) notifyUnauthorized();
      throw ApiException('Request failed', statusCode: response.statusCode);
    }
    return await response.fold<List<int>>(
      [],
      (bytes, chunk) => bytes..addAll(chunk),
    );
  } on ApiException {
    rethrow;
  } on SocketException {
    throw const ApiException('Network error');
  } on TimeoutException {
    throw const ApiException('Request timed out');
  } finally {
    client.close(force: true);
  }
}

/// 校验 HTTP 和业务状态，再提取响应数据。
dynamic _responseData(http.Response response) {
  dynamic decoded;
  try {
    decoded = _decodeJson(utf8.decode(response.bodyBytes));
  } on FormatException {
    if (response.statusCode >= 200 && response.statusCode < 300) rethrow;
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    _throwResponse(decoded, response.statusCode);
  }
  if (decoded is Map<String, dynamic> &&
      decoded.containsKey('code') &&
      decoded['code'] != 200) {
    _throwResponse(decoded, decoded['code'] as int?);
  }
  return decoded is Map<String, dynamic> && decoded.containsKey('data')
      ? decoded['data']
      : decoded;
}

/// 解析允许为空的 JSON 响应。
dynamic _decodeJson(String text) {
  if (text.trim().isEmpty) return null;
  return jsonDecode(text);
}

/// 登录失效时先安排退出，再把错误抛给当前请求。
Never _throwResponse(dynamic decoded, int? statusCode) {
  if (statusCode == 401) notifyUnauthorized();
  throw ApiException(_message(decoded), statusCode: statusCode);
}

/// 提取服务端可显示的错误信息。
String _message(dynamic response) {
  if (response is Map<String, dynamic>) {
    final message = response['message'];
    if (message is String && message.isNotEmpty) return message;
  }
  return 'Request failed';
}
