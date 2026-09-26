import { sign, verify } from 'hono/jwt';
import { type JWTPayload } from 'hono/utils/jwt/types';
import BizError from "@/server/error/biz-error";

// 这个模块负责登录 JWT 的生成与校验。

interface LoginTokenPayload extends JWTPayload {
  userId: string;
  uuid: string;
}

// 生成登录成功后返回给前端的 JWT。
async function createLoginToken(userId: string, uuid: string): Promise<string> {
  const secret = process.env.JWT_SECRET;

  if (!secret) {
    throw new BizError('system.jwtSecretMissing');
  }

  const now = Math.floor(Date.now() / 1000);
  const payload: LoginTokenPayload = {
    userId,
    uuid,
    iat: now,
    exp: now + 60 * 60 * 24 * 30
  };

  return sign(payload, secret);
}

// 校验登录 JWT，验证失败时返回空。
async function verifyLoginToken(token: string | undefined): Promise<LoginTokenPayload | null> {
  const secret = process.env.JWT_SECRET;

  if (!secret) {
    throw new BizError('system.jwtSecretMissing');
  }

  try {
    const payload = await verify(token as string, secret, 'HS256');
    return payload as LoginTokenPayload;
  } catch {
    return null;
  }
}

export { createLoginToken, verifyLoginToken };
export type { LoginTokenPayload };
