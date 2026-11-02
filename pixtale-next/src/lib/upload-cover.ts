import { getMediaType } from "@/lib/media"

export const COVER_SIZE = 400

// 视频不读取封面，图片解码并裁剪为上传面板使用的预览位图。
export async function createPhotoCover(file: File): Promise<ImageBitmap | null> {
  if (getMediaType(file).startsWith("video/")) {
    return null
  }

  const bitmap = await createImageBitmap(file)

  try {
    const size = Math.min(bitmap.width, bitmap.height)

    return await createImageBitmap(
      bitmap,
      Math.floor((bitmap.width - size) / 2),
      Math.floor((bitmap.height - size) / 2),
      size,
      size,
      {
        resizeWidth: COVER_SIZE,
        resizeHeight: COVER_SIZE,
        resizeQuality: "low",
      },
    )
  } finally {
    bitmap.close()
  }
}
