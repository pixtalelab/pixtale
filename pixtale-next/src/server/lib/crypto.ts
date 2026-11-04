import { createHash } from 'node:crypto';
import { createReadStream } from 'node:fs';

const encoder = new TextEncoder();

interface HashResult {
  salt: string;
  hash: string;
}

// 生成密码哈希使用的随机盐。
export function generateSalt(length: number = 16): string {
  const array = new Uint8Array(length);
  crypto.getRandomValues(array);
  return btoa(String.fromCharCode(...array));
}

// 生成带盐密码哈希。
export async function hashPassword(password: string): Promise<HashResult> {
  const salt = generateSalt();
  const hash = await genHashPassword(password, salt);
  return { salt, hash };
}

// 根据密码和盐生成 SHA-256 哈希。
export async function genHashPassword(password: string, salt: string): Promise<string> {
  const data = encoder.encode(salt + password);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return btoa(String.fromCharCode(...hashArray));
}

// 按文件路径流式计算 SHA-1 校验和。
export async function fileChecksumFromPath(filePath: string) {
  const hash = createHash('sha1');

  for await (const chunk of createReadStream(filePath)) {
    hash.update(chunk);
  }

  return hash.digest('hex');
}

// 校验输入密码是否匹配保存的哈希。
export async function verifyPassword(inputPassword: string, salt: string, storedHash: string): Promise<boolean> {
  const hash = await genHashPassword(inputPassword, salt);
  return hash === storedHash;
}
