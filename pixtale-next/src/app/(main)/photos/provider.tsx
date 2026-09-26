"use client"

import { createContext, useContext } from "react"
import { type PhotoVo } from "@/server/entity/vo/photo"

interface PhotoContextValue {
  // initialPhotos 保存服务端查询到的照片第一页。
  initialPhotos: PhotoVo[]
}

interface PhotoProviderProps {
  // children 是 /photo 路由下的页面内容。
  children: React.ReactNode
  // initialPhotos 保存服务端查询到的照片第一页。
  initialPhotos: PhotoVo[]
}

const PhotoContext = createContext<PhotoContextValue | null>(null)

// 读取 /photo 路由下服务端预取的照片数据。
function usePhotoContext() {
  const context = useContext(PhotoContext)

  if (!context) {
    throw new Error("usePhotoContext must be used within PhotoProvider.")
  }

  return context
}

// 给 /photo 路由下的客户端组件提供服务端预取照片。
function PhotoProvider({ children, initialPhotos }: PhotoProviderProps) {
  return (
    <PhotoContext.Provider value={{ initialPhotos }}>
      {children}
    </PhotoContext.Provider>
  )
}

export { PhotoProvider, usePhotoContext }
