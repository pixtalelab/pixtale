import { headers } from "next/headers"
import { getRequestConfig } from "next-intl/server"
import { resolveLocale } from "@/lib/locale"

// 这个模块根据浏览器语言为当前请求加载翻译消息。

// 把语言文件中的点分隔扁平键转换为 next-intl 使用的嵌套消息。
function nestMessages(messages: Record<string, string>): Record<string, unknown> {
  const result: Record<string, unknown> = {}

  for (const [key, message] of Object.entries(messages)) {
    const parts = key.split(".")
    let target = result

    for (const part of parts.slice(0, -1)) {
      target[part] ??= {}
      target = target[part] as Record<string, unknown>
    }

    target[parts[parts.length - 1]] = message
  }

  return result
}

// 读取浏览器语言并返回对应翻译消息。
export default getRequestConfig(async () => {
  const requestHeaders = await headers()
  const locale = resolveLocale(requestHeaders.get("accept-language"))
  const flatMessages = locale === "en"
    ? (await import("../../locales/web/en.json")).default
    : (await import("../../locales/web/zh.json")).default

  return {
    locale,
    messages: nestMessages(flatMessages),
  }
})
