// 这个模块解析浏览器语言。

// 根据 Accept-Language 中优先级最高的浏览器语言选择中文或英语。
function resolveLocale(acceptLanguage: string | null | undefined) {
  const languages = (acceptLanguage ?? "")
    .split(",")
    .map((item) => {
      const [language, ...params] = item.trim().split(";")
      const qualityParam = params.find((param) => param.trim().startsWith("q="))

      return {
        language: language.toLowerCase(),
        quality: qualityParam ? Number(qualityParam.trim().slice(2)) : 1,
      }
    })
    .filter((item) => item.language && item.quality > 0)
    .sort((left, right) => right.quality - left.quality)

  const preferredLanguage = languages[0]?.language

  if (preferredLanguage === "zh" || preferredLanguage?.startsWith("zh-")) {
    return "zh"
  }

  return "en"
}

export { resolveLocale }
