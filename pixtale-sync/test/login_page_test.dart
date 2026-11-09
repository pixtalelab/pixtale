import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pixtale_sync/db/db.dart';
import 'package:pixtale_sync/models/user.dart';
import 'package:pixtale_sync/pages/app_page.dart';
import 'package:pixtale_sync/pages/login_page.dart';
import 'package:pixtale_sync/pages/task_page.dart';
import 'package:pixtale_sync/pages/template_page.dart';
import 'package:pixtale_sync/request/request.dart';
import 'package:pixtale_sync/services/auth_service.dart';
import 'package:pixtale_sync/services/rule_service.dart';
import 'package:pixtale_sync/services/storage_service.dart';
import 'package:pixtale_sync/services/task_service.dart';
import 'package:pixtale_sync/services/user_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'localized_app.dart';

// 验证独立登录页面及启动、退出、鉴权失效时的统一页面切换。

/// 执行登录界面与会话入口测试。
void main() {
  sqfliteFfiInit();
  late Db database;
  late UserService users;
  late TestAuth auth;

  setUp(() {
    database = Db(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    users = UserService(database: database);
    auth = TestAuth(database, users);
  });
  tearDown(() => database.close());

  /// 等待后台数据库查询及页面切换完成。
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(() async {
      await (await database.database).rawQuery('SELECT 1');
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pump();
    await tester.runAsync(() async {
      await (await database.database).rawQuery('SELECT 1');
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
  }

  /// 启动具有真实本地账户查询的应用入口。
  Future<void> show(WidgetTester tester, {UserService? userService}) async {
    await tester.runAsync(() async {
      await database.database;
    });
    await tester.pumpWidget(
      localizedApp(
        home: AppPage(
          userService: userService ?? users,
          authService: auth,
          taskService: TaskService(database: database),
          ruleService: RuleService(database: database),
          storageService: StorageService(database: database),
        ),
      ),
    );
    await settle(tester);
  }

  /// 填写一组可用的登录表单数据。
  Future<void> fill(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'https://example.test/');
    await tester.enterText(fields.at(1), 'tester');
    await tester.enterText(fields.at(2), 'secret');
  }

  testWidgets('启动没有用户时直接显示登录页，不加载功能页面', (tester) async {
    await show(tester);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(TaskPage), findsNothing);
    expect(find.byType(TemplatePage), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(auth.calls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('无法读取本地用户时也显示登录页', (tester) async {
    await show(tester, userService: BrokenUsers(database));
    expect(find.byType(LoginPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('登录校验、失败提示及窄屏键盘布局正常', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 450);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await show(tester);
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();
    expect(find.text('请输入端点'), findsOneWidget);
    expect(find.text('请输入用户名'), findsOneWidget);
    expect(find.text('请输入密码'), findsOneWidget);
    expect(auth.calls, 0);
    await fill(tester);
    await tester.enterText(find.byType(TextFormField).first, 'not-a-url');
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('请输入有效的端点地址'), findsOneWidget);
    expect(auth.calls, 0);
    await tester.enterText(
      find.byType(TextFormField).first,
      'https://example.test',
    );
    auth.failure = const ApiException('密码错误');
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await settle(tester);
    expect(find.text('密码错误'), findsOneWidget);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('登录成功进入任务页，设置退出清除所有会话并回到登录页', (tester) async {
    await show(tester);
    await fill(tester);
    await tester.tap(find.byType(FilledButton));
    await settle(tester);
    expect(auth.calls, 1);
    expect(auth.endpoint, 'https://example.test');
    expect(find.byType(LoginPage), findsNothing);
    expect(find.byType(TaskPage), findsOneWidget);
    await tester.runAsync(() async {
      await users.add(_user('other'));
    });
    await settle(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('tester'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AlertDialog, '账户'), findsOneWidget);
    await tester.tap(find.text('退出登录'));
    await settle(tester);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(await tester.runAsync(users.get), isNull);
    await fill(tester);
    await tester.tap(find.byType(FilledButton));
    await settle(tester);
    expect(find.byType(TaskPage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('启动已有用户直接进入主界面，403 清除会话并关闭弹窗和子页面', (tester) async {
    await tester.runAsync(() => users.add(_user('user')));
    await show(tester);
    expect(find.byType(TaskPage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
    final navigator = Navigator.of(tester.element(find.byType(TaskPage)));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('相册选择测试')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      showDialog<void>(
        context: tester.element(find.text('相册选择测试')),
        builder: (_) => const AlertDialog(title: Text('打开的弹窗')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'code': 403, 'message': 'Session expired'}),
          403,
        ),
      );
      try {
        await expectLater(
          post<dynamic>(
            '/check',
            baseUrl: 'https://example.test',
            client: client,
          ),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 403),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
      } finally {
        client.close();
      }
    });
    await settle(tester);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('相册选择测试'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(TaskPage, skipOffstage: false), findsNothing);
    expect(await tester.runAsync(users.get), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

/// 生成测试中保存的有效登录账户。
User _user(String id) => User(
  userId: id,
  username: 'tester',
  avatar: '',
  type: 0,
  token: 'token',
  endpoint: 'https://example.test',
);

/// 保存账户并发送真实通知，隔离表单测试与网络协议。
class TestAuth extends AuthService {
  /// 注入同一数据库与账户服务。
  TestAuth(Db database, this.users) : super(database: database);
  final UserService users;
  int calls = 0;
  String? endpoint;
  Object? failure;

  /// 记录表单输入并模拟登录结果。
  @override
  Future<User> login({
    required String endpoint,
    required String username,
    required String password,
  }) async {
    calls++;
    this.endpoint = endpoint;
    expect(username, 'tester');
    expect(password, 'secret');
    if (failure != null) throw failure!;
    final user = _user('user');
    await users.add(user);
    return user;
  }
}

/// 模拟启动时本地账户查询失败。
class BrokenUsers extends UserService {
  /// 复用测试连接，避免平台数据库初始化。
  BrokenUsers(Db database) : super(database: database);

  /// 抛出读取错误，应用应回到可登录状态。
  @override
  Future<User?> get() async => throw StateError('Cannot read user');
}
