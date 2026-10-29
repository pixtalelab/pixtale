import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pixtale_sync/l10n/localizations.dart';
import 'package:pixtale_sync/pages/app_page.dart';
import 'package:pixtale_sync/theme/app_theme.dart';
import 'package:pixtale_sync/l10n/locale.dart';
import 'package:pixtale_sync/services/window_service.dart';
import 'package:pixtale_sync/services/foreground_sync_service.dart';

// 应用入口，负责启动并配置根组件。

/// 启动应用。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ForegroundSyncService.initialize();
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await WindowService.instance.initialize();
  }
  await AppLocale.instance.load();
  runApp(const MyApp());
}

/// 应用根组件，配置主题、语言和底部导航入口。
class MyApp extends StatefulWidget {
  /// 创建应用根组件。
  const MyApp({super.key});

  /// 创建根组件状态。
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    AppLocale.instance.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    AppLocale.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() => setState(() {});

  /// 构建应用根界面。
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pixtale Sync',
      locale: AppLocale.instance.locale,
      localeResolutionCallback: (device, _) =>
          AppLocale.instance.locale ?? AppLocale.resolve(device: device),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(),
      home: const AppPage(),
    );
  }
}
