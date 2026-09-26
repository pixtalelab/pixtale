// 这个模块定义存储配置接口入参对象。

interface StorageSetTopBo {
  storageId: string;
}

interface StorageToggleStatusBo {
  storageId: string;
}

interface StorageDeleteBo {
  storageId: string;
}

export type { StorageDeleteBo, StorageSetTopBo, StorageToggleStatusBo };
