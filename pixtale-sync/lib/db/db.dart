import 'package:pixtale_sync/db/database_path.dart';
import 'package:pixtale_sync/db/schema.dart';
import 'package:sqflite/sqflite.dart';

// SQLite 连接与结构初始化。结构版本变化时执行当前 schema，业务查询由 Service 负责。

/// 应用本地 SQLite 数据库。
class Db {
  /// 打开同一个持久化数据库，测试可注入连接。
  Db({DatabaseFactory? factory, String? databasePath})
    : _factory = factory ?? databaseFactory,
      _path = databasePath;

  /// 数据库插件工厂，测试使用内存 SQLite。
  final DatabaseFactory _factory;

  /// 指定数据库位置，未指定时使用平台默认数据目录。
  final String? _path;

  /// 共享正在打开或已打开的数据库连接。
  Future<Database>? _connection;

  /// 延迟打开并复用数据库。
  Future<Database> get database => _connection ??= _open();

  /// 关闭已打开的连接。
  Future<void> close() async {
    final connection = _connection;
    if (connection != null) {
      await (await connection).close();
      _connection = null;
    }
  }

  /// 打开数据库。结构版本只保存在 settings.schema_version。
  Future<Database> _open() async {
    final databasePath = _path ?? await getDatabaseFilePath();
    return _factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        // 前台与后台共享原生连接，避免不同连接的事务阻塞数据库工作线程。
        singleInstance: true,
        // 后台接入时不能回滚前台仍在执行的事务，调试模式也保持此行为。
        rollbackActiveTransactionOnOpen: false,
        onOpen: _ensureSchema,
      ),
    );
  }

  /// 结构版本不一致时执行当前 schema，并记下版本。
  Future<void> _ensureSchema(Database db) async {
    if (await _schemaVersion(db) == databaseVersion) return;
    await db.transaction((txn) async {
      for (final sql in databaseSchema) {
        try {
          await txn.execute(sql);
        } on DatabaseException catch (error) {
          // SQLite 的 ADD COLUMN 没有 IF NOT EXISTS，列已在时跳过这一条。
          if (!error.isDuplicateColumnError()) rethrow;
        }
      }
      await txn.rawUpdate(
        'UPDATE settings SET schema_version = ? WHERE id = 1',
        [databaseVersion],
      );
    });
  }

  /// 没有设置表、版本列或记录时视为尚未初始化。
  Future<int> _schemaVersion(DatabaseExecutor db) async {
    try {
      final rows = await db.rawQuery(
        'SELECT schema_version FROM settings WHERE id = 1',
      );
      if (rows.isEmpty) return 0;
      return rows.single['schema_version'] as int? ?? 0;
    } on DatabaseException catch (error) {
      if (error.isNoSuchTableError('settings') ||
          error.toString().contains('no such column')) {
        return 0;
      }
      rethrow;
    }
  }
}
