"use client"

import * as React from "react"
import { TOKEN_COOKIE_MAX_AGE } from "@/server/const/global"

type Theme = "light" | "dark"

const THEME_COOKIE_NAME = "theme"

type ThemeProviderProps = {
  children: React.ReactNode
  defaultTheme: Theme
}

type ThemeContextValue = {
  theme: Theme
  setTheme: (theme: Theme) => void
  toggleTheme: () => void
}

const ThemeContext = React.createContext<ThemeContextValue | null>(null)

// 读取全局主题状态。
function useTheme() {
  const context = React.useContext(ThemeContext)

  if (!context) {
    throw new Error("useTheme must be used within a ThemeProvider.")
  }

  return context
}

// 承载全站主题切换。
function ThemeProvider({ children, defaultTheme }: ThemeProviderProps) {
  const [theme, setThemeState] = React.useState<Theme>(defaultTheme)

  // 更新主题 class 和 cookie，让下次服务端渲染能恢复当前主题。
  const setTheme = React.useCallback((nextTheme: Theme) => {
    setThemeState(nextTheme)
    document.documentElement.classList.toggle("dark", nextTheme === "dark")
    document.documentElement.style.colorScheme = nextTheme
    document.cookie = `${THEME_COOKIE_NAME}=${nextTheme}; path=/; max-age=${TOKEN_COOKIE_MAX_AGE}`
  }, [])

  // 在亮色和暗色主题之间切换。
  const toggleTheme = React.useCallback(() => {
    setTheme(theme === "dark" ? "light" : "dark")
  }, [setTheme, theme])

  const value = React.useMemo<ThemeContextValue>(
    () => ({
      theme,
      setTheme,
      toggleTheme,
    }),
    [theme, setTheme, toggleTheme]
  )

  return (
    <ThemeContext.Provider value={value}>
      {children}
    </ThemeContext.Provider>
  )
}

export { ThemeProvider, useTheme }
export type { Theme }
