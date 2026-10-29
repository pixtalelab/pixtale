import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:pixtale_sync/l10n/localizations.dart';
import 'package:pixtale_sync/services/settings_service.dart';

// 读取并应用用户选择的界面语言，空值跟随系统。

/// 向根组件发布当前语言。
class AppLocale extends ChangeNotifier {
  /// 应用使用的语言控制器。
  static final instance = AppLocale();

  /// 用户指定的语言。空表示跟随系统。
  Locale? locale;

  /// 从设置表恢复语言，数据库未就绪时保持跟随系统。
  Future<void> load() async {
    try {
      final settings = await SettingsService.instance.get();
      _apply(settings.locale, notify: false);
    } catch (_) {
      locale = null;
    }
  }

  /// 保存并立即切换界面语言。
  Future<void> setCode(String code) async {
    await SettingsService.instance.updateLocale(code);
    _apply(code);
  }

  void _apply(String code, {bool notify = true}) {
    final next = switch (code) {
      'zh' => const Locale('zh'),
      'en' => const Locale('en'),
      _ => null,
    };
    if (locale == next) return;
    locale = next;
    if (notify) notifyListeners();
  }

  /// 与界面相同：手动中英优先；跟随系统时只有中文用中文，其余用英语。
  static Locale resolve({String? saved, Locale? device}) {
    if (saved == 'zh') return const Locale('zh');
    if (saved == 'en') return const Locale('en');
    final code = (device ?? PlatformDispatcher.instance.locale).languageCode;
    return code == 'zh' ? const Locale('zh') : const Locale('en');
  }

  /// 按 [resolve] 取出当前语言的文案。
  static AppLocalizations strings({String? saved, Locale? device}) {
    return lookupAppLocalizations(resolve(saved: saved, device: device));
  }
}
