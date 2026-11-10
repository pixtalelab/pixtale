import { readFile } from "node:fs/promises"
import convert from "heic-convert"

// 这个模块将 HEIC/HEIF 图片转换为供派生图处理使用的 JPEG，不修改原文件。

// 读取 HEIC/HEIF 文件并在内存中转换为 JPEG。
export async function convertHeicToJpeg(filePath: string): Promise<Buffer> {
  const buffer = await readFile(filePath)
  const jpeg = await convert({ buffer, format: "JPEG", quality: 0.95 })
  return Buffer.from(jpeg)
}
