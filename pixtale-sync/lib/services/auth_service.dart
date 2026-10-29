import 'package:pixtale_sync/models/user.dart';
import 'package:pixtale_sync/request/user.dart' as user_request;

/// 用户登录业务：组合远端用户请求和本地用户模型。
class AuthService {
  const AuthService();

  Future<User> login({
    required String endpoint,
    required String username,
    required String password,
  }) async {
    final base = endpoint.replaceFirst(RegExp(r'/+$'), '');
    final token = await user_request.login(
      base,
      user_request.LoginParams(username: username, password: password),
    );
    final info = await user_request.getUserInfo(base, token);
    if (info == null) {
      throw const FormatException("User info wasn't returned");
    }
    return User(
      userId: info.userId,
      username: info.username,
      avatar: info.avatar,
      type: info.type,
      token: token,
      endpoint: base,
    );
  }
}
