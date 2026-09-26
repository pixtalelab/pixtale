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

// 把哈希二进制转成 hex 字符串。
function hashToHex(buffer: ArrayBuffer) {
  return Array.from(new Uint8Array(buffer))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

// 计算文件 SHA-1 校验和。
export async function fileChecksum(file: Blob) {
  const hashBuffer = await crypto.subtle.digest('SHA-1', await file.arrayBuffer());
  return hashToHex(hashBuffer);
}

// 校验输入密码是否匹配保存的哈希。
export async function verifyPassword(inputPassword: string, salt: string, storedHash: string): Promise<boolean> {
  const hash = await genHashPassword(inputPassword, salt);
  return hash === storedHash;
}
