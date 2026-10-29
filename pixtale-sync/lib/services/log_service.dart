import 'dart:async';

import 'package:pixtale_sync/db/db.dart';
import 'package:pixtale_sync/models/log.dart';

// 同步日志持久化、分页筛选和保留数量限制。

/// 保存同步事件，并通知日志页刷新。
class LogService {
  /// 创建可替换数据库的日志服务。
  LogService({Db? database}) : _providedDatabase = database;

  static final instance = LogService();
  final Db? _providedDatabase;

  /// 仅在实际读写日志时打开数据库，不影响任务页首次展示。
  late final Db _database = _providedDatabase ?? Db();

  /// 只在写入完成后广播变更，不要求页面持续轮询。
  final _changes = StreamController<void>.broadcast();

  /// 订阅新增和清空事件。
  Stream<void> get changes => _changes.stream;

  /// 后台服务写入日志后通知当前隔离区的页面重新读取。
  void notifyChanged() => _changes.add(null);

  /// 写入一次最终结果。status 保存 0 或 1，成功文案由调用方按当前语言传入。
  Future<void> add({
    required String albumName,
    required String event,
    required int status,
    String? message,
  }) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.insert('log', {
        'album_name': albumName,
        'event': event,
        'status': status,
        'message': status == LogStatus.success
            ? (message ?? 'Success')
            : (message ?? ''),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      final settings = await txn.query(
        'settings',
        columns: ['log_max_count'],
        where: 'id = ?',
        whereArgs: [1],
      );
      final maxCount = settings.single['log_max_count'] as int;
      if (maxCount > 0) {
        await txn.rawDelete(
          'DELETE FROM log WHERE id IN '
          '(SELECT id FROM log ORDER BY id DESC LIMIT -1 OFFSET ?)',
          [maxCount],
        );
      }
    });
    _changes.add(null);
  }

  /// 按最新优先分页查询。可按状态筛选，未指定时返回全部记录。
  Future<List<Log>> list({
    bool failuresOnly = false,
    int? status,
    int offset = 0,
    int limit = 100,
  }) async {
    final selected = status ?? (failuresOnly ? LogStatus.failure : null);
    final rows = await (await _database.database).query(
      'log',
      where: selected == null ? null : 'status = ?',
      whereArgs: selected == null ? null : [selected],
      orderBy: 'id DESC',
      offset: offset,
      limit: limit,
    );
    return rows
        .map(
          (row) => Log(
            id: row['id'] as int,
            albumName: row['album_name'] as String,
            event: row['event'] as String,
            status: row['status'] as int,
            message: row['message'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList();
  }

  /// 清空本地日志并通知列表刷新。
  Future<void> clear() async {
    await (await _database.database).delete('log');
    _changes.add(null);
  }
}
