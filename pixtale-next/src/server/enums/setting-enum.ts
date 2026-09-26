// 这个模块定义系统设置相关枚举值。

const SettingSyncDeleteEnum = {
  ENABLE: 1,
  DISABLE: 2
} as const;

const SettingPhotoDedupEnum = {
  ENABLE: 1,
  DISABLE: 2
} as const;

const SettingPublicAlbumEnum = {
  DISABLE: 1,
  ENABLE: 2
} as const;

const SettingListStyleEnum = {
  MASONRY: 1,
  GRID: 2
} as const;

export { SettingSyncDeleteEnum, SettingPhotoDedupEnum, SettingPublicAlbumEnum, SettingListStyleEnum };
