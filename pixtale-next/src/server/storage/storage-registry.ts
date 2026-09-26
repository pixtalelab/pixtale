import { type StorageStrategy } from '@/server/storage/storage-types';

// 这个模块维护存储策略注册表，供各策略实现自行注册。

const strategyMap = new Map<number, () => StorageStrategy>();

// 把存储策略注册到 strategyMap。
function registerStorageStrategy(type: number, factory: () => StorageStrategy) {
  strategyMap.set(type, factory);
}

// 根据存储类型取出策略工厂。
function resolveStorageStrategy(type: number) {
  return strategyMap.get(type);
}

export { registerStorageStrategy, resolveStorageStrategy };
