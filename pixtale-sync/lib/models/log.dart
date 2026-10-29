// 一次同步事件的持久化结果。

/// 日志结果。数据库只保存数字，界面再换成中文。
abstract final class LogStatus {
  /// 失败。
  static const failure = 0;

  /// 成功。
  static const success = 1;

  /// 把状态数字显示为中文。未知数字按失败展示。
  static String label(int status) => status == success ? 'Success' : 'Failed';
}

/// 日志条目，不保存照片大小和上传进度。
class Log {
  /// 创建包含相册、事件和结果的日志记录。
  const Log({
    required this.id,
    required this.albumName,
    required this.event,
    required this.status,
    required this.message,
    required this.createdAt,
  });

  final int id;
  final String albumName;
  final String event;

  /// 0 失败，1 成功。
  final int status;
  final String message;
  final DateTime createdAt;
}
