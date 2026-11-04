import { type Readable } from 'node:stream';
import { type Storage } from '@/server/entity/storage';

// 这个模块定义存储策略相关类型。

interface StorageStrategy {
  put(files: StorageUploadObject[], storage: Storage): Promise<void>;
  get(key: string, storage: Storage, range?: StorageRange): Promise<StorageObject>;
  delete(key: string | string[], storage: Storage): Promise<void>;
}

type ReadBody = Readable | ReadableStream;

interface StorageRange {
  start: number;
  end: number;
}

interface StorageObject {
  body: ReadBody;
  size: number;
  type: string;
  contentRange?: string;
  acceptRanges?: boolean;
}

interface StorageUploadObject {
  key: string;
  body?: Uint8Array;
  path?: string;
  type?: string;
  metadata?: string[][];
}

export type { ReadBody, StorageObject, StorageRange, StorageStrategy, StorageUploadObject };
