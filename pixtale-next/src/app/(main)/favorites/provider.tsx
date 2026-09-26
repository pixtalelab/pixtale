"use client"

import { createContext, useContext } from "react"

import { type PhotoVo } from "@/server/entity/vo/photo"

interface FavoriteContextValue {
  // initialPhotos 保存服务端查询到的收藏照片第一页。
  initialPhotos: PhotoVo[]
}

interface FavoriteProviderProps {
  // children 是收藏页内容。
  children: React.ReactNode
  // initialPhotos 保存服务端查询到的收藏照片第一页。
  initialPhotos: PhotoVo[]
}

const FavoriteContext = createContext<FavoriteContextValue | null>(null)

// 读取收藏页服务端预取的照片数据。
function useFavoriteContext() {
  const context = useContext(FavoriteContext)

  if (!context) {
    throw new Error("useFavoriteContext must be used within FavoriteProvider.")
  }

  return context
}

// 给收藏页客户端组件提供服务端预取照片。
function FavoriteProvider({ children, initialPhotos }: FavoriteProviderProps) {
  return (
    <FavoriteContext.Provider value={{ initialPhotos }}>
      {children}
    </FavoriteContext.Provider>
  )
}

export { FavoriteProvider, useFavoriteContext }
