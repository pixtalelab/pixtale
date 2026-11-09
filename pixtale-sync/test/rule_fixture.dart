import 'package:pixtale_sync/db/db.dart';
import 'package:pixtale_sync/models/rule.dart';

/// 创建带固定 ID 的测试规则，默认允许全部测试文件。
Rule testRule({
  required String id,
  required String name,
  String userId = 'user',
  String storageId = 'local-id',
  int minimum = 0,
  int maximum = 9007199254740991,
  RuleFileType type = RuleFileType.any,
}) => Rule(
  id: id,
  userId: userId,
  name: name,
  sortTime: 1,
  items: [
    RuleItem(
      id: '$id-item',
      pid: id,
      fileType: type,
      fileMinSize: minimum,
      fileMaxSize: maximum,
      storageId: storageId,
      createdAt: DateTime.utc(2026),
    ),
  ],
);

/// 保存显式指定的测试规则与子项。
Future<void> saveTestRule(Db database, Rule rule) async {
  final db = await database.database;
  await db.insert('rule', {
    'id': rule.id,
    'user_id': rule.userId,
    'name': rule.name,
    'sort_time': rule.sortTime,
  });
  for (final item in rule.items) {
    await db.insert('rule_item', {
      'id': item.id,
      'pid': rule.id,
      'file_type': item.fileType.name,
      'file_min_size': item.fileMinSize,
      'file_max_size': item.fileMaxSize,
      'storage_id': item.storageId,
      'created_at': item.createdAt.toIso8601String(),
    });
  }
}
