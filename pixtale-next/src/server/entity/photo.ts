import { sql } from 'drizzle-orm';
import { integer, sqliteTable, text } from 'drizzle-orm/sqlite-core';
import { PhotoFavoriteEnum, PhotoStatusEnum } from '@/server/enums/photo-enum';

// 照片
export const photoTab = sqliteTable('photo', {
  photoId: text('photo_id').primaryKey().notNull(), // 照片id
  name: text('name').notNull(), // 名称
  thumbHash: text('thumb_hash'), // 模糊色
  checksum: text('checksum'), // 原图 SHA-1 校验和
  type: text('type').notNull(), // 照片类型
  typeDesc: text('type_desc').notNull(), // 类型描述
  size: integer('size').notNull(), // 文件大小
  width: integer('width'), // 宽度
  height: integer('height'), // 高度
  takenTime: text('taken_time'), // 拍摄时间，优先 Exif，无 Exif 时用前端传入的 lastModified
  createTime: text('create_time').default(sql`(strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))`).notNull(), // 创建时间 ISO UTC
  recycleTime: text('recycle_time'), // 回收时间
  userId: text('user_id').notNull(), // 创建用户id
  status: integer('status').default(PhotoStatusEnum.NORMAL).notNull(), // 状态 1正常 2回收
  favorite: integer('favorite').default(PhotoFavoriteEnum.NO).notNull(), // 收藏 1未收藏 2已收藏
  storageId: text('storage_id') // 存储id
});

export type Photo = typeof photoTab.$inferSelect;
export type PhotoInto = typeof photoTab.$inferInsert;
