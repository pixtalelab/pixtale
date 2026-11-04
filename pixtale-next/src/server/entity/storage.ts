import { integer, sqliteTable, text } from 'drizzle-orm/sqlite-core';

// 存储
export const storageTab = sqliteTable('storage', {
  storageId: text('storage_id').primaryKey(), // 存储id
  name: text('name').notNull(), // 存储名称
  type: integer('type').notNull(), // 存储类型 1本地 2对象存储
  domain: text('domain'), // 访问域名
  bucket: text('bucket'), // 桶名称
  region: text('region'), // 区域
  endpoint: text('endpoint'), // 接入端点
  accessKey: text('access_key'), // access
  secretKey: text('secret_key'), // secret
  userId: text('user_id'), // 创建用户id
  sort: integer('sort').default(0).notNull(), // 排序时间戳 值越大越靠前
  status: integer('status').default(0) // 状态 0启用 1禁用
});

export type Storage = typeof storageTab.$inferSelect;
export type StorageInto = typeof storageTab.$inferInsert;
