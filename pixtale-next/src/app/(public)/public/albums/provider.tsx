"use client"

import { createContext, useContext } from "react"
import { type AlbumVo } from "@/server/entity/vo/album"

interface PublicAlbumContextValue {
  // initialAlbums 保存服务端查询到的公开相册。
  initialAlbums: AlbumVo[]
}

interface PublicAlbumProviderProps {
  // children 是公开相册页面内容。
  children: React.ReactNode
  // initialAlbums 保存服务端查询到的公开相册。
  initialAlbums: AlbumVo[]
}

const PublicAlbumContext = createContext<PublicAlbumContextValue | null>(null)

// 为公开相册页面提供服务端预取的相册数据。
function PublicAlbumProvider({ children, initialAlbums }: PublicAlbumProviderProps) {
  return (
    <PublicAlbumContext.Provider value={{ initialAlbums }}>
      {children}
    </PublicAlbumContext.Provider>
  )
}

// 读取公开相册页面的服务端预取数据。
function usePublicAlbumContext() {
  const context = useContext(PublicAlbumContext)

  if (!context) {
    throw new Error("usePublicAlbumContext must be used within PublicAlbumProvider.")
  }

  return context
}

export { PublicAlbumProvider, usePublicAlbumContext }
