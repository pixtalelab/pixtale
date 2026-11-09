import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pixtale_sync/l10n/localizations.dart';
import 'package:pixtale_sync/components/common/window_title_bar.dart';
import 'package:pixtale_sync/pages/log_page.dart';
import 'package:pixtale_sync/pages/login_page.dart';
import 'package:pixtale_sync/pages/settings_page.dart';
import 'package:pixtale_sync/pages/task_page.dart';
import 'package:pixtale_sync/pages/template_page.dart';
import 'package:pixtale_sync/providers/sync_provider.dart';
import 'package:pixtale_sync/request/request.dart';
import 'package:pixtale_sync/services/foreground_sync_service.dart';
import 'package:pixtale_sync/services/auth_service.dart';
import 'package:pixtale_sync/models/user.dart';
import 'package:pixtale_sync/services/task_service.dart';
import 'package:pixtale_sync/services/rule_service.dart';
import 'package:pixtale_sync/services/storage_service.dart';
import 'package:pixtale_sync/services/user_service.dart';
import 'package:pixtale_sync/services/window_service.dart';
import 'package:pixtale_sync/theme/app_theme.dart';

// 应用主页面。窄屏竖向时导航贴底，宽屏或横屏时导航在左侧。

/// 任务、规则、日志和设置的导航容器。
class AppPage extends StatefulWidget {
  /// 创建主页面，可注入任务服务进行测试。
  const AppPage({
    super.key,
    this.taskService,
    this.storageService,
    this.ruleService,
    this.userService,
    this.authService,
  });

  /// 任务和规则页面使用的本地规则服务。
  final RuleService? ruleService;

  /// 任务页面使用的持久化服务。
  final TaskService? taskService;

  /// 规则页面使用的存储列表服务。
  final StorageService? storageService;

  /// 统一读取和清除当前登录会话。
  final UserService? userService;

  /// 登录页面使用的账户初始化服务。
  final AuthService? authService;

  /// 创建导航状态。
  @override
  State<AppPage> createState() => _AppPageState();
}

/// 管理导航索引，并保留各页面的状态。
class _AppPageState extends State<AppPage> {
  // 状态与依赖

  /// 桌面窗口最窄就是这个宽度，所以这里起改用左侧导航。
  static const _sideMenuMinWidth = 600.0;

  /// 当前选中的导航项。
  int _index = 0;

  /// 启动时先读取会话，避免显示未登录账户的功能页面。
  User? _user;
  bool _accountLoaded = false;
  int _accountVersion = 0;
  late final _users = widget.userService ?? UserService.instance;

  /// 任务页和设置页共用，改并发时可以停掉正在跑的同步再启动。
  late final SyncProvider _sync = SyncProvider(
    service: ForegroundSyncService.create(
      tasks: widget.taskService ?? TaskService.instance,
    ),
  );

  /// 保持同一次回调，页面释放时只清掉自己注册的处理。
  late final Future<void> Function() _expiredSession = _logoutExpiredSession;

  /// 注册会话监听，并在启动时读取本地用户。
  @override
  void initState() {
    super.initState();
    onUnauthorized = _expiredSession;
    UserService.changes.addListener(_onUserChanged);
    _loadUser();
    if (WindowService.showsTitleBar) WindowService.instance.bindSync(_sync);
  }

  /// 登录失效后清除会话并停止同步，由账户监听切换到登录页。
  Future<void> _logoutExpiredSession() async {
    await _users.logout();
    await _sync.stop();
  }

  /// 登录、退出或后台失效时重新读取当前账户。
  void _onUserChanged() => unawaited(_loadUser());

  /// 无法读取用户时显示登录页，退出时关闭仍打开的弹窗及相册页面。
  Future<void> _loadUser() async {
    final version = ++_accountVersion;
    User? user;
    try {
      user = await _users.get();
    } catch (_) {
      // 本地没有可用会话时交由登录页重新登录。
    }
    if (!mounted || version != _accountVersion) return;
    final changed =
        user?.userId != _user?.userId ||
        user?.token != _user?.token ||
        user?.endpoint != _user?.endpoint;
    if (changed || user == null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      if (_accountLoaded || user == null) unawaited(_sync.stop());
      _sync.progress.clear();
    }
    setState(() {
      if (changed || user == null) _index = 0;
      _user = user;
      _accountLoaded = true;
    });
  }

