import 'package:flutter/foundation.dart';
import 'package:pixtale_sync/db/db.dart';
import 'package:pixtale_sync/models/rule.dart';
import 'package:pixtale_sync/models/user.dart';
import 'package:pixtale_sync/request/request.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// 管理本地模板及规则，创建模板与首条规则在同一事务中完成。
class RuleService {
  RuleService({Db? database}) : _database = database ?? Db();

  static final instance = RuleService();
  static final changes = ValueNotifier<int>(0);
  static const _uuid = Uuid();
  final Db _database;

  /// 登录事务中为尚无规则的账户创建默认规则，重复登录不改变已有规则。
  Future<void> ensureDefault(
    String userId, {
    required Transaction transaction,
  }) async {
    final existing = await transaction.query(
      'rule',
      columns: ['id'],
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    await transaction.insert('rule', {
      'id': id,
      'user_id': userId,
      'name': 'Default Rule',
      'sort_time': now.millisecondsSinceEpoch ~/ 1000,
    });
    await _insertItem(
      transaction,
      id,
      RuleFileType.any,
      0,
      200 * 1024 * 1024,
      'local',
      now.toIso8601String(),
    );
  }

  /// 返回当前账户的全部同步规则。
  Future<List<Rule>> list() => _read();

  /// 每次从数据库读取指定账户关联的规则及其有序子规则。
  Future<Rule?> get(String id, {User? account}) async =>
      (await _read(id: id, account: account)).firstOrNull;

  /// 在同一事务内读取规则及子项，防止编辑期间读取不完整的数据。
  Future<List<Rule>> _read({String? id, User? account}) async {
    return (await _database.database).transaction((txn) async {
      final userId = account?.userId ?? await _currentUserId(txn);
      if (userId == null) return <Rule>[];
      final rules = await txn.query(
        'rule',
        where: 'user_id = ?${id == null ? '' : ' AND id = ?'}',
        whereArgs: [userId, ?id],
        orderBy: 'sort_time ASC, rowid ASC',
      );
      final rows = await txn.rawQuery(
        '''
SELECT rule_item.* FROM rule_item
INNER JOIN rule ON rule.id = rule_item.pid
WHERE rule.user_id = ? ${id == null ? '' : 'AND rule.id = ?'}
ORDER BY rule_item.rowid ASC
''',
        [userId, ?id],
      );
      final items = <String, List<RuleItem>>{};
      for (final row in rows) {
        final item = RuleItem(
          id: row['id'] as String,
          pid: row['pid'] as String,
          fileType: RuleFileType.values.byName(row['file_type'] as String),
          fileMinSize: row['file_min_size'] as int,
          fileMaxSize: row['file_max_size'] as int,
          storageId: row['storage_id'] as String,
          createdAt: DateTime.parse(row['created_at'] as String),
        );
        (items[item.pid] ??= []).add(item);
      }
      return rules
          .map(
            (row) => Rule(
              id: row['id'] as String,
              userId: row['user_id'] as String,
              name: row['name'] as String,
              sortTime: row['sort_time'] as int,
              items: List.unmodifiable(items[row['id']] ?? <RuleItem>[]),
            ),
          )
          .toList();
    });
  }

  Future<String> add({
    required String name,
    required RuleFileType fileType,
    required int fileMinSize,
    required int fileMaxSize,
    required String storageId,
  }) async {
    if (name.trim().isEmpty) throw ArgumentError.value(name, 'name');
    _validate(fileMinSize, fileMaxSize, storageId);
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    final createdAt = now.toIso8601String();
    await (await _database.database).transaction((txn) async {
      final userId = await _requireUserId(txn);
      await txn.insert('rule', {
        'id': id,
        'user_id': userId,
        'name': name.trim(),
        'sort_time': now.millisecondsSinceEpoch ~/ 1000,
      });
      await _insertItem(
        txn,
        id,
        fileType,
        fileMinSize,
        fileMaxSize,
        storageId,
        createdAt,
      );
    });
    changes.value++;
    return id;
  }

  Future<void> addItem({
    required String pid,
    required RuleFileType fileType,
    required int fileMinSize,
    required int fileMaxSize,
    required String storageId,
  }) async {
    _validate(fileMinSize, fileMaxSize, storageId);
    await (await _database.database).transaction((txn) async {
      await _requireOwnedRule(txn, pid);
      await _insertItem(
        txn,
        pid,
        fileType,
        fileMinSize,
        fileMaxSize,
        storageId,
        DateTime.now().toUtc().toIso8601String(),
      );
    });
    changes.value++;
  }

  /// 只修改模板名称，保留规则、UUID 和排序时间。
  Future<void> rename({required String id, required String name}) async {
    if (name.trim().isEmpty) throw ArgumentError.value(name, 'name');
    await (await _database.database).transaction((txn) async {
      await _requireOwnedRule(txn, id);
      await txn.update(
        'rule',
        {'name': name.trim()},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    changes.value++;
  }

  /// 与任务卡片一致，取当前账户最小排序时间减一。
  Future<void> pin(String id) async {
    await (await _database.database).transaction((txn) async {
      await _requireOwnedRule(txn, id);
      final userId = await _requireUserId(txn);
      final rows = await txn.rawQuery(
        'SELECT MIN(sort_time) AS value FROM rule WHERE user_id = ?',
        [userId],
      );
      final minimum = rows.single['value'] as int? ?? 0;
      await txn.update(
        'rule',
        {'sort_time': minimum - 1},
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, userId],
      );
    });
    changes.value++;
  }

  /// 在同一事务中删除模板及全部子规则。
  Future<void> remove(String id) async {
    await (await _database.database).transaction((txn) async {
      await _requireOwnedRule(txn, id);
      await txn.delete('rule_item', where: 'pid = ?', whereArgs: [id]);
      final changed = await txn.delete(
        'rule',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (changed != 1) throw StateError('Rule does not exist');
    });
    changes.value++;
  }

  /// 原位修改规则，保留 UUID、创建时间及排列顺序。
  Future<void> updateItem({
    required String id,
    required String pid,
    required RuleFileType fileType,
    required int fileMinSize,
    required int fileMaxSize,
    required String storageId,
  }) async {
    _validate(fileMinSize, fileMaxSize, storageId);
    await (await _database.database).transaction((txn) async {
      await _requireOwnedRule(txn, pid);
      final changed = await txn.update(
        'rule_item',
        {
          'file_type': fileType.name,
          'file_min_size': fileMinSize,
          'file_max_size': fileMaxSize,
          'storage_id': storageId,
        },
        where: 'id = ? AND pid = ?',
        whereArgs: [id, pid],
      );
      if (changed != 1) throw StateError('Rule item does not exist');
    });
    changes.value++;
  }

  /// 只删除指定模板的规则，模板本身保留。
  Future<void> removeItem({required String id, required String pid}) async {
    await (await _database.database).transaction((txn) async {
      await _requireOwnedRule(txn, pid);
      final changed = await txn.delete(
        'rule_item',
        where: 'id = ? AND pid = ?',
        whereArgs: [id, pid],
      );
      if (changed != 1) throw StateError('Rule item does not exist');
    });
    changes.value++;
  }

  /// 在业务事务内解析当前账户，避免切换账户与规则写入交错。
  Future<String?> _currentUserId(DatabaseExecutor db) async {
    final rows = await db.query(
      'user',
      columns: ['user_id'],
      orderBy: 'rowid DESC',
      limit: 1,
    );
    return rows.firstOrNull?['user_id'] as String?;
  }

  Future<String> _requireUserId(DatabaseExecutor db) async {
    final id = await _currentUserId(db);
    if (id == null) throw const ApiException('Sign in first');
    return id;
  }

  Future<void> _requireOwnedRule(DatabaseExecutor db, String id) async {
    final userId = await _requireUserId(db);
    final rows = await db.query(
      'rule',
      columns: ['id'],
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Rule does not exist');
  }

  void _validate(int minimum, int maximum, String storageId) {
    if (minimum < 0 || maximum < minimum || maximum > 9007199254740991) {
      throw ArgumentError('Invalid file size range');
    }
    if (storageId.trim().isEmpty) throw ArgumentError('Storage is required');
  }

  Future<void> _insertItem(
    DatabaseExecutor db,
    String pid,
    RuleFileType type,
    int minimum,
    int maximum,
    String storageId,
    String createdAt,
  ) async {
    await db.insert('rule_item', {
      'id': _uuid.v4(),
      'pid': pid,
      'file_type': type.name,
      'file_min_size': minimum,
      'file_max_size': maximum,
      'storage_id': storageId,
      'created_at': createdAt,
    });
  }
}
