// 当前数据库结构。版本不一致时执行这些语句。
// 已有表由 IF NOT EXISTS 跳过；之后给旧表补的列追加在建表语句后面。

/// 当前数据库结构版本。
const databaseVersion = 5;

/// 应用当前使用的全部表。
const databaseSchema = <String>[
  '''
CREATE TABLE IF NOT EXISTS user (
  user_id TEXT PRIMARY KEY,
  username TEXT NOT NULL,
  avatar TEXT NOT NULL DEFAULT '',
  type INTEGER NOT NULL DEFAULT 0,
  token TEXT NOT NULL,
  endpoint TEXT NOT NULL DEFAULT '',
  avatar_bytes BLOB
);
''',
  '''
CREATE TABLE IF NOT EXISTS storage (
  user_id TEXT NOT NULL,
  storage_id TEXT NOT NULL,
  name TEXT NOT NULL,
  type INTEGER NOT NULL,
  PRIMARY KEY (user_id, storage_id)
);
''',
  '''
CREATE TABLE IF NOT EXISTS task (
  user_id TEXT NOT NULL,
  album_id TEXT NOT NULL,
  sort_time INTEGER NOT NULL,
  completed_count INTEGER NOT NULL DEFAULT 0,
  storage_id TEXT,
  album_name TEXT NOT NULL DEFAULT '',
  photo_count INTEGER NOT NULL DEFAULT 0,
  cover BLOB,
  path TEXT,
  is_invalid INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, album_id)
);
''',
  '''
CREATE TABLE IF NOT EXISTS log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  album_name TEXT NOT NULL,
  event TEXT NOT NULL,
  status INTEGER NOT NULL,
  message TEXT NOT NULL,
  created_at TEXT NOT NULL
);
''',
  '''
CREATE TABLE IF NOT EXISTS settings (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  task_interval INTEGER NOT NULL DEFAULT 10,
  log_max_count INTEGER NOT NULL DEFAULT 500,
  task_status INTEGER NOT NULL DEFAULT 2,
  upload_concurrency INTEGER NOT NULL DEFAULT 1,
  last_sync_at TEXT,
  schema_version INTEGER NOT NULL DEFAULT 0,
  locale TEXT NOT NULL DEFAULT ''
);
''',
  'INSERT OR IGNORE INTO settings (id) VALUES (1);',
  // 旧库的 settings 在这条列加入之前就已建好，CREATE 不会补列。
  'ALTER TABLE settings ADD COLUMN schema_version INTEGER NOT NULL DEFAULT 0;',
  "ALTER TABLE settings ADD COLUMN locale TEXT NOT NULL DEFAULT '';",
  'DROP TABLE IF EXISTS window_state;',
];
