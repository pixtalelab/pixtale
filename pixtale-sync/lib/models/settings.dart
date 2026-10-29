/// 应用同步和日志设置。
class Settings {
  const Settings({
    required this.taskInterval,
    required this.logMaxCount,
    required this.taskStatus,
    required this.uploadConcurrency,
    this.lastSyncAt,
    this.locale = '',
  });

  final int taskInterval;
  final int logMaxCount;
  final int taskStatus;
  final int uploadConcurrency;
  final String? lastSyncAt;

  /// 界面语言。空字符串表示跟随系统。
  final String locale;

  Settings copyWith({
    int? taskInterval,
    int? logMaxCount,
    int? taskStatus,
    int? uploadConcurrency,
    String? lastSyncAt,
    String? locale,
  }) {
    return Settings(
      taskInterval: taskInterval ?? this.taskInterval,
      logMaxCount: logMaxCount ?? this.logMaxCount,
      taskStatus: taskStatus ?? this.taskStatus,
      uploadConcurrency: uploadConcurrency ?? this.uploadConcurrency,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      locale: locale ?? this.locale,
    );
  }
}
