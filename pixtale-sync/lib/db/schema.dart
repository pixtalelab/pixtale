// 当前数据库结构。低于 22 的数据库删除旧表后按此结构重建。

/// 当前数据库结构版本。
const databaseVersion = 22;

/// 应用唯一设置记录的固定主键。
const settingsId = 'setting';

/// 应用当前使用的全部表。
const databaseSchema = <String>[
  '''
CREATE TABLE IF NOT EXISTS rule (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  name TEXT NOT NULL CHECK (length(trim(name)) > 0),
  sort_time INTEGER NOT NULL
);
''',
  'CREATE INDEX IF NOT EXISTS rule_user_id ON rule(user_id);',
  '''
CREATE TABLE IF NOT EXISTS rule_item (
  id TEXT PRIMARY KEY,
  pid TEXT NOT NULL REFERENCES rule(id),
  file_type TEXT NOT NULL CHECK (file_type IN ('photo', 'video', 'any')),
  file_min_size INTEGER NOT NULL CHECK (file_min_size >= 0),
  file_max_size INTEGER NOT NULL CHECK (file_max_size >= file_min_size),
  storage_id TEXT NOT NULL,
  created_at TEXT NOT NULL
);
''',
  'CREATE INDEX IF NOT EXISTS rule_item_pid ON rule_item(pid);',
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
  rule_id TEXT,
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
  id TEXT PRIMARY KEY,
  album_name TEXT NOT NULL,
  event TEXT NOT NULL,
  status INTEGER NOT NULL,
  message TEXT NOT NULL,
  created_at TEXT NOT NULL
);
''',
  '''
CREATE TABLE IF NOT EXISTS settings (
  id TEXT NOT NULL PRIMARY KEY CHECK (id = '$settingsId'),
  task_interval INTEGER NOT NULL DEFAULT 10,
  log_max_count INTEGER NOT NULL DEFAULT 500,
  task_status INTEGER NOT NULL DEFAULT 2,
  upload_concurrency INTEGER NOT NULL DEFAULT 1,
  last_sync_at TEXT,
  schema_version INTEGER NOT NULL DEFAULT 0,
  locale TEXT NOT NULL DEFAULT ''
);
''',
  "INSERT OR IGNORE INTO settings (id) VALUES ('$settingsId');",
];
