// 获取媒体 MIME 类型，在浏览器未识别 HEIC/HEIF 图片或视频类型时按扩展名补全。
export function getMediaType(file: { name: string; type: string }): string {
  if (file.type.startsWith("image/") || file.type.startsWith("video/")) {
    return file.type
  }

  const extension = file.name.split(".").pop()?.toLowerCase() ?? ""
  const mediaTypes: Record<string, string> = {
    heic: "image/heic",
    heif: "image/heif",
    hif: "image/heif",
    mp4: "video/mp4",
    m4v: "video/mp4",
    mov: "video/quicktime",
    webm: "video/webm",
    mkv: "video/x-matroska",
    avi: "video/x-msvideo",
    mpg: "video/mpeg",
    mpeg: "video/mpeg",
    "3gp": "video/3gpp",
    mts: "video/mp2t",
    m2ts: "video/mp2t",
  }

  return mediaTypes[extension] ?? file.type
}
