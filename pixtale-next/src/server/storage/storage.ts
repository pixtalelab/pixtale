import { type Storage } from '@/server/entity/storage';
import { StorageStatusEnum } from '@/server/enums/storage-enum';
import BizError from '@/server/error/biz-error';
import { storageService } from '@/server/service/storage-service';
import '@/server/storage/local-storage';
import '@/server/storage/s3-storage';
import '@/server/storage/telegram-storage';
import { resolveStorageStrategy } from '@/server/storage/storage-registry';
import { type StorageObject, type StorageStrategy, type StorageUploadObject } from '@/server/storage/storage-types';

// 这个模块按策略选择存储实现。

// 根据存储 id 查询可用存储配置。
async function getStorage(storageId: string): Promise<Storage> {
  const storageList = await storageService.getStorageList();
  const fileStorage = storageList.find((item) => item.storageId === storageId);

  if (!fileStorage) {
    throw new BizError('storage.notFound');
  }

  return fileStorage;
}

// 校验存储是否可用，禁用则抛出异常。
function assertStorageEnabled(fileStorage: Storage) {
  if (fileStorage.status === StorageStatusEnum.DISABLE) {
    throw new BizError('storage.disabled');
  }
}

// 根据传入的存储配置类型创建存储策略，删除场景下无效类型返回 null。
function createStorageStrategy(storage: Storage, skipInvalid = false): StorageStrategy | null {
  const strategy = resolveStorageStrategy(storage.type);

  if (!strategy) {
    if (skipInvalid) {
      return null;
    }

    throw new Error('存储类型无效');
  }

  return strategy();
}

const storage = {

  // 根据存储 id 查询配置、选择策略并保存多个文件。
  async put(files: StorageUploadObject[], storageId: string): Promise<void> {
    const fileStorage = await getStorage(storageId);
    assertStorageEnabled(fileStorage);
    return createStorageStrategy(fileStorage)!.put(files, fileStorage);
  },

  // 根据存储 id 查询配置、选择策略并读取文件。
  async get(key: string, storageId: string): Promise<StorageObject> {
    const fileStorage = await getStorage(storageId);
    return createStorageStrategy(fileStorage)!.get(key, fileStorage);
  },

  // 根据存储 id 查询配置、选择策略并删除文件，无效类型直接跳过。
  async delete(key: string | string[], storageId: string): Promise<void> {
    const fileStorage = await getStorage(storageId);
    const strategy = createStorageStrategy(fileStorage, true);

    if (!strategy) {
      return;
    }

    return strategy.delete(key, fileStorage);
  }
};

export { storage };
export { registerStorageStrategy } from '@/server/storage/storage-registry';
export type { ReadBody, StorageObject, StorageStrategy, StorageUploadObject } from '@/server/storage/storage-types';
