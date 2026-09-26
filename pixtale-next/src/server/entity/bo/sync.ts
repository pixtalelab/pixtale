// 这个模块定义照片同步业务入参对象。

interface SyncCheckBo {
  name: string;
  size: number;
}

interface SyncConfigBo {
  albumName: string[];
  storageId?: string;
}

export type { SyncCheckBo, SyncConfigBo };
