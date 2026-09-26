"use client"

import { createContext, useContext } from "react"

import { type StorageVo } from "@/server/entity/vo/storage"

interface StorageContextValue {
  // initialStorageList 保存服务端查询到的存储配置列表。
  initialStorageList: StorageVo[]
}

interface StorageProviderProps {
  // children 是 /storage 路由下的页面内容。
  children: React.ReactNode
  // initialStorageList 保存服务端查询到的存储配置列表。
  initialStorageList: StorageVo[]
}

const StorageContext = createContext<StorageContextValue | null>(null)

// 读取 /storage 路由下服务端预取的存储配置列表。
function useStorageContext() {
  const context = useContext(StorageContext)

  if (!context) {
    throw new Error("useStorageContext must be used within StorageProvider.")
  }

  return context
}

// 给 /storage 路由下的客户端组件提供服务端预取存储配置。
function StorageProvider({ children, initialStorageList }: StorageProviderProps) {
  return (
    <StorageContext.Provider value={{ initialStorageList }}>
      {children}
    </StorageContext.Provider>
  )
}

export { StorageProvider, useStorageContext }
