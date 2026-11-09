import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixtale_sync/components/template/template_card.dart';
import 'package:pixtale_sync/models/storage.dart';
import 'package:pixtale_sync/models/rule.dart';
import 'package:pixtale_sync/pages/template_page.dart';
import 'package:pixtale_sync/services/storage_service.dart';
import 'package:pixtale_sync/services/rule_service.dart';
import 'package:pixtale_sync/services/user_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'localized_app.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late _Templates templates;
  late _Storages storages;

  setUp(() {
    templates = _Templates();
    storages = _Storages();
  });

  Future<void> show(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    await tester.pumpWidget(
      localizedApp(
        home: TemplatePage(service: templates, storageService: storages),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );

  Future<void> range(
    WidgetTester tester,
    String minimum,
    String maximum,
  ) async {
    await tester.enterText(field('最小值'), minimum);
    await tester.enterText(field('最大值'), maximum);
  }

  Future<void> type(WidgetTester tester, String value) async {
    final dropdown = find.byType(DropdownButtonFormField<RuleFileType>);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(value).last);
    await tester.pumpAndSettle();
  }

  testWidgets('窄屏创建规则，卡片展示两行规则，追加规则排在末尾', (tester) async {
    await show(tester);
    expect(find.widgetWithText(AppBar, '规则'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(field('规则名称'), '旅行');
    await range(tester, '20', '30');
    await type(tester, '视频');
    final storage = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(storage);
    await tester.tap(storage);
    await tester.pumpAndSettle();
    await tester.tap(find.text('视频云盘').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('旅行'), findsOneWidget);
    expect(find.text('20 - 30 MB 视频'), findsOneWidget);
    expect(find.text('视频云盘'), findsOneWidget);
    expect(templates.records.single.items.single.fileMinSize, 20 * 1024 * 1024);
    expect(templates.records.single.items.single.storageId, 'video');
    for (final value in ['照片', '不限']) {
      await tester.tap(find.widgetWithText(TextButton, '添加规则'));
      await tester.pumpAndSettle();
      expect(field('规则名称'), findsNothing);
      await range(tester, '0', '10.5');
      await type(tester, value);
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('0 - 10.5 MB $value'), findsOneWidget);
    }
    expect(find.byType(TemplateCard), findsOneWidget);
    expect(templates.records.single.items.map((item) => item.fileType), [
      RuleFileType.video,
      RuleFileType.photo,
      RuleFileType.any,
    ]);
    expect(
      tester.getTopLeft(find.text('0 - 10.5 MB 不限')).dy,
      greaterThan(tester.getTopLeft(find.text('0 - 10.5 MB 照片')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('校验名称和范围，取消不新增，保存失败可重试', (tester) async {
    await show(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('请输入规则名称'), findsOneWidget);
    expect(find.text('请输入有效数值'), findsNWidgets(2));
    await tester.enterText(field('规则名称'), '测试');
    await range(tester, '-1', '10');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('请输入有效数值'), findsOneWidget);
    await range(tester, '30', '20');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('最大值不能小于最小值'), findsOneWidget);
    expect(templates.records, isEmpty);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(templates.records, isEmpty);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(field('规则名称'), '测试');
    await range(tester, '0', '1');
    templates.failSave = true;
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('操作失败，请稍后重试'), findsOneWidget);
    expect(templates.records, isEmpty);
    templates.failSave = false;
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('0 - 1 MB 不限'), findsOneWidget);
    expect(templates.records, hasLength(1));
  });

  testWidgets('规则菜单支持回填编辑、取消与保存，删除最后一条仍保留规则', (tester) async {
    final pid = await templates.add(
      name: '旅行',
      fileType: RuleFileType.video,
      fileMinSize: 20 * 1024 * 1024,
      fileMaxSize: 30 * 1024 * 1024,
      storageId: 'video',
    );
    await templates.addItem(
      pid: pid,
      fileType: RuleFileType.any,
      fileMinSize: 0,
      fileMaxSize: 1024 * 1024,
      storageId: 'photos',
    );
    final first = templates.records.single.items.first;
    await show(tester);

    Future<void> edit() async {
      await tester.tap(find.byIcon(Icons.settings_outlined).first);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(MenuItemButton, '编辑'), findsOneWidget);
      expect(find.widgetWithText(MenuItemButton, '删除'), findsOneWidget);
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
    }

    await edit();
    expect(find.widgetWithText(AlertDialog, '编辑规则'), findsOneWidget);
    expect(field('规则名称'), findsNothing);
    expect(tester.widget<TextField>(field('最小值')).controller!.text, '20');
    expect(tester.widget<TextField>(field('最大值')).controller!.text, '30');
    expect(
      tester.getTopLeft(field('最小值')).dy,
      tester.getTopLeft(field('最大值')).dy,
    );
    expect(
      tester
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
          .value,
      'video',
    );
    await range(tester, '25', '35');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('20 - 30 MB 视频'), findsOneWidget);
    await edit();
    await range(tester, '25', '35');
    await type(tester, '照片');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('照片云盘').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('25 - 35 MB 照片'), findsOneWidget);
    expect(find.text('20 - 30 MB 视频'), findsNothing);
    expect(templates.records.single.items, hasLength(2));
    expect(templates.records.single.items.first.id, first.id);
    expect(templates.records.single.items.first.createdAt, first.createdAt);
    expect(templates.records.single.items.first.storageId, 'photos');
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('25 - 35 MB 照片'), findsNothing);
    expect(find.text('0 - 1 MB 不限'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('旅行'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
    expect(find.widgetWithText(TextButton, '添加规则'), findsOneWidget);
    expect(templates.records.single.items, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('规则菜单只编辑名称，支持校验、取消、保存重试和删除整个规则', (tester) async {
    final pid = await templates.add(
      name: '旅行',
      fileType: RuleFileType.video,
      fileMinSize: 20 * 1024 * 1024,
      fileMaxSize: 30 * 1024 * 1024,
      storageId: 'video',
    );
    await templates.add(
      name: '其他规则',
      fileType: RuleFileType.any,
      fileMinSize: 0,
      fileMaxSize: 1024 * 1024,
      storageId: 'photos',
    );
    final before = templates.records.first;
    await show(tester);
    expect(find.widgetWithText(TextButton, '添加规则'), findsNWidgets(2));

    Future<void> edit() async {
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(MenuItemButton, '编辑'), findsOneWidget);
      expect(find.widgetWithText(MenuItemButton, '删除'), findsOneWidget);
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
    }

    await edit();
    expect(find.widgetWithText(AlertDialog, '编辑规则'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(field('最小值'), findsNothing);
    expect(field('最大值'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.byType(DropdownButtonFormField<RuleFileType>), findsNothing);
    expect(tester.widget<TextField>(field('规则名称')).controller!.text, '旅行');
    await tester.enterText(field('规则名称'), ' ');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('请输入规则名称'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(templates.records.first.name, '旅行');
    await edit();
    await tester.enterText(field('规则名称'), '新的规则');
    templates.failSave = true;
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('操作失败，请稍后重试'), findsOneWidget);
    expect(templates.records.first.name, '旅行');
    templates.failSave = false;
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('新的规则'), findsOneWidget);
    expect(find.text('旅行'), findsNothing);
    expect(templates.records.first.id, pid);
    expect(templates.records.first.sortTime, before.sortTime);
    expect(templates.records.first.items, before.items);
    expect(find.text('20 - 30 MB 视频'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('新的规则'), findsNothing);
    expect(find.text('20 - 30 MB 视频'), findsNothing);
    expect(find.text('其他规则'), findsOneWidget);
    expect(templates.records, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('规则菜单第二项为置顶，点击后规则移到最前且子规则没有置顶入口', (tester) async {
    await templates.add(
      name: '规则一',
      fileType: RuleFileType.photo,
      fileMinSize: 0,
      fileMaxSize: 1024 * 1024,
      storageId: 'photos',
    );
    await templates.add(
      name: '规则二',
      fileType: RuleFileType.video,
      fileMinSize: 20 * 1024 * 1024,
      fileMaxSize: 30 * 1024 * 1024,
      storageId: 'video',
    );
    await show(tester);
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<MenuItemButton>(find.byType(MenuItemButton))
          .map((button) => (button.child as Text).data),
      ['编辑', '置顶', '删除'],
    );
    await tester.tap(find.text('置顶'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TemplateCard>(find.byType(TemplateCard).first)
          .template
          .name,
      '规则二',
    );
    expect(find.text('20 - 30 MB 视频'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('置顶'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('存储刷新期间不显示加载动画，已有选项仍可选择和保存', (tester) async {
    await show(tester);
    final pending = Completer<List<Storage>>();
    storages.pending = pending;
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('照片云盘'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '保存'))
          .onPressed,
      isNotNull,
    );
    expect(
      tester.getTopLeft(field('最小值')).dy,
      tester.getTopLeft(field('最大值')).dy,
    );
    pending.complete(storages.items);
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
  });

  testWidgets('启动即预加载，切换不重读，隐藏时账户变化也重载并丢弃旧结果', (tester) async {
    templates.userId = 'a';
    await templates.add(
      name: 'A 的规则',
      fileType: RuleFileType.video,
      fileMinSize: 0,
      fileMaxSize: 1024 * 1024,
      storageId: 'video',
    );
    final a = templates.records.single;
    templates.userId = 'b';
    await templates.add(
      name: 'B 的规则',
      fileType: RuleFileType.photo,
      fileMinSize: 0,
      fileMaxSize: 1024 * 1024,
      storageId: 'photos',
    );
    templates.userId = 'a';
    final selected = ValueNotifier<int>(0);
    addTearDown(selected.dispose);
    final page = TemplatePage(service: templates, storageService: storages);
    await tester.pumpWidget(
      localizedApp(
        home: ValueListenableBuilder<int>(
          valueListenable: selected,
          builder: (_, index, _) =>
              IndexedStack(index: index, children: [const SizedBox(), page]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(templates.reads, 1);
    expect(find.text('A 的规则'), findsNothing);
    expect(find.text('A 的规则', skipOffstage: false), findsOneWidget);
    selected.value = 1;
    await tester.pumpAndSettle();
    expect(find.text('A 的规则'), findsOneWidget);
    expect(templates.reads, 1);
    selected.value = 0;
    await tester.pumpAndSettle();
    templates.userId = null;
    UserService.changes.value++;
    await tester.pumpAndSettle();
    expect(find.byType(TemplateCard, skipOffstage: false), findsNothing);
    expect(templates.reads, 2);
    templates.userId = 'b';
    UserService.changes.value++;
    await tester.pumpAndSettle();
    expect(find.text('B 的规则', skipOffstage: false), findsOneWidget);
    expect(find.text('A 的规则', skipOffstage: false), findsNothing);
    final stale = Completer<List<Rule>>();
    templates.pendingList = stale;
    templates.userId = 'a';
    UserService.changes.value++;
    await tester.pump();
    expect(find.byType(TemplateCard, skipOffstage: false), findsNothing);
    templates.pendingList = null;
    templates.userId = 'b';
    UserService.changes.value++;
    await tester.pumpAndSettle();
    stale.complete([a]);
    await tester.pumpAndSettle();
    selected.value = 1;
    await tester.pumpAndSettle();
    expect(find.text('B 的规则'), findsOneWidget);
    expect(find.text('A 的规则'), findsNothing);
    expect(templates.reads, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('登录失效时清空列表并关闭编辑弹窗，重新登录恢复该用户规则', (tester) async {
    await templates.add(
      name: '原规则',
      fileType: RuleFileType.any,
      fileMinSize: 0,
      fileMaxSize: 1024 * 1024,
      storageId: 'video',
    );
    await show(tester);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    templates.userId = null;
    UserService.changes.value++;
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(TemplateCard), findsNothing);
    templates.userId = 'user';
    UserService.changes.value++;
    await tester.pumpAndSettle();
    expect(find.text('原规则'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '添加规则'));
    await tester.pumpAndSettle();
    templates.userId = null;
    UserService.changes.value++;
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(TemplateCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('首次加载规则时保留列表区域，不显示加载动画', (tester) async {
    final pending = Completer<List<Rule>>();
    templates.pendingList = pending;
    await show(tester);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.add), findsOneWidget);
    pending.complete([]);
    await tester.pumpAndSettle();
  });

  testWidgets('打开添加规则并刷新存储时保留规则卡片、列表状态和已有名称', (tester) async {
    await templates.add(
      name: '旅行',
      fileType: RuleFileType.video,
      fileMinSize: 20 * 1024 * 1024,
      fileMaxSize: 30 * 1024 * 1024,
      storageId: 'video',
    );
    await show(tester);
    final card = tester.element(find.byType(TemplateCard));
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final refresh = Completer<List<Storage>>();
    storages.pending = refresh;
    await tester.tap(find.widgetWithText(TextButton, '添加规则'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AlertDialog, '添加规则'), findsOneWidget);
    final listing = Completer<List<Storage>>();
    storages.pendingList = listing;
    const updated = [Storage(id: 'video', name: '新视频云盘', type: 1)];
    refresh.complete(updated);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byType(CircularProgressIndicator, skipOffstage: false),
      findsNothing,
    );
    expect(
      tester.element(find.byType(TemplateCard, skipOffstage: false)),
      same(card),
    );
    expect(
      tester.state<ScrollableState>(
        find.byType(Scrollable, skipOffstage: false).first,
      ),
      same(scroll),
    );
    expect(
      find.descendant(
        of: find.byType(TemplateCard, skipOffstage: false),
        matching: find.text('视频云盘', skipOffstage: false),
      ),
      findsOneWidget,
    );
    listing.complete(updated);
    await tester.pumpAndSettle();
    expect(
      tester.element(find.byType(TemplateCard, skipOffstage: false)),
      same(card),
    );
    expect(
      find.descendant(
        of: find.byType(TemplateCard, skipOffstage: false),
        matching: find.text('新视频云盘', skipOffstage: false),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(tester.element(find.byType(TemplateCard)), same(card));
    expect(tester.takeException(), isNull);
  });

  testWidgets('没有存储禁止保存，存储移除后卡片显示失效', (tester) async {
    await templates.add(
      name: '已有规则',
      fileType: RuleFileType.any,
      fileMinSize: 0,
      fileMaxSize: 1024 * 1024,
      storageId: 'missing',
    );
    storages.items = [];
    await show(tester);
    expect(find.text('存储失效'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '添加规则'));
    await tester.pumpAndSettle();
    expect(find.text('暂无可用存储'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '保存'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(templates.records.single.items, hasLength(1));
  });
}

class _Storages extends StorageService {
  Completer<List<Storage>>? pending;
  Completer<List<Storage>>? pendingList;
  List<Storage> items = const [
    Storage(id: 'photos', name: '照片云盘', type: 1),
    Storage(id: 'video', name: '视频云盘', type: 1),
  ];

  @override
  Future<List<Storage>> list() async => pendingList?.future ?? items;

  @override
  Future<List<Storage>> refresh() async {
    items = await (pending?.future ?? Future.value(items));
    StorageService.notifyChanged();
    return items;
  }
}

class _Templates extends RuleService {
  Completer<List<Rule>>? pendingList;
  final records = <Rule>[];
  bool failSave = false;
  int _id = 0;
  String? userId = 'user';
  int reads = 0;

  @override
  Future<List<Rule>> list() async {
    reads++;
    return pendingList?.future ??
        (records.where((record) => record.userId == userId).toList()
          ..sort((a, b) => a.sortTime.compareTo(b.sortTime)));
  }

  @override
  Future<void> rename({required String id, required String name}) async {
    if (failSave) throw StateError('Save failed');
    final index = records.indexWhere((record) => record.id == id);
    final before = records[index];
    records[index] = Rule(
      id: id,
      userId: before.userId,
      name: name.trim(),
      sortTime: before.sortTime,
      items: before.items,
    );
  }

  @override
  Future<void> remove(String id) async {
    records.removeWhere((record) => record.id == id);
  }

  @override
  Future<void> pin(String id) async {
    final owned = records.where((record) => record.userId == userId);
    final minimum = owned
        .map((record) => record.sortTime)
        .reduce((a, b) => a < b ? a : b);
    final index = records.indexWhere((record) => record.id == id);
    final before = records[index];
    records[index] = Rule(
      id: id,
      userId: before.userId,
      name: before.name,
      sortTime: minimum - 1,
      items: before.items,
    );
  }

  @override
  Future<String> add({
    required String name,
    required RuleFileType fileType,
    required int fileMinSize,
    required int fileMaxSize,
    required String storageId,
  }) async {
    if (failSave) throw StateError('Save failed');
    final id = 'template-${_id++}';
    records.add(
      Rule(
        id: id,
        userId: userId!,
        name: name,
        sortTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        items: [],
      ),
    );
    await addItem(
      pid: id,
      fileType: fileType,
      fileMinSize: fileMinSize,
      fileMaxSize: fileMaxSize,
      storageId: storageId,
    );
    return id;
  }

  @override
  Future<void> addItem({
    required String pid,
    required RuleFileType fileType,
    required int fileMinSize,
    required int fileMaxSize,
    required String storageId,
  }) async {
    if (failSave) throw StateError('Save failed');
    records
        .singleWhere((record) => record.id == pid)
        .items
        .add(
          RuleItem(
            id: 'item-${_id++}',
            pid: pid,
            fileType: fileType,
            fileMinSize: fileMinSize,
            fileMaxSize: fileMaxSize,
            storageId: storageId,
            createdAt: DateTime.now(),
          ),
        );
  }

  @override
  Future<void> updateItem({
    required String id,
    required String pid,
    required RuleFileType fileType,
    required int fileMinSize,
    required int fileMaxSize,
    required String storageId,
  }) async {
    if (failSave) throw StateError('Save failed');
    final items = records.singleWhere((record) => record.id == pid).items;
    final index = items.indexWhere((item) => item.id == id);
    final before = items[index];
    items[index] = RuleItem(
      id: id,
      pid: pid,
      fileType: fileType,
      fileMinSize: fileMinSize,
      fileMaxSize: fileMaxSize,
      storageId: storageId,
      createdAt: before.createdAt,
    );
  }

  @override
  Future<void> removeItem({required String id, required String pid}) async {
    records
        .singleWhere((record) => record.id == pid)
        .items
        .removeWhere((item) => item.id == id);
  }
}
