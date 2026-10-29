import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

// 数据库文件放在当前用户可写目录，不读取程序目录或旧位置。

/// 用户数据目录名和数据库文件名。
const databaseName = 'pixtale-sync';

/// 共享默认路径的准备过程，避免多个 Service 同时创建数据目录。
Future<String>? _databasePath;

/// 桌面端使用用户本地数据目录，移动端继续使用应用文档目录。
Future<String> getDatabaseFilePath() =>
    _databasePath ??= _resolveDatabaseFilePath();

/// 读取平台目录并确保桌面数据目录存在。
Future<String> _resolveDatabaseFilePath() async {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    return prepareDesktopDatabase(await desktopDatabaseDirectory());
  }
  final documents = await getApplicationDocumentsDirectory();
  return path.join(documents.path, '$databaseName.sqlite');
}

/// Windows 使用 LocalAppData，其他桌面平台使用应用支持目录。
Future<String> desktopDatabaseDirectory() async {
  if (Platform.isWindows) {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      return path.join(localAppData, databaseName);
    }
  }
  return (await getApplicationSupportDirectory()).path;
}

/// 创建用户数据目录并返回数据库文件路径。文件在首次打开时创建。
Future<String> prepareDesktopDatabase(String dataDirectory) async {
  final directory = Directory(dataDirectory);
  await directory.create(recursive: true);
  return path.join(directory.path, '$databaseName.sqlite');
}