  // 事件处理

  /// 切换导航页面。
  void _selectPage(int index) => setState(() => _index = index);

  /// 释放共用的同步状态。
  @override
  void dispose() {
    if (identical(onUnauthorized, _expiredSession)) onUnauthorized = null;
    UserService.changes.removeListener(_onUserChanged);
    WindowService.instance.unbindSync(_sync);
    _sync.dispose();
    super.dispose();
  }

  // 页面渲染

  /// 页面叠在一起，切页时保留任务列表状态。
  Widget _pages() {
    return IndexedStack(
      index: _index,
      children: [
        TaskPage(
          taskService: widget.taskService,
          ruleService: widget.ruleService,
          sync: _sync,
        ),
        TemplatePage(
          service: widget.ruleService,
          storageService: widget.storageService,
        ),
        LogPage(active: _index == 2),
        SettingsPage(sync: _sync, userService: _users),
      ],
    );
  }

  /// 竖屏窄窗口把导航放在底部，横屏或够宽时放在左侧。桌面再叠一条自定义标题栏。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final page = !_accountLoaded
        ? const Scaffold()
        : _user == null
        ? LoginPage(authService: widget.authService)
        : OrientationBuilder(
            builder: (context, orientation) {
              final width = MediaQuery.sizeOf(context).width;
              final side =
                  orientation == Orientation.landscape ||
                  width >= _sideMenuMinWidth;
              return side
                  ? _sideMenu(context, l10n)
                  : _bottomMenu(context, l10n);
            },
          );
    if (!WindowService.showsTitleBar) return page;
    return ColoredBox(
      color: appSideMenuColor,
      child: Column(
        children: [
          const WindowTitleBar(),
          Expanded(child: page),
        ],
      ),
    );
  }

  /// 移动端竖屏的底部导航。
  Widget _bottomMenu(BuildContext context, AppLocalizations l10n) {
    return Scaffold(
      body: _pages(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _selectPage,
        destinations: [
          NavigationDestination(
            tooltip: '',
            icon: const Icon(Icons.assignment_turned_in_outlined),
            selectedIcon: const Icon(Icons.assignment_turned_in),
            label: l10n.tasks,
          ),
          NavigationDestination(
            tooltip: '',
            icon: const Icon(Icons.signpost_outlined),
            selectedIcon: const Icon(Icons.signpost),
            label: l10n.templates,
          ),
          NavigationDestination(
            tooltip: '',
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: l10n.logs,
          ),
          NavigationDestination(
            tooltip: '',
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.settings,
          ),
        ],
      ),
    );
  }

  /// 宽屏和横屏的左侧导航。文字始终显示，入口排在 logo 下面。
  Widget _sideMenu(BuildContext context, AppLocalizations l10n) {
    final labelStyle = Theme.of(context).textTheme.labelLarge;
    return Scaffold(
      backgroundColor: appSideMenuColor,
      body: Row(
        children: [
          SafeArea(
            right: false,
            child: NavigationRail(
              backgroundColor: appSideMenuColor,
              indicatorColor: const Color(0xFFE4E4E7),
              groupAlignment: -1,
              selectedLabelTextStyle: labelStyle,
              unselectedLabelTextStyle: labelStyle,
              leading: const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 16),
                child: Image(
                  image: AssetImage('assets/logo.png'),
                  width: 42,
                  height: 42,
                ),
              ),
              labelType: NavigationRailLabelType.all,
              selectedIndex: _index,
              onDestinationSelected: _selectPage,
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.assignment_turned_in_outlined),
                  selectedIcon: const Icon(Icons.assignment_turned_in),
                  label: Text(l10n.tasks),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.signpost_outlined),
                  selectedIcon: const Icon(Icons.signpost),
                  label: Text(l10n.templates),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.receipt_long_outlined),
                  selectedIcon: const Icon(Icons.receipt_long),
                  label: Text(l10n.logs),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: Text(l10n.settings),
                ),
              ],
            ),
          ),
          Expanded(child: _pages()),
        ],
      ),
    );
  }
}
