export const COVER_SIZE = 400

// Decode and crop a preview bitmap without encoding another image file.
export async function createPhotoCover(file: File): Promise<ImageBitmap> {
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
