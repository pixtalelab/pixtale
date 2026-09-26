// 这个模块定义照片相关枚举值。

const PhotoStatusEnum = {
  NORMAL: 1,
  DELETE: 2
} as const;

const PhotoFavoriteEnum = {
  NO: 1,
  YES: 2
} as const;

export { PhotoStatusEnum, PhotoFavoriteEnum };
