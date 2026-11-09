import 'package:pixtale_sync/db/db.dart';
import 'package:pixtale_sync/models/settings.dart';

// 应用设置与同步运行状态的持久化。

/// 应用设置的持久化服务。
class SettingsService {
  /// 创建可指定数据库的设置服务。
  SettingsService({Db? database}) : _database = database ?? Db();

  static final SettingsService instance = SettingsService();
  final Db _database;

  /// 读取应用唯一的设置记录。
  Future<Settings> get() async {
    final rows = await (await _database.database).query(
      'settings',
      where: 'id = 1',
      limit: 1,
    );
    final row = rows.first;
    return Settings(
      taskInterval: row['task_interval'] as int,
      logMaxCount: row['log_max_count'] as int,
      taskStatus: row['task_status'] as int,
      uploadConcurrency: row['upload_concurrency'] as int,
      lastSyncAt: row['last_sync_at'] as String?,
      locale: row['locale'] as String? ?? '',
    );
  }

  /// 保存同步间隔，零表示仅执行一轮。
  Future<void> updateTaskInterval(int value) => _update('task_interval', value);

  /// 保存日志保留数量，仅允许 10 至 1000 条。
  Future<void> updateLogMaxCount(int value) async {
    RangeError.checkValueInInterval(value, 10, 1000, 'logMaxCount');
    await _update('log_max_count', value);
  }

  /// 保存每页允许同时上传的照片数。
  Future<void> updateUploadConcurrency(int value) =>
      _update('upload_concurrency', value);

  /// 保存同步开启或关闭状态。
  Future<void> updateTaskStatus(int value) => _update('task_status', value);

  /// 保存本轮同步完成时间。
  Future<void> updateLastSyncAt() =>
      _update('last_sync_at', DateTime.now().toUtc().toIso8601String());

  /// 保存界面语言。空字符串表示跟随系统。
  Future<void> updateLocale(String value) => _update('locale', value);

  /// 更新指定设置字段。
  Future<void> _update(String column, Object value) async {
    await (await _database.database).update('settings', {
      column: value,
    }, where: 'id = 1');
  }
}
