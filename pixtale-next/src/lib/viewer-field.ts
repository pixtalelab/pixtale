// 这个模块负责照片查看器侧栏信息列的回显格式化。

// 解析照片 exif JSON 字符串。
function parsePhotoExifJson(exif: string | null | undefined) {
  if (!exif) {
    return null
  }

  try {
    return JSON.parse(exif) as Record<string, unknown>
  } catch {
    return null
  }
}

const colorSpaceLabels: Record<number, string> = {
  1: "sRGB",
  2: "Adobe RGB",
}

// 仅使用 Exif ColorSpace 显示色彩空间，翻译未校准状态并清理末尾括号说明。
function formatColorSpace(exif: Record<string, unknown> | null | undefined, uncalibrated: string) {
  const colorSpace = exif?.ColorSpace
  if (!colorSpace) {
    return null
  }

  if (typeof colorSpace === "number") {
    return colorSpace === 65535 ? uncalibrated : colorSpaceLabels[colorSpace] ?? String(colorSpace)
  }

  const text = String(colorSpace).replace(/\s*\([^)]*\)$/, "").trim()
  if (text.toLowerCase() === "uncalibrated") {
    return uncalibrated
  }

  return text.toLowerCase() === "srgb" ? "sRGB" : text || null
}

// 从照片 exif JSON 字符串读取色彩空间。
export function getPhotoColorSpace(exif: string | null | undefined, uncalibrated = "Uncalibrated") {
  return formatColorSpace(parsePhotoExifJson(exif), uncalibrated)
}

type ViewerField = {
  key: "camera" | "lens" | "shutter" | "aperture" | "maxAperture" | "focalLength" | "focalLength35mm" | "iso"
  value: string
  wrap?: boolean
}

// 把 Exif 文本字段转成非空字符串。
function exifText(value: unknown) {
  if (value === undefined || value === null || value === "") {
    return null
  }

  const text = String(value).trim()
  return text || null
}

// 格式化 Exif 快门速度。
function formatExposureTime(value: unknown) {
  const text = exifText(value)
  if (!text) {
    return null
  }

  if (text.includes("/")) {
    return text.endsWith("s") ? text : `${text}s`
  }

  const seconds = Number(text)
  if (Number.isNaN(seconds)) {
    return text
  }

  if (seconds >= 1) {
    return `${Number.isInteger(seconds) ? seconds : seconds.toFixed(1)}s`
  }

  return `1/${Math.round(1 / seconds)}s`
}

// 格式化 Exif 光圈值。
function formatFNumber(value: unknown) {
  const text = exifText(value)
  if (!text) {
    return null
  }

  if (text.startsWith("f/")) {
    return text
  }

  const num = Number(text)
  if (Number.isNaN(num)) {
    return text
  }

  return `f/${Number.isInteger(num) ? num : num.toFixed(1)}`
}

// 格式化实际焦距和 35mm 等效焦距，保留小数并隐藏无效或未知的零值。
function formatFocalLength(value: unknown) {
  const text = exifText(value)
  if (!text) {
    return null
  }

  const num = Number(text.replace(/\s*mm$/i, ""))
  return Number.isFinite(num) && num > 0 ? `${num}mm` : null
}

// 从照片 exif JSON 字符串读取设备信息列表。
export function getPhotoDeviceParams(exif: string | null | undefined): ViewerField[] {
  const data = parsePhotoExifJson(exif)
  if (!data) {
    return []
  }

  const items: ViewerField[] = []
  const camera = [data.Make, data.Model].filter(Boolean).map(String).join(" ").trim()

  if (camera) {
    items.push({ key: "camera", value: camera, wrap: true })
  }

  const lens = exifText(data.LensModel)
  if (lens) {
    items.push({ key: "lens", value: lens, wrap: true })
  }

  const focalLength = formatFocalLength(data.FocalLength)
  if (focalLength) {
    items.push({ key: "focalLength", value: focalLength })
  }

  const focalLength35mm = formatFocalLength(data.FocalLengthIn35mmFormat)
  if (focalLength35mm) {
    items.push({ key: "focalLength35mm", value: focalLength35mm })
  }

  // ExifTool 默认已将 MaxApertureValue 的 APEX 编码转换为光圈值。
  const maxAperture = formatFNumber(data.MaxApertureValue)
  if (maxAperture) {
    items.push({ key: "maxAperture", value: maxAperture })
  }

  return items
}

// 从照片 exif JSON 字符串读取拍摄参数列表，焦距使用 35mm 等效值。
export function getPhotoShootingParams(exif: string | null | undefined): ViewerField[] {
  const data = parsePhotoExifJson(exif)
  if (!data) {
    return []
  }

  const items: ViewerField[] = []

  // 拍摄参数按焦距、光圈、快门、ISO 的顺序展示。
  const focalLength35mm = formatFocalLength(data.FocalLengthIn35mmFormat)
  if (focalLength35mm) {
    items.push({ key: "focalLength", value: focalLength35mm })
  }

  const fNumber = formatFNumber(data.FNumber)
  if (fNumber) {
    items.push({ key: "aperture", value: fNumber })
  }

  const exposureTime = formatExposureTime(data.ExposureTime)
  if (exposureTime) {
    items.push({ key: "shutter", value: exposureTime })
  }

  const iso = exifText(data.ISO)
  if (iso) {
    items.push({ key: "iso", value: iso })
  }

  return items
}

// 把 EXIF 偏移格式化成 UTC +8 / UTC +5:30。
function formatUtcOffset(offset: string) {
  const match = offset.trim().match(/^([+-])(\d{1,2})(?::(\d{2}))?$/)
  if (!match) {
    return null
  }

  const sign = match[1] === "-" ? "-" : "+"
  const hour = Number(match[2])
  const minute = Number(match[3] ?? "0")

  if (minute === 0) {
    return `UTC ${sign}${hour}`
  }

  return `UTC ${sign}${hour}:${String(minute).padStart(2, "0")}`
}

// 从照片 exif JSON 字符串读取时区展示文本，只显示统一的 UTC 偏移。
export function getPhotoTimezone(exif: string | null | undefined) {
  const data = parsePhotoExifJson(exif)

  const offset = exifText(data?.TimeZoneOffset)
    ?? exifText(data?.OffsetTimeOriginal)
    ?? exifText(data?.OffsetTime)

  return offset ? formatUtcOffset(offset) : null
}

// 从照片 exif JSON 字符串读取软件信息。
export function getPhotoSoftware(exif: string | null | undefined) {
  return exifText(parsePhotoExifJson(exif)?.Software)
}

// 把经纬度和海拔格式化成位置文本，例如 52.5187°N 13.3763°E 46 m。
export function formatPhotoLocation(
  latitude: number | null | undefined,
  longitude: number | null | undefined,
  altitude: number | null | undefined,
) {
  if (latitude == null || longitude == null) {
    return null
  }

  const latText = `${Math.abs(latitude).toFixed(4)}°${latitude >= 0 ? "N" : "S"}`
  const lngText = `${Math.abs(longitude).toFixed(4)}°${longitude >= 0 ? "E" : "W"}`
  let text = `${latText} ${lngText}`

  if (altitude != null) {
    text += ` ${Math.round(altitude)} m`
  }

  return text
}
