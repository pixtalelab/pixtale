import 'dart:async';

import 'package:flutter/material.dart';

// 应用共用的底部提示，不挤压页面内容或重复排队。

/// 在底部导航上方展示短暂提示。
class AppNotice {
  /// 当前显示的提示浮层。
  static OverlayEntry? _entry;

  /// 当前提示文字，用于合并重复提示。
  static String? _message;

  /// 自动关闭当前提示的计时器。
  static Timer? _timer;

  /// 显示提示，相同提示显示期间不重复添加。
  static void show(BuildContext context, String message) {
    if (_entry != null && _message == message) return;
    hide();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    _message = message;
    _entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: IgnorePointer(
          child: SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Material(
                    color: colors.inverseSurface,
                    elevation: 6,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text(
                        message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onInverseSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    _timer = Timer(const Duration(seconds: 4), hide);
  }

  /// 关闭当前提示并清理自动关闭计时器。
  static void hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
    _message = null;
  }
}
