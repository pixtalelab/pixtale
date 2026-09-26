// 这个模块提供时间解析与展示格式化方法。

// 按语言分别缓存列表日期、详情日期时间和回收站相对时间格式化器。
const dateFormatters = new Map<string, Intl.DateTimeFormat>()
const dateTimeFormatters = new Map<string, Intl.DateTimeFormat>()
const relativeFormatters = new Map<string, Intl.RelativeTimeFormat>()

// 把 ISO 或数据库时间字符串解析成 Date。
function parseTime(value: string) {
  const date = new Date(value)

  if (Number.isNaN(date.getTime())) {
    return null
  }

  return date
}

// 把 ISO UTC 字符串解析成时间戳，兼容无 Z 的旧格式。
function parseUtcTime(value: string) {
  const text = value.trim()
  const hasTimezone = /(?:Z|[+-]\d{2}:?\d{2})$/i.test(text)
  const utcValue = hasTimezone ? text : `${text.replace(" ", "T")}Z`
  const time = new Date(utcValue).getTime()

  if (Number.isNaN(time)) {
    return null
  }

  return time
}

// 格式化照片拍摄时间为本地日期，用于列表展示。
function formatPhotoTakenDate(takenTime: string | null | undefined, locale = "zh") {
  if (!takenTime) {
    return null
  }

  const date = parseTime(takenTime)
  if (!date) {
    return null
  }

  let formatter = dateFormatters.get(locale)
  if (!formatter) {
    formatter = new Intl.DateTimeFormat(locale, {
      year: "numeric",
      month: "long",
      day: "numeric",
      weekday: "long",
    })
    dateFormatters.set(locale, formatter)
  }

  return formatter.formatToParts(date).map((part, index, parts) => {
    // 日期与星期直接相邻时补空格，保留语言原有的标点和顺序。
    const previous = parts[index - 1]
    const needsSpace = previous && (
      (part.type === "weekday" && !/\s$/.test(previous.value))
      || (previous.type === "weekday" && part.type !== "literal")
    )

    return `${needsSpace ? " " : ""}${part.value}`
  }).join("")
}

// 格式化照片拍摄时间为本地日期时间，用于详情展示。
function formatPhotoTakenDateTime(takenTime: string | null | undefined, locale = "zh") {
  if (!takenTime) {
    return null
  }

  const date = parseTime(takenTime)
  if (!date) {
    return takenTime
  }

  let formatter = dateTimeFormatters.get(locale)
  if (!formatter) {
    formatter = new Intl.DateTimeFormat(locale, {
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hour12: false,
    })
    dateTimeFormatters.set(locale, formatter)
  }

  return formatter.format(date)
}

// 格式化回收时间为相对描述。
function formatRecycleTime(recycleTime?: string | null, locale = "zh") {
  if (!recycleTime) {
    return ""
  }

  const time = parseUtcTime(recycleTime)
  if (time === null) {
    return ""
  }

  const diff = Math.max(0, Date.now() - time)
  const hour = 60 * 60 * 1000
  const day = 24 * hour

  if (diff < hour) {
    return locale === "zh" ? "1 小时内" : "Within 1 hour"
  }

  let formatter = relativeFormatters.get(locale)
  if (!formatter) {
    formatter = new Intl.RelativeTimeFormat(locale, { numeric: "always" })
    relativeFormatters.set(locale, formatter)
  }

  if (diff < day) {
    return formatter.format(-Math.floor(diff / hour), "hour")
  }

  return formatter.format(-Math.floor(diff / day), "day")
}

// 读取当前浏览器相对 UTC 的偏移分钟数，东八区为 480。
function getLocalTzOffsetMin() {
  return -new Date().getTimezoneOffset()
}

export { formatPhotoTakenDate, formatPhotoTakenDateTime, formatRecycleTime, getLocalTzOffsetMin, parseTime, parseUtcTime }
