import sharp from "sharp"
import { rgbaToThumbHash } from "thumbhash"

// 这个模块负责服务端照片压缩和 thumbHash 生成。

sharp.cache(false)

// 用 sharp 生成 preview、thumbnail、thumbHash 和宽高。
export async function processPhotoImages(buffer: Buffer) {
  const metadata = await sharp(buffer).metadata()
  // EXIF Orientation 5 到 8 会交换宽高，保存摆正后的原图尺寸而非预览尺寸。
  const swapDimensions = (metadata.orientation ?? 1) >= 5 && (metadata.orientation ?? 1) <= 8
  const width = (swapDimensions ? metadata.height : metadata.width) ?? 0
  const height = (swapDimensions ? metadata.width : metadata.height) ?? 0
  // 摆正并缩小后再导出像素，避免持有完整原图的 raw 缓冲区。
  const { data, info } = await sharp(buffer)
    .autoOrient()
    .resize({ width: 1440, height: 1440, fit: "outside", withoutEnlargement: true })
    .raw()
    .toBuffer({ resolveWithObject: true })
  // 共享缩小后的像素，各派生图独立编码，避免重复有损压缩。
  const original = sharp(data, { raw: info })

  const previewBuffer = await original.clone()
    .jpeg({ quality: 80 })
    .toBuffer()

  const thumbnailBuffer = await original.clone()
    .resize({ width: 300, height: 300, fit: "outside", withoutEnlargement: true })
    .webp({ quality: 90 })
    .toBuffer()

  const hashImage = await original.clone()
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
