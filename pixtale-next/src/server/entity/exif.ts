import { real, sqliteTable, text } from 'drizzle-orm/sqlite-core';

// 照片 Exif，与 photo 一对一。

export const exifTab = sqliteTable('exif', {
  photoId: text('photo_id').primaryKey().notNull(), // 照片 id
  exif: text('exif'), // Exif JSON 字符串
  latitude: real('latitude'), // 纬度
  longitude: real('longitude'), // 经度
  altitude: real('altitude') // 海拔（米）
});

export type Exif = typeof exifTab.$inferSelect;
export type ExifInto = typeof exifTab.$inferInsert;
