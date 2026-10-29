import 'dart:typed_data';

// 本地保存的登录用户及头像缓存。

/// 本地保存的登录用户。
class User {
  /// 创建用户信息，可携带本地头像图片。
  const User({
    required this.userId,
    required this.username,
    required this.avatar,
    required this.type,
    required this.token,
    required this.endpoint,
    this.avatarBytes,
  });

  final String userId;
  final String username;
  final String avatar;
  final int type;
  final String token;
  final String endpoint;
  final Uint8List? avatarBytes;
}
