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

// 把 Exif 色彩空间字段格式化成可读文本。
function formatColorSpace(exif: Record<string, unknown> | null | undefined, uncalibrated: string) {
  if (!exif) {
    return null
  }

  const profile = exif.ProfileDescription
  if (profile !== undefined && profile !== null && profile !== "") {
    return String(profile)
  }

  const colorSpace = exif.ColorSpace
  if (colorSpace === undefined || colorSpace === null || colorSpace === "") {
    return null
  }

  if (typeof colorSpace === "number") {
    return colorSpace === 65535 ? uncalibrated : colorSpaceLabels[colorSpace] ?? String(colorSpace)
  }

  return String(colorSpace)
}

// 从照片 exif JSON 字符串读取色彩空间。
export function getPhotoColorSpace(exif: string | null | undefined, uncalibrated = "Uncalibrated") {
  return formatColorSpace(parsePhotoExifJson(exif), uncalibrated)
}

type ViewerField = {
  key: "camera" | "lens" | "shutter" | "aperture" | "focalLength" | "iso"
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

// 格式化 Exif 焦距。
function formatFocalLength(value: unknown) {
  const text = exifText(value)
  if (!text) {
    return null
  }

  if (text.endsWith("mm")) {
    return text
  }

  const num = Number(text)
  if (Number.isNaN(num)) {
    return text
  }

  return `${Number.isInteger(num) ? num : num.toFixed(1)}mm`
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

  const lens = [data.LensMake, data.LensModel].filter(Boolean).map(String).join(" ").trim()
  if (lens) {
    items.push({ key: "lens", value: lens, wrap: true })
  }

  return items
}

// 从照片 exif JSON 字符串读取拍摄参数列表。
export function getPhotoShootingParams(exif: string | null | undefined): ViewerField[] {
  const data = parsePhotoExifJson(exif)
  if (!data) {
    return []
  }

  const items: ViewerField[] = []

  const exposureTime = formatExposureTime(data.ExposureTime)
  if (exposureTime) {
    items.push({ key: "shutter", value: exposureTime })
  }

  const fNumber = formatFNumber(data.FNumber)
  if (fNumber) {
    items.push({ key: "aperture", value: fNumber })
  }

  const focalLength = formatFocalLength(data.FocalLength)
  if (focalLength) {
    items.push({ key: "focalLength", value: focalLength })
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
