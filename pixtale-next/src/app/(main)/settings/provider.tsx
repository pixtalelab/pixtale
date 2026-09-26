"use client"

import { createContext, useContext } from "react"

import { type Setting } from "@/server/entity/setting"

interface SettingContextValue {
  // initialSetting 保存服务端查询到的系统设置。
  initialSetting: Setting
}

interface SettingProviderProps {
  // children 是 /settings 路由下的页面内容。
  children: React.ReactNode
  // initialSetting 保存服务端查询到的系统设置。
  initialSetting: Setting
}

const SettingContext = createContext<SettingContextValue | null>(null)

// 读取 /settings 路由下服务端预取的系统设置。
function useSettingContext() {
  const context = useContext(SettingContext)

  if (!context) {
    throw new Error("useSettingContext must be used within SettingProvider.")
  }

  return context
}

// 给 /settings 路由下的客户端组件提供服务端预取系统设置。
function SettingProvider({ children, initialSetting }: SettingProviderProps) {
  return (
    <SettingContext.Provider value={{ initialSetting }}>
      {children}
    </SettingContext.Provider>
  )
}

export { SettingProvider, useSettingContext }
