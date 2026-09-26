import { DeleteObjectsCommand, GetObjectCommand, PutObjectCommand, type PutObjectCommandInput, S3Client } from '@aws-sdk/client-s3';
import { type ReadBody, type StorageObject, type StorageStrategy, type StorageUploadObject } from '@/server/storage/storage-types';
import { registerStorageStrategy } from '@/server/storage/storage-registry';
import { type Storage } from '@/server/entity/storage';
import { StorageTypeEnum } from '@/server/enums/storage-enum';
import BizError from '@/server/error/biz-error';
import { formatHttpUrl } from '@/lib/url';

// 这个模块实现 S3 存储策略。

class S3StorageStrategy implements StorageStrategy {

  // 根据存储配置创建 S3 客户端。
  private createClient(storage: Storage) {
    const region = storage.region?.trim() || 'auto';
    const endpoint = formatHttpUrl(storage.endpoint);
    const accessKeyId = storage.accessKey?.trim();
    const secretAccessKey = storage.secretKey?.trim();

    if (!endpoint || !accessKeyId || !secretAccessKey) {
      throw new BizError('s3.configIncomplete');
    }

    return new S3Client({
      region,
      endpoint,
      forcePathStyle: true,
      credentials: {
        accessKeyId,
        secretAccessKey
      }
    });
  }

  // 把自定义元数据项转成 S3 PutObject 参数。
  private buildPutOptions(metadata: string[][]) {
    const options: Partial<PutObjectCommandInput> = {};

    for (const [name, value] of metadata) {
      if (name === 'Cache-Control') {
        options.CacheControl = value;
        continue;
      }

      if (name === 'Content-Type') {
        options.ContentType = value;
        continue;
      }

      if (name === 'Content-Disposition') {
        options.ContentDisposition = value;
        continue;
      }

      options.Metadata = {
        ...options.Metadata,
        [name]: value,
      };
    }

    return options;
  }

  // 保存多个文件到 S3。
  async put(files: StorageUploadObject[], storage: Storage): Promise<void> {
    const client = this.createClient(storage);
    const bucket = storage.bucket?.trim();

    if (!bucket) {
      throw new BizError('s3.bucketRequired');
    }

    for (const file of files) {
      const putOptions = file.metadata ? this.buildPutOptions(file.metadata) : {};

      await client.send(new PutObjectCommand({
        Bucket: bucket,
        Key: file.key,
        Body: file.body,
        ...putOptions,
        ...(file.type ? { ContentType: file.type } : {}),
      }));
    }
  }

  // 从 S3 读取文件并转成响应 body。
  async get(key: string, storage: Storage): Promise<StorageObject> {
    const client = this.createClient(storage);
    const bucket = storage.bucket?.trim();

    if (!bucket) {
      throw new BizError('s3.bucketRequired');
    }

    const res = await client.send(new GetObjectCommand({
      Bucket: bucket,
      Key: key
    }));

    if (!res.Body) {
      throw new BizError('s3.readFailed');
    }

    return {
      body: res.Body as ReadBody,
      size: res.ContentLength ?? 0,
      type: res.ContentType ?? ''
    };
  }

  // 从 S3 删除一个或多个文件。
  async delete(key: string | string[], storage: Storage): Promise<void> {
    const keys = Array.isArray(key) ? key : [key];

    if (!keys.length) {
      return;
    }

    const client = this.createClient(storage);
    const bucket = storage.bucket?.trim();

    if (!bucket) {
      throw new BizError('s3.bucketRequired');
    }

    await client.send(new DeleteObjectsCommand({
      Bucket: bucket,
      Delete: {
        Objects: keys.map((item) => ({
          Key: item
        })),
        Quiet: true
      }
    }));
  }
}

registerStorageStrategy(StorageTypeEnum.S3, () => new S3StorageStrategy());

export { S3StorageStrategy };
