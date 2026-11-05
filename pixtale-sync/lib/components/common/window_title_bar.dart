import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pixtale_sync/theme/app_theme.dart';
import 'package:window_manager/window_manager.dart';

// 桌面自定义标题栏。隐藏系统栏后，用这一条拖动窗口并放窗口按钮。

/// 覆盖在页面上方的窗口标题栏。没有固定、logo 和标题，只保留窗口按钮。
class WindowTitleBar extends StatefulWidget {
  /// 创建自定义标题栏。
  const WindowTitleBar({super.key});

  /// 标题栏高度，略小于默认 IconButton 的 48。
  static const double height = 36;

  @override
  State<WindowTitleBar> createState() => _WindowTitleBarState();
}

class _WindowTitleBarState extends State<WindowTitleBar> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    unawaited(_loadMaximized());
  }

  Future<void> _loadMaximized() async {
    try {
      final maximized = await windowManager.isMaximized();
      if (mounted) setState(() => _maximized = maximized);
    } catch (_) {}
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _maximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _maximized = false);
  }

  Future<void> _minimize() async {
    try {
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      } else {
        await windowManager.minimize();
      }
    } catch (_) {}
  }

  Future<void> _toggleMaximize() async {
    try {
      if (_maximized) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    } catch (_) {}
  }

  void _close() {
    try {
      windowManager.close();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: appTitleBarColor,
      child: SizedBox(
        height: WindowTitleBar.height,
        child: Row(
          children: [
            const Expanded(child: DragToMoveArea(child: SizedBox.expand())),
            _button(
              onPressed: _minimize,
              icon: const Icon(Icons.horizontal_rule),
            ),
            _button(
              onPressed: _toggleMaximize,
              icon: Icon(_maximized ? Icons.filter_none : Icons.crop_square),
            ),
            _button(onPressed: _close, icon: const Icon(Icons.close)),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  /// 和标题栏同高的 IconButton，图标也略小于页面默认的 24。
  Widget _button({required VoidCallback onPressed, required Widget icon}) {
    return IconButton(
      onPressed: onPressed,
      icon: icon,
      iconSize: 20,
      style: IconButton.styleFrom(
        minimumSize: const Size(WindowTitleBar.height, WindowTitleBar.height),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
      ),
    );
  }
}   
