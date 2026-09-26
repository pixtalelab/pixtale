import enMessages from "../../../locales/server/en.json"
import zhMessages from "../../../locales/server/zh.json"
import { getContext } from "hono/context-storage"
import type { Context, Next } from "hono"
import type { HonoEnv } from "@/server/hono/type"
import { resolveLocale } from "@/lib/locale"

// 这个模块根据消息键和请求语言返回后端国际化文案。

type MessageKey = keyof typeof zhMessages

// 根据请求头解析语言并写入当前 Hono 请求上下文。
async function i18nMiddleware(c: Context<HonoEnv>, next: Next): Promise<void> {
  c.set("locale", resolveLocale(c.req.header("accept-language")))
  await next()
}

// 根据当前请求语言翻译消息，未配置的消息保持原文。
function t(message: string): string {
  const locale = getContext<HonoEnv>().get("locale") ?? "en"
  const messages: Record<MessageKey, string> = locale === "zh" ? zhMessages : enMessages
  return messages[message as MessageKey] ?? message
}

export { i18nMiddleware, t }
