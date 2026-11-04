// 这个模块定义存储配置相关枚举值。

const StorageStatusEnum = {
  NORMAL: 0,
  DISABLE: 1
} as const;

const StorageTypeEnum = {
  LOCAL: 1,
  S3: 2
} as const;

type StorageType = (typeof StorageTypeEnum)[keyof typeof StorageTypeEnum];

const StorageTypeOptions = [
  { label: "local", value: StorageTypeEnum.LOCAL },
  { label: "objectStorage", value: StorageTypeEnum.S3 }
];

export { StorageStatusEnum, StorageTypeEnum, StorageTypeOptions };
export type { StorageType };
