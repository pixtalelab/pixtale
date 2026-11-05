// 这个模块定义照片同步业务入参对象。

interface SyncCheckFileBo {
  name: string;
  size: number;
}

interface SyncCheckBo {
  albumId: string;
  files: SyncCheckFileBo[];
}

interface SyncConfigBo {
  albumName: string[];
  storageId?: string;
}

export type { SyncCheckBo, SyncCheckFileBo, SyncConfigBo };
