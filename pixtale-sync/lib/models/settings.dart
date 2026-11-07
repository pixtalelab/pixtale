/// 应用同步和日志设置。
class Settings {
  const Settings({
    required this.taskInterval,
    required this.logMaxCount,
    required this.taskStatus,
    required this.uploadConcurrency,
    this.fileLimitMb = 300,
    this.lastSyncAt,
    this.locale = '',
  });

  final int taskInterval;
  final int logMaxCount;
  final int taskStatus;
  final int uploadConcurrency;

  /// 单文件上传大小上限，单位 MB。
  final int fileLimitMb;
  final String? lastSyncAt;

  /// 界面语言。空字符串表示跟随系统。
  final String locale;

  Settings copyWith({
    int? taskInterval,
    int? logMaxCount,
    int? taskStatus,
    int? uploadConcurrency,
    int? fileLimitMb,
    String? lastSyncAt,
    String? locale,
  }) {
    return Settings(
      taskInterval: taskInterval ?? this.taskInterval,
      logMaxCount: logMaxCount ?? this.logMaxCount,
      taskStatus: taskStatus ?? this.taskStatus,
      uploadConcurrency: uploadConcurrency ?? this.uploadConcurrency,
      fileLimitMb: fileLimitMb ?? this.fileLimitMb,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      locale: locale ?? this.locale,
    );
  }
}
