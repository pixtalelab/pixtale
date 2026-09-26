"use client"

import { createContext, useContext } from "react"

import { type UserVo } from "@/server/entity/vo/user"

interface UserContextValue {
  // initialUserList 保存服务端查询到的用户列表。
  initialUserList: UserVo[]
}

interface UserProviderProps {
  // children 是 /user 路由下的页面内容。
  children: React.ReactNode
  // initialUserList 保存服务端查询到的用户列表。
  initialUserList: UserVo[]
}

const UserContext = createContext<UserContextValue | null>(null)

// 读取 /user 路由下服务端预取的用户列表。
function useUserContext() {
  const context = useContext(UserContext)

  if (!context) {
    throw new Error("useUserContext must be used within UserProvider.")
  }

  return context
}

// 给 /user 路由下的客户端组件提供服务端预取用户列表。
function UserProvider({ children, initialUserList }: UserProviderProps) {
  return (
    <UserContext.Provider value={{ initialUserList }}>
      {children}
    </UserContext.Provider>
  )
}

export { UserProvider, useUserContext }
