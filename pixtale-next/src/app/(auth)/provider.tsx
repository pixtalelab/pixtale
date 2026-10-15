"use client"

import { createContext, useContext } from "react"

interface AuthContextValue {
  // title 保存登录页显示的网站名称。
  title: string
  // publicAlbumEnabled 控制登录页是否显示返回公开页面的按钮。
  publicAlbumEnabled: boolean
}

interface AuthProviderProps {
  // children 是认证页面内容。
  children: React.ReactNode
  // title 是服务端读取的网站名称。
  title: string
  // publicAlbumEnabled 是服务端读取的公开相册开关。
  publicAlbumEnabled: boolean
}

const AuthContext = createContext<AuthContextValue | null>(null)

// 为认证页面提供网站名称。
function AuthProvider({ children, title, publicAlbumEnabled }: AuthProviderProps) {
  return (
    <AuthContext.Provider value={{ title, publicAlbumEnabled }}>
      {children}
    </AuthContext.Provider>
  )
}

// 读取认证页面的网站名称。
function useAuthContext() {
  const context = useContext(AuthContext)

  if (!context) {
    throw new Error("useAuthContext must be used within AuthProvider.")
  }

  return context
}

export { AuthProvider, useAuthContext }
