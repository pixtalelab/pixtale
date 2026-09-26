import { getContext } from 'hono/context-storage';
import type { HonoEnv } from '@/server/hono/type';

// 这个模块读写当前请求登录用户 id。

// 把当前请求登录用户 id 写入 Hono 请求上下文。
function setUserId(userId: string) {
  getContext<HonoEnv>().set('userId', userId);
}

// 从 Hono 请求上下文读取当前请求登录用户 id。
function getUserId(): string {
  return getContext<HonoEnv>().get('userId') ?? '';
}

export { getUserId, setUserId };
