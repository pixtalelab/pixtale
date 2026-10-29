import 'package:pixtale_sync/request/request.dart';

// 统一管理登录、用户信息与头像接口。

/// 登录请求参数。
class LoginParams {
  const LoginParams({required this.username, required this.password});

  final String username;
  final String password;
}

/// 服务端当前用户信息。
class UserInfo {
  const UserInfo({
    required this.userId,
    required this.username,
    required this.avatar,
    required this.type,
  });

  final String userId;
  final String username;
  final String avatar;
  final int type;

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      userId: json['userId'] as String,
      username: json['username'] as String,
      avatar: json['avatar'] as String? ?? '',
      type: json['type'] as int? ?? 0,
    );
  }
}

/// 使用指定端点登录并返回 JWT。
Future<String> login(String endpoint, LoginParams params) {
  return post<String>(
    '/api/login',
    baseUrl: endpoint,
    body: {'username': params.username, 'password': params.password},
    decode: (data) => (data as Map<String, dynamic>)['token'] as String,
  );
}

/// 查询当前登录用户信息。
Future<UserInfo?> getUserInfo(String endpoint, String token) {
  return post<UserInfo?>(
    '/api/user/info',
    baseUrl: endpoint,
    token: token,
    decode: (data) =>
        data == null ? null : UserInfo.fromJson(data as Map<String, dynamic>),
  );
}

/// 下载当前用户的头像文件。
Future<List<int>> getUserAvatar(String key, String endpoint, String token) {
  return getBytes(_avatarPath(key), baseUrl: endpoint, token: token);
}

/// 生成头像路径并编码文件标识。
String _avatarPath(String key) =>
    '/api/user/avatar/${Uri.encodeComponent(key)}';
