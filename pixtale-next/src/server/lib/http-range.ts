import { type StorageRange } from "@/server/storage/storage-types"

// 这个模块解析播放器使用的单段 HTTP 字节范围。

// 解析闭合、开放及后缀范围，无效或超出文件大小时返回 null。
export function parseByteRange(value: string, size: number): StorageRange | null {
  const match = /^bytes=(\d*)-(\d*)$/i.exec(value.trim())
  if (!match || (!match[1] && !match[2]) || size <= 0) {
    return null
  }

  const first = Number(match[1])
  const last = Number(match[2])
  if (!Number.isSafeInteger(first) || !Number.isSafeInteger(last)) {
    return null
  }

  // bytes=-N 表示文件末尾 N 个字节，超出文件大小时返回整个文件范围。
  const start = match[1] ? first : Math.max(0, size - last)
  const end = match[1] && match[2] ? Math.min(last, size - 1) : size - 1
  if (start >= size || start > end || (!match[1] && last === 0)) {
    return null
  }

  return { start, end }
}
