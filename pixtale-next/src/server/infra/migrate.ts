import { SETTING_KEY } from '@/server/const/global';
import { type Setting } from '@/server/entity/setting';
import { SettingListStyleEnum, SettingPhotoDedupEnum, SettingPublicAlbumEnum, SettingSyncDeleteEnum } from '@/server/enums/setting-enum';
import { db } from '@/server/infra/db';

// 这个模块负责数据库表结构初始化。

// 系统设置默认值，仅用于建表种子数据。
const settingDefaults: Setting = {
  title: 'Pixtale',
  syncDelete: SettingSyncDeleteEnum.ENABLE,
  clearLast: 7,
  photoDedup: SettingPhotoDedupEnum.ENABLE,
  publicAlbum: SettingPublicAlbumEnum.DISABLE,
  listStyle: SettingListStyleEnum.MASONRY,
};

const createTableSqlList = [
  `CREATE TABLE IF NOT EXISTS user (
        user_id TEXT PRIMARY KEY,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        salt TEXT NOT NULL,
        avatar TEXT NOT NULL DEFAULT '',
        type INTEGER NOT NULL DEFAULT 2,
        sort INTEGER NOT NULL DEFAULT 0,
        status INTEGER NOT NULL DEFAULT 0,
        create_time TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
    )`,

  `CREATE TABLE IF NOT EXISTS album (
        album_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        sort INTEGER NOT NULL DEFAULT 0,
        public INTEGER NOT NULL DEFAULT 1,
        create_time TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
        update_time TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
        user_id TEXT NOT NULL
    )`,

  `CREATE TABLE IF NOT EXISTS photo (
        photo_id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        thumb_hash TEXT,
        checksum TEXT,
        type TEXT NOT NULL,
        type_desc TEXT NOT NULL,
        size INTEGER NOT NULL,
        width INTEGER,
        height INTEGER,
        taken_time TEXT,
        create_time TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
        recycle_time TEXT,
        user_id TEXT NOT NULL,
        status INTEGER NOT NULL DEFAULT 1,
        favorite INTEGER NOT NULL DEFAULT 1,
        storage_id TEXT
    )`,
  `CREATE INDEX IF NOT EXISTS idx_photo_user_status_taken_time
        ON photo (user_id, status, taken_time)`,
  `CREATE INDEX IF NOT EXISTS idx_photo_status_recycle_time
        ON photo (status, recycle_time)`,

  `CREATE TABLE IF NOT EXISTS file (
        file_id TEXT PRIMARY KEY NOT NULL,
        photo_id TEXT NOT NULL,
        key TEXT NOT NULL,
        type INTEGER NOT NULL,
        file_type TEXT NOT NULL,
        size INTEGER NOT NULL
    )`,
  `CREATE INDEX IF NOT EXISTS idx_file_photo_id ON file (photo_id)`,
  `CREATE UNIQUE INDEX IF NOT EXISTS idx_file_key ON file (key)`,

  `CREATE TABLE IF NOT EXISTS exif (
        photo_id TEXT PRIMARY KEY NOT NULL REFERENCES photo(photo_id) ON DELETE CASCADE,
        exif TEXT,
        latitude REAL,
        longitude REAL,
        altitude REAL
    )`,

  `CREATE TABLE IF NOT EXISTS album_photo (
        id TEXT PRIMARY KEY NOT NULL,
        photo_id TEXT NOT NULL,
        album_id TEXT NOT NULL
    )`,

  `CREATE TABLE IF NOT EXISTS storage (
        storage_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type INTEGER NOT NULL,
        domain TEXT,
        bucket TEXT,
        region TEXT,
        endpoint TEXT,
        access_key TEXT,
        secret_key TEXT,
        tg_token TEXT,
        tg_chat_id TEXT,
        user_id TEXT,
        sort INTEGER NOT NULL DEFAULT 0,
        status INTEGER DEFAULT 0
    )`,
  `INSERT OR IGNORE INTO storage (storage_id, name, type, sort, status)
        VALUES ('local', '本地存储', 1, 0, 0)`,

  `CREATE TABLE IF NOT EXISTS setting (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
    )`,
  `INSERT OR IGNORE INTO setting (key, value)
        VALUES ('${SETTING_KEY}', '${JSON.stringify(settingDefaults)}')`,

  `CREATE TABLE IF NOT EXISTS cache (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        expire_time INTEGER
    )`,
];

// 执行全部建表语句，已存在的表会自动跳过。
async function migrate(): Promise<void> {
  const runBatch = db.transaction(() => {
    for (const sql of createTableSqlList) {
      db.exec(sql);
    }
    // 为已有用户表补上新增排序字段；新建表已经包含该字段。
    const userColumns = db.prepare('PRAGMA table_info(user)').all() as { name: string }[];
    if (!userColumns.some((column) => column.name === 'sort')) {
      db.exec('ALTER TABLE user ADD COLUMN sort INTEGER NOT NULL DEFAULT 0');
    }
  });
  runBatch();
}

export { migrate };
