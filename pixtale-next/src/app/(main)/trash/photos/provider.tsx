"use client"

import { createContext, useContext } from "react"

import { type PhotoVo } from "@/server/entity/vo/photo"

interface TrashPhotoContextValue {
  // initialPhotos 保存服务端查询到的回收站照片第一页。
  initialPhotos: PhotoVo[]
}

interface TrashPhotoProviderProps {
  // children 是回收站照片页内容。
  children: React.ReactNode
  // initialPhotos 保存服务端查询到的回收站照片第一页。
  initialPhotos: PhotoVo[]
}

const TrashPhotoContext = createContext<TrashPhotoContextValue | null>(null)

// 读取回收站照片页服务端预取的照片数据。
function useTrashPhotoContext() {
  const context = useContext(TrashPhotoContext)

  if (!context) {
    throw new Error("useTrashPhotoContext must be used within TrashPhotoProvider.")
  }

  return context
}

// 给回收站照片页客户端组件提供服务端预取照片。
function TrashPhotoProvider({ children, initialPhotos }: TrashPhotoProviderProps) {
  return (
    <TrashPhotoContext.Provider value={{ initialPhotos }}>
      {children}
    </TrashPhotoContext.Provider>
  )
}

export { TrashPhotoProvider, useTrashPhotoContext }
