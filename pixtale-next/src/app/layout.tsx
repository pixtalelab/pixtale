import { cookies } from "next/headers"
import { Geist } from "next/font/google"
import { type Metadata } from "next"
import { getLocale } from "next-intl/server"

import { ThemeProvider, type Theme } from "@/app/provider"
import { Toaster } from "@/components/ui/sonner"
import { settingService } from "@/server/service/setting-service"
import "./globals.css"

const geist = Geist({
  subsets: ["latin"],
  variable: "--font-geist",
  display: "swap",
})

const THEME_COOKIE_NAME = "theme"

// 使用系统设置中的网站名称生成页面元数据。
export async function generateMetadata(): Promise<Metadata> {
  const { title } = await settingService.get()

  return {
    title,
    icons: {
      icon: "/assets/logo.png",
      apple: "/assets/logo.png",
    },
  }
}

interface RootLayoutProps {
  children: React.ReactNode
}

// 最简根布局：html/body、字体，以及主题 Provider。
export default async function RootLayout({ children }: RootLayoutProps) {
  const cookieStore = await cookies()
  // 仅显式 light 时启用浅色，其余默认深色。
  const defaultTheme: Theme = cookieStore.get(THEME_COOKIE_NAME)?.value === "light" ? "light" : "dark"
  const locale = await getLocale()

  return (
    <html lang={locale} className={`${geist.variable} ${defaultTheme}`} suppressHydrationWarning>
      <head />
      <body>
        <ThemeProvider defaultTheme={defaultTheme}>
          {children}
          <Toaster position="bottom-right" />
        </ThemeProvider>
      </body>
    </html>
  )
}
