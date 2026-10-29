import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// 应用主题。

/// 构建应用主题。背景用白色，强调色用科技黑，标题和正文保持原来的颜色。
ThemeData buildAppTheme() {
  const background = Color(0xFFFFFFFF);
  const ink = Color(0xFF111111);
  final original = ColorScheme.fromSeed(
    seedColor: const Color(0xFF247A78),
    surface: const Color(0xFFF8FAF9),
  );
  final colorScheme = original.copyWith(primary: ink, surface: background);
  return ThemeData(
    // Windows 先用系统界面字体。Win11 有 Segoe UI Variable，没有时退回 Segoe UI。
    // 缺字再按简体、繁体、日文、韩文补，最后才是普通微软雅黑。
    fontFamily: defaultTargetPlatform == TargetPlatform.windows
        ? 'Segoe UI Variable'
        : null,
    fontFamilyFallback: defaultTargetPlatform == TargetPlatform.windows
        ? const [
            'Segoe UI',
            'Microsoft YaHei UI',
            'Microsoft JhengHei UI',
            'Yu Gothic UI',
            'Malgun Gothic',
            'Microsoft YaHei',
          ]
        : null,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: background,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: background,
      indicatorColor: Color(0xFFE4E4E7),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: background),
    useMaterial3: true,
  );
}
