// 这个模块从原图 Exif 读取拍摄元数据。

import { mkdtemp, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { ExifDateTime, ExifTool, type Tags } from "exiftool-vendored"

// 启用时区推断的 exiftool 实例。
const exiftool = new ExifTool({
  backfillTimezones: true,
  inferTimezoneFromDatestamps: true,
})

const exifPickKeys = [
  "DateTimeOriginal",
  "CreateDate",
  "OffsetTimeOriginal",
  "OffsetTimeDigitized",
  "OffsetTime",
  "Make",
  "Model",
  "LensMake",
  "LensModel",
  "Software",
  "ExposureTime",
  "FNumber",
  "FocalLength",
  "ISO",
  "ColorSpace",
  "ProfileDescription",
] as const

const readArgs = [
  ...exifPickKeys.map((key) => `-${key}`),
  "-GPSLatitude",
  "-GPSLongitude",
  "-GPSAltitude",
  "-GPSAltitudeRef",
]

// 把 exiftool 字段值转成可 JSON 序列化的值。
function tagValueToJson(value: unknown) {
  if (value instanceof ExifDateTime) {
    return value.toString() ?? value.toExifString()
  }

  return value
}

// 把 UTC 偏移分钟数格式化成 +08:00。
function formatTzOffset(minutes: number) {
  const sign = minutes >= 0 ? "+" : "-"
  const abs = Math.abs(minutes)
  const hour = Math.floor(abs / 60)
  const minute = abs % 60

  return `${sign}${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`
}

// 从拍摄时间字段提取时区名称与偏移。
function getTimezoneInfo(tags: Tags) {
  const candidates = [tags.DateTimeOriginal, tags.CreateDate]

  for (const value of candidates) {
    if (!(value instanceof ExifDateTime) || !value.hasZone) {
      continue
    }

    const info: Record<string, unknown> = {}

    if (value.zoneName) {
      info.TimeZone = value.zoneName
    } else if (typeof value.zone === "string") {
      info.TimeZone = value.zone
    }

    if (value.tzoffsetMinutes != null) {
      info.TimeZoneOffset = formatTzOffset(value.tzoffsetMinutes)
    }

    if (value.inferredZone) {
      info.TimeZoneInferred = true
    }

    if (Object.keys(info).length) {
      return info
    }
  }

  return null
}

// 从 exiftool 结果提取拍摄时间并转成 ISO UTC。
function getTakenTime(tags: Tags) {
  const candidates = [tags.DateTimeOriginal, tags.CreateDate]

  for (const value of candidates) {
    if (!value) {
      continue
    }

    if (value instanceof ExifDateTime) {
      const iso = value.toISOString()
      if (iso) {
        return iso
      }
      continue
    }

    if (typeof value === "string") {
      const iso = ExifDateTime.fromEXIF(value)?.toISOString()
      if (iso) {
        return iso
      }
    }
  }

  return null
}

// 把 GPS 坐标字段解析成十进制度数。
function getCoordinate(value: unknown) {
  if (value === undefined || value === null || value === "") {
    return null
  }

  if (typeof value === "number") {
    return Number.isFinite(value) ? value : null
  }

  const num = Number(value)
  return Number.isNaN(num) ? null : num
}

// 从 GPS 海拔字段解析海拔（米）。
function getAltitude(tags: Tags) {
  const num = getCoordinate(tags.GPSAltitude)
  if (num === null) {
    return null
  }

  const ref = tags.GPSAltitudeRef
  if (ref === 1) {
    return -num
  }

  return num
}

// 把 exiftool 指定字段转成 JSON 字符串。
function buildExifJson(tags: Tags) {
  const data: Record<string, unknown> = {}
  const record = tags as Record<string, unknown>

  for (const key of exifPickKeys) {
    const value = record[key]
    if (value !== undefined && value !== null && value !== "") {
      data[key] = tagValueToJson(value)
    }
  }

  if (!data.ProfileDescription) {
    const profile = record.ProfileDescription ?? record["ICC_Profile:ProfileDescription"]
    if (profile !== undefined && profile !== null && profile !== "") {
      data.ProfileDescription = tagValueToJson(profile)
    }
  }

  const timezone = getTimezoneInfo(tags)
  if (timezone) {
    Object.assign(data, timezone)

    // 原图未写入 OffsetTime* 时，用推断结果补全常用偏移字段。
    if (timezone.TimeZoneOffset && !data.OffsetTimeOriginal) {
      data.OffsetTimeOriginal = timezone.TimeZoneOffset
    }
  }

  return Object.keys(data).length ? JSON.stringify(data) : null
}

// 从原图 Exif 读取拍摄时间、经纬度与 exif JSON 字符串。
export async function readPhotoExifFromBuffer(input: ArrayBuffer | Buffer) {
  const source = input instanceof Buffer ? input : Buffer.from(input)
  const dir = await mkdtemp(join(tmpdir(), "album-exif-"))
  const filePath = join(dir, "photo")

  try {
    await writeFile(filePath, source)
    const tags = await exiftool.read(filePath, { readArgs })

    return {
      takenTime: getTakenTime(tags),
      latitude: getCoordinate(tags.GPSLatitude),
      longitude: getCoordinate(tags.GPSLongitude),
      altitude: getAltitude(tags),
      exif: buildExifJson(tags),
    }
  } catch (error) {
    console.error("[ExifError] failed to read EXIF:", error)
    return {
      takenTime: null,
      latitude: null,
      longitude: null,
      altitude: null,
      exif: null,
    }
  } finally {
    await rm(dir, { recursive: true, force: true })
  }
}
