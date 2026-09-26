// 这个模块定义文件相关枚举值。

// 文件类型：原图 / 高清图 / 缩图
const FileTypeEnum = {
  ORIGINAL: 1,
  PREVIEW: 2,
  THUMBNAIL: 3
} as const;

type FileType = (typeof FileTypeEnum)[keyof typeof FileTypeEnum];

export { FileTypeEnum };
export type { FileType };
