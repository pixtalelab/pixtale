"use client"

import { createContext, useContext } from "react"

interface PublicAlbumPhotoContextValue {
  // albumName 保存当前公开相册名称。
  albumName: string
}

interface PublicAlbumPhotoProviderProps {
  // children 是公开相册照片页面内容。
  children: React.ReactNode
  // albumName 保存当前公开相册名称。
  albumName: string
}

const PublicAlbumPhotoContext = createContext<PublicAlbumPhotoContextValue | null>(null)

// 为公开相册照片页提供相册名称。
function PublicAlbumPhotoProvider({ children, albumName }: PublicAlbumPhotoProviderProps) {
  return (
    <PublicAlbumPhotoContext.Provider value={{ albumName }}>
      {children}
    </PublicAlbumPhotoContext.Provider>
  )
}

// 读取当前公开相册名称。
function usePublicAlbumPhotoContext() {
  const context = useContext(PublicAlbumPhotoContext)

  if (!context) {
    throw new Error("usePublicAlbumPhotoContext must be used within PublicAlbumPhotoProvider.")
  }

  return context
}

export { PublicAlbumPhotoProvider, usePublicAlbumPhotoContext }
