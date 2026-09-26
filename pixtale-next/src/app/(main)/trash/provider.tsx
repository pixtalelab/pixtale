"use client"

import { createContext, useContext } from "react"

import { type AlbumVo } from "@/server/entity/vo/album"

interface TrashContextValue {
  // initialAlbum 保存服务端查询到的回收站虚拟相册。
  initialAlbum: AlbumVo
}

interface TrashProviderProps {
  // children 是 /trash 路由下的页面内容。
  children: React.ReactNode
  // initialAlbum 保存服务端查询到的回收站虚拟相册。
  initialAlbum: AlbumVo
}

const TrashContext = createContext<TrashContextValue | null>(null)

// 读取 /trash 路由下服务端预取的回收站相册。
function useTrashContext() {
  const context = useContext(TrashContext)

  if (!context) {
    throw new Error("useTrashContext must be used within TrashProvider.")
  }

  return context
}

// 给 /trash 路由下的客户端组件提供服务端预取回收站相册。
function TrashProvider({ children, initialAlbum }: TrashProviderProps) {
  return (
    <TrashContext.Provider value={{ initialAlbum }}>
      {children}
    </TrashContext.Provider>
  )
}

export { TrashProvider, useTrashContext }
