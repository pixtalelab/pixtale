import { createReadStream } from 'node:fs';
import fs from 'node:fs/promises';
import path from 'node:path';
import { type StorageObject, type StorageStrategy, type StorageUploadObject } from '@/server/storage/storage-types';
import { registerStorageStrategy } from '@/server/storage/storage-registry';
import { type Storage } from '@/server/entity/storage';
import { StorageTypeEnum } from '@/server/enums/storage-enum';

// 这个模块实现本地存储策略。

class LocalStorageStrategy implements StorageStrategy {

  // 生成本地文件绝对路径。
  private getLocalPath(key: string) {
    const root = path.resolve(process.cwd(), 'data');
    const normalizedKey = key.replace(/^\/+/, '');
    const filePath = path.resolve(root, normalizedKey);
    const relativePath = path.relative(root, filePath);

    if (relativePath.startsWith('..') || path.isAbsolute(relativePath)) {
      throw new Error('文件路径无效');
    }

    return filePath;
  }

  // 保存多个文件到本地。
  async put(files: StorageUploadObject[], storage: Storage): Promise<void> {

    void storage;

    await Promise.all(files.map(async (file) => {
      const filePath = this.getLocalPath(file.key);
      await fs.mkdir(path.dirname(filePath), { recursive: true });
      await fs.writeFile(filePath, file.body);
    }));
  }

  // 从本地读取文件并以流的方式返回。
  async get(key: string, storage: Storage): Promise<StorageObject> {
    void storage;
    const filePath = this.getLocalPath(key);
    const { size } = await fs.stat(filePath);

    return {
      body: createReadStream(filePath),
      size,
      type: ''
    };
  }

  // 从本地删除一个或多个文件。
  async delete(key: string | string[], storage: Storage) {
    void storage;
    const keys = Array.isArray(key) ? key : [key];
    await Promise.all(keys.map((item) => fs.rm(this.getLocalPath(item), { force: true })));
  }
}

registerStorageStrategy(StorageTypeEnum.LOCAL, () => new LocalStorageStrategy());

export { LocalStorageStrategy };
