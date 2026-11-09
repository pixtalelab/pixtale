import 'package:pixtale_sync/db/db.dart';
import 'package:pixtale_sync/models/storage.dart';
import 'package:pixtale_sync/models/user.dart';
import 'package:pixtale_sync/request/storage.dart' as storage_request;
import 'package:pixtale_sync/request/user.dart' as user_request;
import 'package:pixtale_sync/services/rule_service.dart';
import 'package:pixtale_sync/services/storage_service.dart';
import 'package:pixtale_sync/services/user_service.dart';

// 登录成功后一次性保存账户、远端存储及默认规则，再通知页面刷新。

/// 用户登录与该账户本地数据的初始化。
class AuthService {
  /// 测试可注入数据库，默认与其他服务共用本地连接。
  AuthService({Db? database}) : _database = database ?? Db();

  final Db _database;

  /// 读取账户和远端存储，所有本地写入成功后才完成登录。
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
    final user = User(
      userId: info.userId,
      username: info.username,
      avatar: info.avatar,
      type: info.type,
      token: token,
      endpoint: base,
    );
    final List<Storage> storages = await storage_request.listStorages(user);
    final users = UserService(database: _database);
    final storageService = StorageService(database: _database);
    final rules = RuleService(database: _database);
    await (await _database.database).transaction((txn) async {
      await users.add(user, transaction: txn);
      await storageService.save(storages, account: user, transaction: txn);
      await rules.ensureDefault(user.userId, transaction: txn);
    });
    UserService.changes.value++;
    StorageService.notifyChanged();
    return user;
  }
}
