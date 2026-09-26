import { StorageTypeEnum } from '@/server/enums/storage-enum';

// 这个模块提供 URL 处理相关工具方法。

// 格式化 HTTP URL，未配置时返回空字符串，未带协议时默认补 https。
function formatHttpUrl(input?: string | null) {
  const value = input?.trim();

  if (!value) {
    return '';
  }

  const httpUrl = /^https?:\/\//i.test(value) ? value : `https://${value}`;

  return httpUrl.replace(/\/+$/, '');
}

// 把存储 key 转成可请求的文件地址，路径片段逐段编码避免 # 等特殊字符截断 URL。
function toMediaUrl(key: string, domain?: string | null) {
  const encodedKey = key.split('/').map((segment) => encodeURIComponent(segment)).join('/');
  const base = formatHttpUrl(domain);

  return base ? `${base}/${encodedKey}` : `/media/${encodedKey}`;
}

export { formatHttpUrl, toMediaUrl };
