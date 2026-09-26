"use client"

import { createContext, useContext } from "react"

interface PublicContextValue {
  // title 保存公开首页顶部显示的网站名称。
  title: string
  // isLoggedIn 标记当前访客是否已有有效登录凭证。
  isLoggedIn: boolean
  // listStyle 保存公开照片列表的布局样式。
  listStyle: number
}

interface PublicProviderProps {
  // children 是公开首页页面内容。
  children: React.ReactNode
  // title 是服务端读取的网站名称。
  title: string
  // isLoggedIn 是服务端读取的当前登录状态。
  isLoggedIn: boolean
  // listStyle 是服务端读取的照片列表布局样式。
  listStyle: number
}

const PublicContext = createContext<PublicContextValue | null>(null)

// 为公开首页提供网站名称。
function PublicProvider({ children, title, isLoggedIn, listStyle }: PublicProviderProps) {
  return (
    <PublicContext.Provider value={{ title, isLoggedIn, listStyle }}>
      {children}
    </PublicContext.Provider>
  )
}

// 读取公开首页的网站名称。
function usePublicContext() {
  const context = useContext(PublicContext)

  if (!context) {
    throw new Error("usePublicContext must be used within PublicProvider.")
  }

  return context
}

export { PublicProvider, usePublicContext }
