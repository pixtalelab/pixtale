// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get tasks => '任务';

  @override
  String get logs => '日志';

  @override
  String get settings => '设置';

  @override
  String get chooseAlbums => '选择相册';

  @override
  String get done => '完成';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get noPhotoAlbums => '没有找到照片相册';

  @override
  String get unnamedAlbum => '未命名相册';

  @override
  String get sortDefault => '默认排序';

  @override
  String get sortNameAsc => '名称 A-Z';

  @override
  String get sortNameDesc => '名称 Z-A';

  @override
  String get sortCountAsc => '数量从少到多';

  @override
  String get sortCountDesc => '数量从多到少';

  @override
  String get photoAccessRequired => '需要照片访问权限';

  @override
  String get albumsLoadFailed => '读取相册失败，请稍后重试';

  @override
  String get signInFirst => '请先登录';

  @override
  String get stopSyncFirst => '请先停止同步';

  @override
  String get addAlbumsFailed => '添加相册失败，请稍后重试';

  @override
  String get addFolderFailed => '添加文件夹失败，请稍后重试';

  @override
  String get actionFailed => '操作失败，请稍后重试';

  @override
  String get localStorage => '本地存储';

  @override
  String get storageUnavailable => '存储失效';

  @override
  String get unavailable => '失效';

  @override
  String get syncComplete => '同步完成';

  @override
  String photoCount(int completed, int total) {
    return '$completed / $total 张照片';
  }

  @override
  String get edit => '编辑';

  @override
  String get pinToTop => '置顶';

  @override
  String get delete => '删除';

  @override
  String get addTask => '添加任务';

  @override
  String get editTask => '编辑任务';

  @override
  String get storage => '存储';

  @override
  String get noStorageAvailable => '暂无可用存储';

  @override
  String get chooseStorage => '请选择存储';

  @override
  String get account => '账户';

  @override
  String signedInAs(String username) {
    return '当前登录为 $username';
  }

  @override
  String get signOut => '退出登录';

  @override
  String get preferences => '功能设置';

  @override
  String get notSignedIn => '未登录';

  @override
  String get tapToSignIn => '点击登录';

  @override
  String get uploadConcurrency => '并发上传';

  @override
  String get syncInterval => '定时同步';

  @override
  String get off => '关闭';

  @override
  String minutes(int count) {
    return '$count分钟';
  }

  @override
  String get logRetention => '日志保留';

  @override
  String logRetentionValue(int count) {
    return '$count条';
  }

  @override
  String get language => '系统语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get dataFolder => '数据目录';

  @override
  String get open => '打开';

  @override
  String get cannotOpenDataFolder => '无法打开数据存放目录';

  @override
  String get value => '数值';

  @override
  String get enterInteger => '请输入整数';

  @override
  String enterMinValue(int min) {
    return '请输入不小于 $min 的数值';
  }

  @override
  String enterMaxValue(int max) {
    return '请输入不大于 $max 的数值';
  }

  @override
  String get invalidEndpoint => '请输入有效的端点地址';

  @override
  String get signIn => '登录';

  @override
  String get endpoint => '端点';

  @override
  String get enterEndpoint => '请输入端点';

  @override
  String get username => '用户名';

  @override
  String get enterUsername => '请输入用户名';

  @override
  String get password => '密码';

  @override
  String get enterPassword => '请输入密码';

  @override
  String get clearLogsFailed => '清空日志失败，请稍后重试';

  @override
  String get loadLogsFailed => '读取日志失败';

  @override
  String get logFilterAll => '全部';

  @override
  String get logFilterSuccess => '成功';

  @override
  String get logFilterFailure => '失败';

  @override
  String get logStatusSuccess => '成功';

  @override
  String get logStatusFailure => '失败';

  @override
  String get notificationPermissionRequired => '需要通知权限才能后台同步';

  @override
  String get logAlbumAll => '全部相册';

  @override
  String get logEventStartSync => '开始同步';

  @override
  String get logEventOpenSync => '开启同步';

  @override
  String get logEventReadStorage => '读取存储';

  @override
  String get logEventReadAlbum => '读取相册';

  @override
  String get logEventRemoteCheck => '远程检测';

  @override
  String get logEventGetRemoteAlbum => '获取远程相册';

  @override
  String get logEventReadSyncSettings => '读取同步设置';

  @override
  String get logEventUpdateCount => '更新同步数量';
}
