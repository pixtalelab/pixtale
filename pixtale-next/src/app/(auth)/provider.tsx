"use client"

import { createContext, useContext } from "react"

interface AuthContextValue {
  // title 保存登录页显示的网站名称。
  title: string
}

interface AuthProviderProps {
  // children 是认证页面内容。
  children: React.ReactNode
  // title 是服务端读取的网站名称。
  title: string
}

const AuthContext = createContext<AuthContextValue | null>(null)

// 为认证页面提供网站名称。
function AuthProvider({ children, title }: AuthProviderProps) {
  return (
    <AuthContext.Provider value={{ title }}>
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
