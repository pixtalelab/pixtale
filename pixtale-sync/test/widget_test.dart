import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pixtale_sync/components/common/app_notice.dart';
import 'localized_app.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pixtale_sync/pages/app_page.dart';
import 'package:pixtale_sync/pages/task_page.dart';
import 'package:pixtale_sync/services/task_service.dart';
import 'package:pixtale_sync/services/storage_service.dart';
import 'package:pixtale_sync/services/sync_service.dart';
import 'package:pixtale_sync/db/db.dart';
import 'package:pixtale_sync/models/storage.dart';
import 'package:pixtale_sync/models/task.dart';
import 'package:pixtale_sync/models/sync.dart';
import 'package:pixtale_sync/models/user.dart';
import 'package:pixtale_sync/services/user_service.dart';

// 任务页与底部导航测试。

/// 执行页面交互测试。
void main() {
  sqfliteFfiInit();

  late Db database;

  setUp(() {
    database = Db(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(database.close);
  });

  testWidgets('添加弹窗先用旧存储，刷新后选择相册并保存所选存储', (tester) async {
    final tasks = DialogTaskService(database);
    final storages = DialogStorageService(database);
    final sync = WaitingSyncService(tasks);
    const channel = MethodChannel('com.fluttercandies/photo_manager');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => switch (call.method) {
        'requestPermissionExtend' || 'getPermissionState' => 3,
        'getAssetPathList' || 'fetchPathProperties' => {
          'data': [
            {'id': 'a', 'name': '旅行', 'assetCount': 123, 'isAll': false},
          ],
        },
        'getAssetCountFromPath' => 123,
        'getAssetListRange' => {'data': []},
        _ => null,
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.runAsync(() async {
      await UserService(database: database).add(_user);
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    await tester.pumpWidget(
      localizedApp(
        home: TaskPage(
          taskService: tasks,
          storageService: storages,
          syncService: sync,
        ),
      ),
    );
    await tester.runAsync(() async {
      await (await database.database).rawQuery('SELECT 1');
    });
    await tester.pumpAndSettle();
    expect(storages.refreshes, 1);
    expect(find.byIcon(Icons.add), findsOneWidget);

    storages.pending = Completer<List<Storage>>();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.widgetWithText(AlertDialog, '添加任务'), findsOneWidget);
    expect(storages.refreshes, 2);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '选择相册'))
          .onPressed,
      isNotNull,
    );
    var dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    expect(dropdown.items!.map((item) => item.value), ['old']);
    expect(dropdown.value, 'old');
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('旧存储').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '选择相册'))
          .onPressed,
      isNotNull,
    );

    // 远端移除旧存储后，自动选择新列表第一项。
    storages.pending!.complete([
      const Storage(id: 'cloud', name: '云端照片', type: 3),
    ]);
    await tester.pumpAndSettle();
    dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    expect(dropdown.value, 'cloud');
    expect(dropdown.items!.map((item) => item.value), ['cloud']);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('云端照片').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(TextButton, '选择相册'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '选择相册'), findsOneWidget);
    expect(find.text('123'), findsOneWidget);
    await tester.tap(find.text('旅行'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final records = await tester.runAsync(tasks.list);
    expect(records!.single.storageId, 'cloud');
    expect(records.single.storageName, '云端照片');
    expect(find.text('云端照片'), findsOneWidget);
    expect(find.text('0 / 123 张照片'), findsOneWidget);
    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .shape,
      isA<RoundedRectangleBorder>(),
    );

    // 同步时更多按钮仍可见，点击不打开菜单，也不修改任务。
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.sync), findsOneWidget);
    final rotation = tester.widget<RotationTransition>(
      find.ancestor(
        of: find.byIcon(Icons.sync),
        matching: find.byType(RotationTransition),
      ),
    );
    final turns = rotation.turns.value;
    await tester.pump(const Duration(milliseconds: 300));
    expect(rotation.turns.value, isNot(turns));
    expect(find.byIcon(Icons.stop), findsOneWidget);
    final syncButton = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(syncButton.backgroundColor, const Color(0xFFF97810));
    expect(syncButton.foregroundColor, Colors.white);
    expect(tester.widget<Icon>(find.byIcon(Icons.stop)).color, Colors.white);
    expect(tester.widget<Icon>(find.byIcon(Icons.stop)).size, 28);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('请先停止同步'), findsOneWidget);
    expect(find.text('编辑'), findsNothing);
    expect(find.text('置顶'), findsNothing);
    expect(find.text('删除'), findsNothing);
    expect(tasks.pinnedId, isNull);

    // 添加按钮保留原色，两个入口重复点击共用一条提示。
    expect(tester.widget<Icon>(find.byIcon(Icons.add)).color, isNull);
    final refreshes = storages.refreshes;
    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.more_vert));
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('请先停止同步'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(storages.refreshes, refreshes);
    expect(tasks.records.length, 1);

    // 移除当前提示后没有排队提示，下一次点击仍能正常提示。
    AppNotice.hide();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('请先停止同步'), findsNothing);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('请先停止同步'), findsOneWidget);
    expect(find.text('置顶'), findsNothing);
    expect(find.text('删除'), findsNothing);
    AppNotice.hide();
    await tester.pump();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.sync), findsNothing);
    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .backgroundColor,
      const Color(0xFF9C9C9C),
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.play_arrow)).color,
      Colors.white,
    );
    expect(tester.widget<Icon>(find.byIcon(Icons.play_arrow)).size, 28);
    expect(tester.widget<Icon>(find.byIcon(Icons.add)).color, isNull);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('置顶'), findsOneWidget);
    expect(find.text('取消置顶'), findsNothing);
    await tester.tap(find.text('置顶'));
    await tester.pumpAndSettle();
    expect(tasks.pinnedId, 'a');

    // 再次打开沿用更新后的缓存，并发起新一轮刷新。
    storages.pending = Completer<List<Storage>>();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump(const Duration(milliseconds: 300));
    expect(storages.refreshes, 3);
    dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    expect(dropdown.items!.single.value, 'cloud');
    storages.pending!.completeError(Exception('连接失败'));
    await tester.pumpAndSettle();
    expect(find.text('Exception: 连接失败'), findsOneWidget);
    dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    expect(dropdown.items!.single.value, 'cloud');
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(AlertDialog))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(tasks.records, isEmpty);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.text('0 / 123'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('任务页空白，底部导航可切换日志和设置并保留任务状态', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await database.database;
    });
    await tester.pumpWidget(
      localizedApp(
        home: AppPage(
          taskService: TaskService(database: database),
          storageService: StorageService(database: database),
        ),
      ),
    );
    await tester.runAsync(() async {
      await (await database.database).rawQuery('SELECT 1');
    });
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('还没有相册'), findsNothing);
    expect(find.text('点击右上角添加相册'), findsNothing);
    expect(find.byType(NavigationDestination), findsNWidgets(3));
    final taskState = tester.state(find.byType(TaskPage));

    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(find.widgetWithText(AppBar, '日志'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    expect(find.widgetWithText(AppBar, '设置'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.assignment_turned_in_outlined));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    expect(find.widgetWithText(AppBar, '任务'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(tester.state(find.byType(TaskPage)), same(taskState));
  });

  testWidgets('相册卡片按名称、存储、照片进度排列，窄屏没有溢出', (tester) async {
    const channel = MethodChannel('com.fluttercandies/photo_manager');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => switch (call.method) {
        'getPermissionState' => 3,
        'fetchPathProperties' => {
          'data': [
            {
              'id': 'a',
              'name': '旅行相册和一个足够长的名称',
              'assetCount': 123,
              'isAll': false,
            },
          ],
        },
        'getAssetCountFromPath' => 123,
        'getAssetListRange' => {'data': []},
        _ => null,
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final service = TaskService(database: database);
    await tester.runAsync(() async {
      await UserService(database: database).add(_user);
      await service.add(['a']);
      await service.updateProgress('a', 12);
      await service.updateInfo(
        'a',
        albumName: '旅行相册和一个足够长的名称',
        photoCount: 123,
      );
    });
    tester.view.devicePixelRatio = 1;
    for (final width in [320.0, 800.0]) {
      tester.view.physicalSize = Size(width, 700);
      await tester.pumpWidget(
        localizedApp(
          home: TaskPage(
            taskService: service,
            storageService: StorageService(database: database),
          ),
        ),
      );
      await tester.runAsync(() async {
        await (await database.database).rawQuery('SELECT 1');
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(find.text('12 / 123 张照片'), findsOneWidget);
      expect(find.text('本地存储'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.textContaining('张照片'), findsOneWidget);
      final nameY = tester.getTopLeft(find.text('旅行相册和一个足够长的名称')).dy;
      final storageY = tester.getTopLeft(find.text('本地存储')).dy;
      final countY = tester.getTopLeft(find.text('12 / 123 张照片')).dy;
      expect(nameY, lessThan(storageY));
      expect(storageY, lessThan(countY));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('存储落库后卡片更新名称和失效状态，保留照片进度', (tester) async {
    final tasks = TaskService(database: database);
    final storages = StorageService(
      database: database,
      fetch: (_) async => throw StateError('离线'),
    );
    const storage = Storage(id: 'cloud', name: '旧存储', type: 3);
    await tester.runAsync(() async {
      await UserService(database: database).add(_user);
      await storages.save([storage], account: _user);
      await tasks.add(['a'], storage: storage);
      await tasks.updateInfo('a', albumName: '旅行', photoCount: 123);
      await tasks.updateProgress('a', 12);
    });
    await _pumpTaskPage(tester, tasks, storages);
    expect(find.text('旧存储'), findsOneWidget);

    await tester.runAsync(() async {
      await storages.save([
        const Storage(id: 'cloud', name: '新存储', type: 3),
      ], account: _user);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text('旧存储'), findsNothing);
    expect(find.text('新存储'), findsOneWidget);
    expect(find.text('12 / 123 张照片'), findsOneWidget);

    await tester.runAsync(() async {
      await storages.save([], account: _user);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    final missing = find.text('存储失效');
    expect(missing, findsOneWidget);
    expect(
      tester.widget<Text>(missing).style?.color,
      Theme.of(tester.element(missing)).colorScheme.error,
    );
    expect(find.text('12 / 123 张照片'), findsOneWidget);
    expect(find.text('旅行'), findsOneWidget);
    await tester.runAsync(() async {
      await tasks.updateInvalid('a', true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text('失效'), findsOneWidget);
    final badge = tester.widget<DecoratedBox>(
      find
          .ancestor(of: find.text('失效'), matching: find.byType(DecoratedBox))
          .first,
    );
    expect(
      (badge.decoration as BoxDecoration).color,
      Theme.of(tester.element(find.text('失效'))).colorScheme.error,
    );
    expect(
      tester.getTopLeft(find.text('失效')).dx,
      lessThan(tester.getTopLeft(find.text('旅行')).dx),
    );
    expect(find.text('12 / 123 张照片'), findsOneWidget);
    await tester.runAsync(() async {
      await tasks.updateInvalid('a', false);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text('失效'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('退出登录立即隐藏旧任务，切换账户只展示新账户任务', (tester) async {
    final tasks = TaskService(database: database);
    final users = UserService(database: database);
    const other = User(
      userId: 'other',
      username: 'other',
      avatar: '',
      type: 0,
      token: 'other-token',
      endpoint: 'https://example.test',
    );
    await tester.runAsync(() async {
      await users.add(_user);
      await tasks.add(['a']);
      await tasks.updateInfo('a', albumName: '账号甲相册', photoCount: 10);
      await tasks.add(['a'], account: other);
      await tasks.updateInfo(
        'a',
        albumName: '账号乙相册',
        photoCount: 20,
        account: other,
      );
    });
    await _pumpTaskPage(tester, tasks, StorageService(database: database));
    expect(find.text('账号甲相册'), findsOneWidget);
    expect(find.text('账号乙相册'), findsNothing);
    await tester.runAsync(() async {
      await users.remove(_user.userId);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text('账号甲相册'), findsNothing);
    await tester.runAsync(() async {
      await users.add(other);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text('账号甲相册'), findsNothing);
    expect(find.text('账号乙相册'), findsOneWidget);
    expect(find.text('0 / 20 张照片'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('完成数量等于全部数量时在数量右侧显示同步完成', (tester) async {
    final tasks = TaskService(database: database);
    await tester.runAsync(() async {
      await UserService(database: database).add(_user);
      await tasks.add(['done', 'empty', 'partial']);
      await tasks.updateInfo('done', albumName: '已完成', photoCount: 5);
      await tasks.updateProgress('done', 5);
      await tasks.updateInfo('empty', albumName: '空相册', photoCount: 0);
      await tasks.updateProgress('empty', 0);
      await tasks.updateInfo('partial', albumName: '未完成', photoCount: 10);
      await tasks.updateProgress('partial', 3);
    });
    await _pumpTaskPage(tester, tasks, StorageService(database: database));
    expect(find.text('同步完成'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('同步完成')).dx,
      greaterThan(tester.getTopRight(find.text('5 / 5 张照片')).dx),
    );
    final badge = tester.widget<DecoratedBox>(
      find
          .ancestor(of: find.text('同步完成'), matching: find.byType(DecoratedBox))
          .first,
    );
    expect(
      (badge.decoration as BoxDecoration).color,
      Theme.of(tester.element(find.text('同步完成'))).colorScheme.primary,
    );
    expect(find.text('0 / 0 张照片'), findsOneWidget);
    expect(find.text('3 / 10 张照片'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('编辑位于菜单首行，默认当前存储，取消不修改，保存刷新卡片', (tester) async {
    final tasks = TaskService(database: database);
    final storages = StorageService(
      database: database,
      fetch: (_) async => throw StateError('离线'),
    );
    const first = Storage(id: 'first', name: '第一个存储', type: 1);
    const current = Storage(id: 'current', name: '当前存储', type: 3);
    await tester.runAsync(() async {
      await UserService(database: database).add(_user);
      await storages.save([first, current], account: _user);
      await tasks.add(['a'], storage: current);
      await tasks.updateInfo('a', albumName: '旅行', photoCount: 123);
      await tasks.updateProgress('a', 12);
    });
    await _pumpTaskPage(tester, tasks, storages);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('编辑')).dy,
      lessThan(tester.getTopLeft(find.text('置顶')).dy),
    );
    await tester.tap(find.text('编辑'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AlertDialog, '编辑任务'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
          .value,
      current.id,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('12 / 123 张照片'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(first.name).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(first.name), findsOneWidget);
    expect(find.text('旅行'), findsOneWidget);
    expect(find.text('12 / 123 张照片'), findsOneWidget);
    final records = await tester.runAsync(tasks.list);
    expect(records!.single.storageId, first.id);
    expect(records.single.completedCount, 12);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('开始同步时没有通知权限会提示后台同步需要通知', (tester) async {
    final tasks = DialogTaskService(database)
      ..records.add(
        Task(albumId: 'a', sortTime: DateTime.utc(2026), albumName: '相机'),
      );
    final sync = NoticeSyncService(tasks);
    const channel = MethodChannel('com.fluttercandies/photo_manager');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => switch (call.method) {
        'requestPermissionExtend' || 'getPermissionState' => 3,
        'getAssetPathList' || 'fetchPathProperties' => {'data': []},
        'getAssetCountFromPath' => 0,
        'getAssetListRange' => {'data': []},
        _ => null,
      },
    );
    addTearDown(() {
      AppNotice.hide();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });
    await tester.pumpWidget(
      localizedApp(
        home: TaskPage(
          taskService: tasks,
          storageService: DialogStorageService(database),
          syncService: sync,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(find.text('需要通知权限才能后台同步'), findsOneWidget);
    AppNotice.hide();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _pumpTaskPage(
  WidgetTester tester,
  TaskService tasks,
  StorageService storages,
) async {
  await tester.pumpWidget(
    localizedApp(
      home: TaskPage(
        taskService: tasks,
        storageService: storages,
        syncService: WaitingSyncService(tasks),
      ),
    ),
  );
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pumpAndSettle();
}

/// 隔离数据库线程，专注验证弹窗提交的任务字段。
class DialogTaskService extends TaskService {
  /// 注入测试数据库，避免初始化平台默认连接。
  DialogTaskService(Db database) : super(database: database);

  final List<Task> records = [];
  String? pinnedId;

  /// 为弹窗交互提供固定登录账户，不等待数据库线程。
  @override
  Future<User?> currentUser() async => _user;

  /// 接收页面提交的相册及存储。
  @override
  Future<void> add(
    List<String> albumIds, {
    Storage? storage,
    User? account,
  }) async {
    records.addAll(
      albumIds.map(
        (id) => Task(
          albumId: id,
          sortTime: DateTime.now(),
          storageId: storage?.id,
          storageName: storage?.name ?? '本地存储',
        ),
      ),
    );
  }

  /// 返回已提交的任务，供页面恢复卡片。
  @override
  Future<List<Task>> list({User? account}) async => records;

  /// 在内存中更新失效状态，与测试任务列表保持一致。
  @override
  Future<void> updateInvalid(
    String albumId,
    bool isInvalid, {
    User? account,
  }) async {
    final index = records.indexWhere((record) => record.albumId == albumId);
    if (index == -1 || records[index].isInvalid == isInvalid) return;
    final record = records[index];
    records[index] = Task(
      albumId: record.albumId,
      sortTime: record.sortTime,
      completedCount: record.completedCount,
      storageId: record.storageId,
      storageName: record.storageName,
      path: record.path,
      albumName: record.albumName,
      photoCount: record.photoCount,
      cover: record.cover,
      isInvalid: isInvalid,
    );
    TaskService.notifyChanged();
  }

  /// 更新测试任务的相册展示缓存。
  @override
  Future<void> updateInfo(
    String albumId, {
    required String albumName,
    required int photoCount,
    Uint8List? cover,
    User? account,
  }) async {
    final index = records.indexWhere((record) => record.albumId == albumId);
    if (index == -1) return;
    final record = records[index];
    records[index] = Task(
      albumId: record.albumId,
      sortTime: record.sortTime,
      completedCount: record.completedCount,
      storageName: record.storageName,
      storageId: record.storageId,
      albumName: albumName,
      photoCount: photoCount,
      cover: cover,
      isInvalid: record.isInvalid,
    );
  }

  /// 记录菜单提交的置顶目标，排序逻辑由数据库测试验证。
  @override
  Future<void> pin(String albumId, {User? account}) async => pinnedId = albumId;

  /// 移除菜单指定任务。
  @override
  Future<void> remove(String albumId, {User? account}) async {
    records.removeWhere((record) => record.albumId == albumId);
  }
}

const _user = User(
  userId: 'user',
  username: 'tester',
  avatar: '',
  type: 0,
  token: 'token',
  endpoint: 'https://example.test',
);

/// 模拟通知权限被拒绝后服务上报的英文提示。
class NoticeSyncService extends SyncService {
  /// 复用测试任务服务，避免默认数据库连接。
  NoticeSyncService(TaskService tasks) : super(tasks: tasks);

  /// 只上报通知权限提示，不访问设备或远端接口。
  @override
  Future<void> start(
    void Function(SyncProgress) onProgress, {
    void Function(String?)? onAlbumChanged,
    void Function(String message)? onNotice,
  }) async {
    onNotice?.call('Notifications are required for background sync');
  }
}

/// 保持同步开启，验证卡片菜单在同步期间不能操作。
class WaitingSyncService extends SyncService {
  /// 复用测试任务服务，避免默认数据库连接。
  WaitingSyncService(TaskService tasks) : super(tasks: tasks);

  final _finished = Completer<void>();

  /// 等待手动停止，不访问设备或远端接口。
  @override
  Future<void> start(
    void Function(SyncProgress) onProgress, {
    void Function(String?)? onAlbumChanged,
    void Function(String message)? onNotice,
  }) async {
    onAlbumChanged?.call('a');
    await _finished.future;
    onAlbumChanged?.call(null);
  }

  /// 结束测试中的同步流程。
  @override
  Future<void> stop() async {
    if (!_finished.isCompleted) _finished.complete();
  }
}

/// 控制弹窗刷新时机，验证请求未完成时仍可使用缓存。
class DialogStorageService extends StorageService {
  /// 使用测试数据库创建存储服务。
  DialogStorageService(Db database) : super(database: database);

  List<Storage> cached = [const Storage(id: 'old', name: '旧存储', type: 1)];
  Completer<List<Storage>>? pending;
  int refreshes = 0;

  /// 立即返回上次缓存。
  @override
  Future<List<Storage>> list() async => cached;

  /// 由测试决定远端请求何时返回。
  @override
  Future<List<Storage>> refresh() async {
    refreshes++;
    return cached = pending == null ? cached : await pending!.future;
  }
}
