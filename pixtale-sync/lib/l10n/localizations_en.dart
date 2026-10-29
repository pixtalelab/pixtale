// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tasks => 'Tasks';

  @override
  String get logs => 'Logs';

  @override
  String get settings => 'Settings';

  @override
  String get chooseAlbums => 'Choose albums';

  @override
  String get done => 'Done';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get noPhotoAlbums => 'No photo albums found';

  @override
  String get unnamedAlbum => 'Untitled album';

  @override
  String get sortDefault => 'Default order';

  @override
  String get sortNameAsc => 'Name A-Z';

  @override
  String get sortNameDesc => 'Name Z-A';

  @override
  String get sortCountAsc => 'Fewest photos';

  @override
  String get sortCountDesc => 'Most photos';

  @override
  String get photoAccessRequired => 'Photo access is required';

  @override
  String get albumsLoadFailed => 'Couldn\'t load albums. Try again later.';

  @override
  String get signInFirst => 'Sign in first';

  @override
  String get stopSyncFirst => 'Stop syncing first';

  @override
  String get addAlbumsFailed => 'Couldn\'t add albums. Try again later.';

  @override
  String get addFolderFailed => 'Couldn\'t add the folder. Try again later.';

  @override
  String get actionFailed => 'Something went wrong. Try again later.';

  @override
  String get localStorage => 'Local storage';

  @override
  String get storageUnavailable => 'Storage unavailable';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get syncComplete => 'Synced';

  @override
  String photoCount(int completed, int total) {
    return '$completed / $total photos';
  }

  @override
  String get edit => 'Edit';

  @override
  String get pinToTop => 'Pin to top';

  @override
  String get delete => 'Delete';

  @override
  String get addTask => 'Add task';

  @override
  String get editTask => 'Edit task';

  @override
  String get storage => 'Storage';

  @override
  String get noStorageAvailable => 'No storage available';

  @override
  String get chooseStorage => 'Choose storage';

  @override
  String get account => 'Account';

  @override
  String signedInAs(String username) {
    return 'Signed in as $username';
  }

  @override
  String get signOut => 'Sign out';

  @override
  String get preferences => 'Preferences';

  @override
  String get notSignedIn => 'Not signed in';

  @override
  String get tapToSignIn => 'Tap to sign in';

  @override
  String get uploadConcurrency => 'Upload concurrency';

  @override
  String get syncInterval => 'Sync interval';

  @override
  String get off => 'Off';

  @override
  String minutes(int count) {
    return '$count min';
  }

  @override
  String get logRetention => 'Log history';

  @override
  String logRetentionValue(int count) {
    return '$count';
  }

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get dataFolder => 'Data folder';

  @override
  String get open => 'Open';

  @override
  String get cannotOpenDataFolder => 'Couldn\'t open the data folder';

  @override
  String get value => 'Value';

  @override
  String get enterInteger => 'Enter a whole number';

  @override
  String enterMinValue(int min) {
    return 'Enter a number of at least $min';
  }

  @override
  String enterMaxValue(int max) {
    return 'Enter a number of at most $max';
  }

  @override
  String get invalidEndpoint => 'Enter a valid server address';

  @override
  String get signIn => 'Sign in';

  @override
  String get endpoint => 'Server';

  @override
  String get enterEndpoint => 'Enter a server address';

  @override
  String get username => 'Username';

  @override
  String get enterUsername => 'Enter a username';

  @override
  String get password => 'Password';

  @override
  String get enterPassword => 'Enter a password';

  @override
  String get clearLogsFailed => 'Couldn\'t clear logs. Try again later.';

  @override
  String get loadLogsFailed => 'Couldn\'t load logs';

  @override
  String get logFilterAll => 'All';

  @override
  String get logFilterSuccess => 'Success';

  @override
  String get logFilterFailure => 'Failed';

  @override
  String get logStatusSuccess => 'Success';

  @override
  String get logStatusFailure => 'Failed';

  @override
  String get notificationPermissionRequired =>
      'Notifications are required for background sync';

  @override
  String get logAlbumAll => 'All albums';

  @override
  String get logEventStartSync => 'Sync started';

  @override
  String get logEventOpenSync => 'Start sync';

  @override
  String get logEventReadStorage => 'Read storage';

  @override
  String get logEventReadAlbum => 'Read album';

  @override
  String get logEventRemoteCheck => 'Remote check';

  @override
  String get logEventGetRemoteAlbum => 'Get remote album';

  @override
  String get logEventReadSyncSettings => 'Read sync settings';

  @override
  String get logEventUpdateCount => 'Update sync count';
}
