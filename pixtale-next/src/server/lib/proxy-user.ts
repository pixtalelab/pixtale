import { createHash } from 'crypto';
import { headers } from 'next/headers';

// 这个模块把固定字段名与 JWT_SECRET 哈希后作为请求头名，供 proxy 下发用户身份。

// 将 value + JWT_SECRET 转为请求头 key。
function toProxyHeaderKey(value: string): string {
  return createHash('sha256').update(`${value}${process.env.JWT_SECRET}`).digest('hex');
}

// 设置 userId、type 请求头。
function setProxyUserHeaders(requestHeaders: Headers, userId: string, type: number): void {
  requestHeaders.set(toProxyHeaderKey('user_id'), userId);
  requestHeaders.set(toProxyHeaderKey('type'), String(type));
}

// 从请求头读取 proxy 下发的用户 id 与 type。
async function getProxyUser(): Promise<{ userId: string; type: number } | null> {
  const h = await headers();
  const userId = h.get(toProxyHeaderKey('user_id'));
  const typeRaw = h.get(toProxyHeaderKey('type'));

  if (!userId || typeRaw == null || typeRaw === '') {
    return null;
  }

  const type = Number(typeRaw);

  if (!Number.isFinite(type)) {
    return null;
  }

  return { userId, type };
}

export {
  getProxyUser,
  setProxyUserHeaders,
  toProxyHeaderKey,
};
