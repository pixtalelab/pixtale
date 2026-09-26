"use client"

import { createContext, useContext } from "react"

import { type PhotoVo } from "@/server/entity/vo/photo"

interface AlbumPhotoContextValue {
  // initialPhotos 保存服务端查询到的相册照片第一页。
  initialPhotos: PhotoVo[]
}

interface AlbumPhotoProviderProps {
  // children 是相册照片页内容。
  children: React.ReactNode
  // initialPhotos 保存服务端查询到的相册照片第一页。
  initialPhotos: PhotoVo[]
}

const AlbumPhotoContext = createContext<AlbumPhotoContextValue | null>(null)

// 读取相册照片页服务端预取的照片数据。
function useAlbumPhotoContext() {
  const context = useContext(AlbumPhotoContext)

  if (!context) {
    throw new Error("useAlbumPhotoContext must be used within AlbumPhotoProvider.")
  }

  return context
}

// 给相册照片页客户端组件提供服务端预取照片。
function AlbumPhotoProvider({ children, initialPhotos }: AlbumPhotoProviderProps) {
  return (
    <AlbumPhotoContext.Provider value={{ initialPhotos }}>
      {children}
    </AlbumPhotoContext.Provider>
  )
}

export { AlbumPhotoProvider, useAlbumPhotoContext }
