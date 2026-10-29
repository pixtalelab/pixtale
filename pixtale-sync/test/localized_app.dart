import 'package:flutter/material.dart';
import 'package:pixtale_sync/l10n/localizations.dart';

// 测试里固定中文，现有 find.text 断言不用跟着系统语言变。

/// 带中文本地化的测试应用。
Widget localizedApp({
  required Widget home,
  ThemeData? theme,
  TransitionBuilder? builder,
}) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme,
    builder: builder,
    home: home,
  );
}
