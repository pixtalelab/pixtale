import { randomUUID } from 'node:crypto';

// 这个模块提供业务 ID 生成方法。

// 生成随机 UUID v4 业务 ID。
function createId(): string {
  return randomUUID();
}

export { createId };
