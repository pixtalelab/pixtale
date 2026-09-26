import { type Storage } from '@/server/entity/storage';

// 这个模块定义存储配置接口返回对象。

interface StorageVo extends Storage {
  photoTotal: number;
  usedCapacity: number;
}

type StorageSelectVo = Pick<Storage, 'storageId' | 'name' | 'type'>;

interface StorageUsageVo {
  storageId: string;
  name: string;
  size: number;
}

export type { StorageSelectVo, StorageUsageVo, StorageVo };
