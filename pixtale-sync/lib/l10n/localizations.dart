import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'localizations_en.dart';
import 'localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @tasks.
  ///
  /// In zh, this message translates to:
  /// **'任务'**
  String get tasks;

  /// No description provided for @logs.
  ///
  /// In zh, this message translates to:
  /// **'日志'**
  String get logs;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @chooseAlbums.
  ///
  /// In zh, this message translates to:
  /// **'选择相册'**
  String get chooseAlbums;

  /// No description provided for @done.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get done;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @noPhotoAlbums.
  ///
  /// In zh, this message translates to:
  /// **'没有找到照片相册'**
  String get noPhotoAlbums;

  /// No description provided for @unnamedAlbum.
  ///
  /// In zh, this message translates to:
  /// **'未命名相册'**
  String get unnamedAlbum;

  /// No description provided for @sortDefault.
  ///
  /// In zh, this message translates to:
  /// **'默认排序'**
  String get sortDefault;

  /// No description provided for @sortNameAsc.
  ///
  /// In zh, this message translates to:
  /// **'名称 A-Z'**
  String get sortNameAsc;

  /// No description provided for @sortNameDesc.
  ///
  /// In zh, this message translates to:
  /// **'名称 Z-A'**
  String get sortNameDesc;

  /// No description provided for @sortCountAsc.
  ///
  /// In zh, this message translates to:
  /// **'数量从少到多'**
  String get sortCountAsc;

  /// No description provided for @sortCountDesc.
  ///
  /// In zh, this message translates to:
  /// **'数量从多到少'**
  String get sortCountDesc;

  /// No description provided for @photoAccessRequired.
  ///
  /// In zh, this message translates to:
  /// **'需要照片访问权限'**
  String get photoAccessRequired;

  /// No description provided for @albumsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'读取相册失败，请稍后重试'**
  String get albumsLoadFailed;

  /// No description provided for @signInFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先登录'**
  String get signInFirst;

  /// No description provided for @stopSyncFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先停止同步'**
  String get stopSyncFirst;

  /// No description provided for @addAlbumsFailed.
  ///
  /// In zh, this message translates to:
  /// **'添加相册失败，请稍后重试'**
  String get addAlbumsFailed;

  /// No description provided for @addFolderFailed.
  ///
  /// In zh, this message translates to:
  /// **'添加文件夹失败，请稍后重试'**
  String get addFolderFailed;

  /// No description provided for @actionFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作失败，请稍后重试'**
  String get actionFailed;

  /// No description provided for @localStorage.
  ///
  /// In zh, this message translates to:
  /// **'本地存储'**
  String get localStorage;

  /// No description provided for @storageUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'存储失效'**
  String get storageUnavailable;

  /// No description provided for @unavailable.
  ///
  /// In zh, this message translates to:
  /// **'失效'**
  String get unavailable;

  /// No description provided for @syncComplete.
  ///
  /// In zh, this message translates to:
  /// **'同步完成'**
  String get syncComplete;

  /// No description provided for @photoCount.
  ///
  /// In zh, this message translates to:
  /// **'{completed} / {total} 张照片'**
  String photoCount(int completed, int total);

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @pinToTop.
  ///
  /// In zh, this message translates to:
  /// **'置顶'**
  String get pinToTop;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @addTask.
  ///
  /// In zh, this message translates to:
  /// **'添加任务'**
  String get addTask;

  /// No description provided for @editTask.
  ///
  /// In zh, this message translates to:
  /// **'编辑任务'**
  String get editTask;

  /// No description provided for @storage.
  ///
  /// In zh, this message translates to:
  /// **'存储'**
  String get storage;

  /// No description provided for @noStorageAvailable.
  ///
  /// In zh, this message translates to:
  /// **'暂无可用存储'**
  String get noStorageAvailable;

  /// No description provided for @chooseStorage.
  ///
  /// In zh, this message translates to:
  /// **'请选择存储'**
  String get chooseStorage;

  /// No description provided for @account.
  ///
  /// In zh, this message translates to:
  /// **'账户'**
  String get account;

  /// No description provided for @signedInAs.
  ///
  /// In zh, this message translates to:
  /// **'当前登录为 {username}'**
  String signedInAs(String username);

  /// No description provided for @signOut.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get signOut;

  /// No description provided for @preferences.
  ///
  /// In zh, this message translates to:
  /// **'功能设置'**
  String get preferences;

  /// No description provided for @notSignedIn.
  ///
  /// In zh, this message translates to:
  /// **'未登录'**
  String get notSignedIn;

  /// No description provided for @tapToSignIn.
  ///
  /// In zh, this message translates to:
  /// **'点击登录'**
  String get tapToSignIn;

  /// No description provided for @uploadConcurrency.
  ///
  /// In zh, this message translates to:
  /// **'并发上传'**
  String get uploadConcurrency;

  /// No description provided for @syncInterval.
  ///
  /// In zh, this message translates to:
  /// **'定时同步'**
  String get syncInterval;

  /// No description provided for @off.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get off;

  /// No description provided for @minutes.
  ///
  /// In zh, this message translates to:
  /// **'{count}分钟'**
  String minutes(int count);

  /// No description provided for @logRetention.
  ///
  /// In zh, this message translates to:
  /// **'日志保留'**
  String get logRetention;

  /// No description provided for @logRetentionValue.
  ///
  /// In zh, this message translates to:
  /// **'{count}条'**
  String logRetentionValue(int count);

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'系统语言'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get languageSystem;

  /// No description provided for @languageChinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @dataFolder.
  ///
  /// In zh, this message translates to:
  /// **'数据目录'**
  String get dataFolder;

  /// No description provided for @open.
  ///
  /// In zh, this message translates to:
  /// **'打开'**
  String get open;

  /// No description provided for @cannotOpenDataFolder.
  ///
  /// In zh, this message translates to:
  /// **'无法打开数据存放目录'**
  String get cannotOpenDataFolder;

  /// No description provided for @value.
  ///
  /// In zh, this message translates to:
  /// **'数值'**
  String get value;

  /// No description provided for @enterInteger.
  ///
  /// In zh, this message translates to:
  /// **'请输入整数'**
  String get enterInteger;

  /// No description provided for @enterMinValue.
  ///
  /// In zh, this message translates to:
  /// **'请输入不小于 {min} 的数值'**
  String enterMinValue(int min);

  /// No description provided for @enterMaxValue.
  ///
  /// In zh, this message translates to:
  /// **'请输入不大于 {max} 的数值'**
  String enterMaxValue(int max);

  /// No description provided for @invalidEndpoint.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的端点地址'**
  String get invalidEndpoint;

  /// No description provided for @signIn.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get signIn;

  /// No description provided for @endpoint.
  ///
  /// In zh, this message translates to:
  /// **'端点'**
  String get endpoint;

  /// No description provided for @enterEndpoint.
  ///
  /// In zh, this message translates to:
  /// **'请输入端点'**
  String get enterEndpoint;

  /// No description provided for @username.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get username;

  /// No description provided for @enterUsername.
  ///
  /// In zh, this message translates to:
  /// **'请输入用户名'**
  String get enterUsername;

  /// No description provided for @password.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// No description provided for @enterPassword.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get enterPassword;

  /// No description provided for @clearLogsFailed.
  ///
  /// In zh, this message translates to:
  /// **'清空日志失败，请稍后重试'**
  String get clearLogsFailed;

  /// No description provided for @loadLogsFailed.
  ///
  /// In zh, this message translates to:
  /// **'读取日志失败'**
  String get loadLogsFailed;

  /// No description provided for @logFilterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get logFilterAll;

  /// No description provided for @logFilterSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get logFilterSuccess;

  /// No description provided for @logFilterFailure.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get logFilterFailure;

  /// No description provided for @logStatusSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get logStatusSuccess;

  /// No description provided for @logStatusFailure.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get logStatusFailure;

  /// No description provided for @notificationPermissionRequired.
  ///
  /// In zh, this message translates to:
  /// **'需要通知权限才能后台同步'**
  String get notificationPermissionRequired;

  /// No description provided for @logAlbumAll.
  ///
  /// In zh, this message translates to:
  /// **'全部相册'**
  String get logAlbumAll;

  /// No description provided for @logEventStartSync.
  ///
  /// In zh, this message translates to:
  /// **'开始同步'**
  String get logEventStartSync;

  /// No description provided for @logEventOpenSync.
  ///
  /// In zh, this message translates to:
  /// **'开启同步'**
  String get logEventOpenSync;

  /// No description provided for @logEventReadStorage.
  ///
  /// In zh, this message translates to:
  /// **'读取存储'**
  String get logEventReadStorage;

  /// No description provided for @logEventReadAlbum.
  ///
  /// In zh, this message translates to:
  /// **'读取相册'**
  String get logEventReadAlbum;

  /// No description provided for @logEventRemoteCheck.
  ///
  /// In zh, this message translates to:
  /// **'远程检测'**
  String get logEventRemoteCheck;

  /// No description provided for @logEventGetRemoteAlbum.
  ///
  /// In zh, this message translates to:
  /// **'获取远程相册'**
  String get logEventGetRemoteAlbum;

  /// No description provided for @logEventReadSyncSettings.
  ///
  /// In zh, this message translates to:
  /// **'读取同步设置'**
  String get logEventReadSyncSettings;

  /// No description provided for @logEventUpdateCount.
  ///
  /// In zh, this message translates to:
  /// **'更新同步数量'**
  String get logEventUpdateCount;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
