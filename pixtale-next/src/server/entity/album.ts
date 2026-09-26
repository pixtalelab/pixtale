import { sql } from 'drizzle-orm';
import { integer, sqliteTable, text } from 'drizzle-orm/sqlite-core';

// 相册
export const albumTab = sqliteTable('album', {
  albumId: text('album_id').primaryKey(), // 相册id
  name: text('name').notNull(), // 相册名
  description: text('description').default('').notNull(), // 描述
  sort: integer('sort').default(0).notNull(), // 排序时间戳 值越大越靠前
  public: integer('public').default(1).notNull(), // 公开状态 1关闭 2开启
  createTime: text('create_time').default(sql`(strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))`).notNull(), // 创建时间 ISO UTC
  updateTime: text('update_time').default(sql`(strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))`).notNull(), // 更新时间 ISO UTC
  userId: text('user_id').notNull() // 创建用户id
});

export type Album = typeof albumTab.$inferSelect;
export type AlbumInto = typeof albumTab.$inferInsert;
