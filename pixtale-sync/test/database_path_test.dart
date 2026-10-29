import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixtale_sync/db/database_path.dart';
import 'package:path/path.dart' as path;

// 验证桌面数据库创建在指定的用户数据目录。

/// 在临时目录中验证路径准备，不访问真实用户数据库。
void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('database_path_');
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  test('在用户数据目录创建数据库路径', () async {
    final directory = path.join(root.path, 'pixtale-sync');
    final result = await prepareDesktopDatabase(directory);

    expect(result, path.join(directory, 'pixtale-sync.sqlite'));
    expect(await Directory(directory).exists(), isTrue);
    expect(await File(result).exists(), isFalse);
  });
}
