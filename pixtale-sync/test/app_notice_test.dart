import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixtale_sync/components/common/app_notice.dart';

// 验证顶部提示的位置、去重、替换与自动关闭。

/// 执行顶部提示组件测试。
void main() {
  tearDown(AppNotice.hide);

  testWidgets('提示靠近顶部栏且不改变页面布局或拦截点击', (tester) async {
    var taps = 0;
    tester.view.padding = const FakeViewPadding(top: 32);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: 32)),
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  taps++;
                  AppNotice.show(context, '顶部提示');
                },
                child: const Text('显示提示'),
              ),
            ),
          ),
        ),
      ),
    );
    final button = find.text('显示提示');
    final position = tester.getTopLeft(button);
    await tester.tap(button);
    await tester.pump();
    final message = find.text('顶部提示');
    expect(message, findsOneWidget);
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final top = tester.getTopLeft(message).dy;
    expect(top, lessThan(screenHeight * 0.5));
    expect(top, greaterThan(32));
    expect(top, lessThan(32 + kToolbarHeight + 48));
    expect(tester.getTopLeft(button), position);
    await tester.tap(button);
    await tester.pump();
    expect(taps, 2);
    expect(message, findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(message, findsNothing);
  });

  testWidgets('新提示替换旧提示，关闭后没有排队提示', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const Scaffold();
          },
        ),
      ),
    );
    AppNotice.show(context, '旧提示');
    AppNotice.show(context, '新提示');
    AppNotice.show(context, '新提示');
    await tester.pump();
    expect(find.text('旧提示'), findsNothing);
    expect(find.text('新提示'), findsOneWidget);
    AppNotice.hide();
    await tester.pump();
    expect(find.text('新提示'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('旧提示'), findsNothing);
  });
}
