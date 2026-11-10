import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixtale_sync/db/db.dart';
import 'package:pixtale_sync/models/user.dart';
import 'package:pixtale_sync/pages/settings_page.dart';
import 'package:pixtale_sync/services/user_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'localized_app.dart';

// 验证手机和 Windows 设置页的常见问题入口及说明弹窗。

/// 验证常见问题仅展示提示，并可通过确认按钮关闭。
void main() {
  sqfliteFfiInit();

  testWidgets(
    '常见问题仅展示省电策略提示，手机和 Windows 均可查看',
    (tester) async {
      await tester.pumpWidget(
        localizedApp(home: SettingsPage(userService: _NoUserService())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      expect(find.text('常见问题'), findsOneWidget);
      expect(find.textContaining('无限制'), findsOneWidget);
      expect(find.text('前往开启'), findsNothing);
      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(of: dialog, matching: find.byType(TextButton)),
        findsOneWidget,
      );
      final context = tester.element(dialog);
      await tester.tap(
        find.text(MaterialLocalizations.of(context).okButtonLabel),
      );
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.windows,
    }),
  );
}

/// 不连接真实账户或数据库，页面沿用默认设置。
class _NoUserService extends UserService {
  /// 使用不会打开的测试存储创建账户服务。
  _NoUserService() : super(database: Db(factory: databaseFactoryFfi));

  /// 模拟尚未初始化的账户存储。
  @override
  Future<User?> get() async => throw StateError('No account store');
}
