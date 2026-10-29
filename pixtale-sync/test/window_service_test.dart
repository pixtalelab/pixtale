import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixtale_sync/services/window_service.dart';

// 验证默认窗口屏幕适配。

/// 执行桌面窗口测试，无需创建原生窗口。
void main() {

  test('首次打开使用默认尺寸并居中', () {
    expect(
      WindowService.fitBounds(const Rect.fromLTWH(0, 0, 1920, 1040)),
      const Rect.fromLTWH(660, 40, 600, 960),
    );
  });

  test('按屏幕原点居中，支持负坐标屏幕', () {
    expect(
      WindowService.fitBounds(const Rect.fromLTWH(-1920, 0, 1920, 1040)),
      const Rect.fromLTWH(-1260, 40, 600, 960),
    );
  });

  test('窗口限制在可用屏幕内，支持比最小尺寸还小的屏幕', () {
    expect(
      WindowService.fitBounds(const Rect.fromLTWH(0, 0, 800, 600)),
      const Rect.fromLTWH(100, 0, 600, 600),
    );
    expect(
      WindowService.fitBounds(const Rect.fromLTWH(0, 0, 500, 400)),
      const Rect.fromLTWH(0, 0, 500, 400),
    );
  });

  test('已保存尺寸居中，超出屏幕或小于最小尺寸时退回默认', () {
    expect(
      WindowService.fitBounds(
        const Rect.fromLTWH(0, 0, 1920, 1040),
        saved: const Size(720, 800),
      ),
      const Rect.fromLTWH(600, 120, 720, 800),
    );
    expect(
      WindowService.fitBounds(
        const Rect.fromLTWH(0, 0, 1920, 1040),
        saved: const Size(2000, 800),
      ),
      const Rect.fromLTWH(660, 40, 600, 960),
    );
    expect(
      WindowService.fitBounds(
        const Rect.fromLTWH(0, 0, 1920, 1040),
        saved: const Size(500, 400),
      ),
      const Rect.fromLTWH(660, 40, 600, 960),
    );
  });

  test('窗口文件保存宽高，无效内容视为没有记录', () async {
    final directory = await Directory.systemTemp.createTemp('window_json_');
    addTearDown(() => directory.delete(recursive: true));
    expect(await WindowService.readSavedSize(directory), isNull);

    await WindowService.writeSavedSize(const Size(720, 800), directory);
    expect(await WindowService.readSavedSize(directory), const Size(720, 800));

    final file = File('${directory.path}/window.json');
    await file.writeAsString('{');
    expect(await WindowService.readSavedSize(directory), isNull);
    expect(WindowService.sizeFromJson('{"width":100,"height":100}'), isNull);
  });
}
