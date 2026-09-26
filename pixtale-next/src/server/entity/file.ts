import { integer, sqliteTable, text } from 'drizzle-orm/sqlite-core';
import { FileTypeEnum } from '@/server/enums/file-enum';

// 照片文件，一张照片对应原图 / 高清图 / 缩图多条记录。

export const fileTab = sqliteTable('file', {
  fileId: text('file_id').primaryKey().notNull(), // 文件id
  photoId: text('photo_id').notNull(), // 照片id
  key: text('key').notNull(), // 存储key
  type: integer('type').notNull().default(FileTypeEnum.ORIGINAL), // 文件类型 1原图 2高清图 3缩图
  fileType: text('file_type').notNull(), // MIME 类型
  size: integer('size').notNull() // 文件大小
});

export type File = typeof fileTab.$inferSelect;
export type FileInto = typeof fileTab.$inferInsert;
