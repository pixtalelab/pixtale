import { type Album } from '@/server/entity/album';

// 这个模块定义照片同步接口返回对象。

interface SyncCheckVo {
  name: string;
  size: number;
}

interface SyncGetConfigVo {
  album: Album[];
  storageExists: boolean;
}

export type { SyncCheckVo, SyncGetConfigVo };
