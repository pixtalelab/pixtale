"use client"

import { MoonIcon, PaletteIcon, SunIcon } from "lucide-react"

import { Button } from "@/components/ui/button"
import { useTheme } from "@/app/provider"
import { useTranslations } from "next-intl"

// 渲染用户菜单里的主题切换按钮。
export function ThemeSwitcher() {
  const t = useTranslations("layout.theme")
  const { theme, toggleTheme } = useTheme()
  const isDark = theme === "dark"

  return (
    <div className="flex items-center justify-between gap-3 px-2  text-sm">
      <div className="flex items-center gap-2">
        <PaletteIcon className="size-4" />
        <span>{t("label")}</span>
      </div>
      <Button
        type="button"
        variant="ghost"
        size="icon"
        aria-label="Toggle theme"
        className="rounded-full"
        onClick={toggleTheme}
      >
        {isDark ? <SunIcon /> : <MoonIcon />}
      </Button>
    </div>
  )
}
