import { sqliteTable, text } from 'drizzle-orm/sqlite-core';

// 系统设置，整份配置以 JSON 存在 value 中。

export const settingTab = sqliteTable('setting', {
  key: text('key').primaryKey(), // 配置键
  value: text('value').notNull() // 配置 JSON
});

export type Setting = {
  title: string; // 网站名称
  syncDelete: number; // 同步删除 1开启 2关闭
  clearLast: number; // 回收站照片多少天后自动清理
  photoDedup: number; // 照片去重 1开启 2关闭
  publicAlbum: number; // 公开相册 1关闭 2开启
  listStyle: number; // 照片列表样式 1瀑布流 2网格
};
