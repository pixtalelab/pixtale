import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixtale_sync/components/common/window_title_bar.dart';

// 自定义标题栏只放窗口按钮，不放固定、logo 和名称。

/// 执行标题栏布局测试。
void main() {
  testWidgets('标题栏只有最小化、最大化和关闭', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      (call) async => switch (call.method) {
        'isMaximized' => false,
        _ => null,
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        null,
      );
    });

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WindowTitleBar())),
    );
    await tester.pump();

    expect(find.byType(IconButton), findsNWidgets(3));
    expect(find.byIcon(Icons.horizontal_rule), findsOneWidget);
    expect(find.byIcon(Icons.crop_square), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.text('Pixtale Sync'), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.push_pin), findsNothing);
    expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
  });
}
