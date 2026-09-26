"use client"

import { createContext, useContext } from "react"

import { type AlbumVo } from "@/server/entity/vo/album"

interface AlbumContextValue {
  // initialAlbums 保存服务端查询到的全部相册。
  initialAlbums: AlbumVo[]
}

interface AlbumProviderProps {
  // children 是 /album 路由下的页面内容。
  children: React.ReactNode
  // initialAlbums 保存服务端查询到的全部相册。
  initialAlbums: AlbumVo[]
}

const AlbumContext = createContext<AlbumContextValue | null>(null)

// 读取 /album 路由下服务端预取的相册数据。
function useAlbumContext() {
  const context = useContext(AlbumContext)

  if (!context) {
    throw new Error("useAlbumContext must be used within AlbumProvider.")
  }

  return context
}

// 给 /album 路由下的客户端组件提供服务端预取相册。
function AlbumProvider({ children, initialAlbums }: AlbumProviderProps) {
  return (
    <AlbumContext.Provider value={{ initialAlbums }}>
      {children}
    </AlbumContext.Provider>
  )
}

export { AlbumProvider, useAlbumContext }
