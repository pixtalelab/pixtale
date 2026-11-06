import { index, sqliteTable, text, uniqueIndex } from 'drizzle-orm/sqlite-core';

// 这个模块定义相册和照片的关联表结构。

// 相册照片关联。同一相册不能重复关联同一张照片。
export const albumPhotoTab = sqliteTable('album_photo', {
  id: text('id').primaryKey().notNull(), // 关联id
  photoId: text('photo_id').notNull(), // 照片id
  albumId: text('album_id').notNull() // 相册id
}, (table) => [
  uniqueIndex('idx_album_photo_album_id_photo_id').on(table.albumId, table.photoId),
  index('idx_album_photo_photo_id').on(table.photoId),
]);

export type AlbumPhoto = typeof albumPhotoTab.$inferSelect;
export type AlbumPhotoInto = typeof albumPhotoTab.$inferInsert;
