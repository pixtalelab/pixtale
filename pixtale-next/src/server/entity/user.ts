import { sql } from 'drizzle-orm';
import { integer, sqliteTable, text } from 'drizzle-orm/sqlite-core';
import { UserStatusEnum } from '@/server/enums/user-enum';

// 用户
export const userTab = sqliteTable('user', {
  userId: text('user_id').primaryKey(), // 用户id
  username: text('username').notNull().unique(), // 用户名
  password: text('password').notNull(), // 密码
  salt: text('salt').notNull(), // 盐
  avatar: text('avatar').default('').notNull(), // 头像
  type: integer('type').default(2).notNull(), // 类型 1管理员 2普通用户
  status: integer('status').default(UserStatusEnum.DEFAULT).notNull(), // 状态 0默认启用 1启用 2禁用
  createTime: text('create_time').default(sql`(strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))`).notNull() // 创建时间 ISO UTC
});

export type User = typeof userTab.$inferSelect;
export type UserInto = typeof userTab.$inferInsert;
