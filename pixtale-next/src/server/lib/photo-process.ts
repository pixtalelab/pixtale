import sharp from "sharp"
import { rgbaToThumbHash } from "thumbhash"

// 这个模块负责服务端照片压缩和 thumbHash 生成。

// 用 sharp 生成 preview、thumbnail、thumbHash 和宽高。
export async function processPhotoImages(buffer: Buffer) {
  // 先按 EXIF Orientation 摆正像素，避免 preview/thumbnail 方向错误。
  const orientedBuffer = await sharp(buffer).autoOrient().toBuffer()
  const metadata = await sharp(orientedBuffer).metadata()
  const width = metadata.width ?? 0
  const height = metadata.height ?? 0

  const previewBuffer = await sharp(orientedBuffer)
    .resize({ width: 1440, height: 1440, fit: "outside", withoutEnlargement: true })
    .jpeg({ quality: 80 })
    .toBuffer()

  const thumbnailBuffer = await sharp(previewBuffer)
    .resize({ width: 300, height: 300, fit: "outside", withoutEnlargement: true })
    .webp({ quality: 90 })
    .toBuffer()

  const hashImage = await sharp(thumbnailBuffer)
    .resize(100, 100, { fit: "inside" })
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true })

  const bytes = rgbaToThumbHash(hashImage.info.width, hashImage.info.height, hashImage.data)
  const thumbHash = Array.from(bytes)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("")

  return {
    previewBuffer,
    thumbnailBuffer,
    width,
    height,
    thumbHash,
  }
}
