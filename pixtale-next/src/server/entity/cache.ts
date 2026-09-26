import { integer, sqliteTable, text } from 'drizzle-orm/sqlite-core';

// 通用缓存表，value 存 JSON，expire_time 为过期时间戳（秒），空表示不过期。

export const cacheTab = sqliteTable('cache', {
  key: text('key').primaryKey(), // 缓存键
  value: text('value').notNull(), // 缓存值 JSON
  expireTime: integer('expire_time'), // 过期时间 unix 秒，null 不过期
});

export type Cache = typeof cacheTab.$inferSelect;
export type CacheInto = typeof cacheTab.$inferInsert;
