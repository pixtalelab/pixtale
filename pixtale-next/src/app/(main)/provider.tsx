"use client"

import dynamic from "next/dynamic"
import * as React from "react"
import { useEffect } from "react"
import { TooltipProvider } from "@/components/ui/tooltip"
import { albumList } from "@/request/album"
import { storageSelect } from "@/request/storage"
import { type UserInfoVo } from "@/server/entity/vo/user"
import { useIsMobile } from "@/hooks/use-mobile"
import { useAlbumStore } from "@/store/album-store"
import { usePhotoStore } from "@/store/photo-store"
import { useStorageStore } from "@/store/storage-store"
import { SettingListStyleEnum } from "@/server/enums/setting-enum"

const PhotoUploadDialog = dynamic(
  () => import("@/components/photo/photo-upload-dialog").then((mod) => mod.PhotoUploadDialog),
  { ssr: false }
)

type ProviderProps = {
  children: React.ReactNode
  defaultSidebarOpen: boolean
  initialUserInfo: UserInfoVo | null
  title: string
  listStyle: number
}

type AppContextValue = {
  title: string
  userInfo: UserInfoVo | null
  setUserInfo: React.Dispatch<React.SetStateAction<UserInfoVo | null>>
  sidebarOpen: boolean
  setSidebarOpen: React.Dispatch<React.SetStateAction<boolean>>
  refreshAlbums: () => Promise<void>
  refreshStorages: () => Promise<void>
  listStyle: number
}

const AppContext = React.createContext<AppContextValue | null>(null)

// 读取应用级全局状态，供布局内的客户端组件复用。
function useApp() {
  const context = React.useContext(AppContext)

  if (!context) {
    throw new Error("useApp must be used within a Provider.")
  }

  return context
}

// 承载主体区域的业务 Provider。
function Provider({ children, defaultSidebarOpen, initialUserInfo, title, listStyle }: ProviderProps) {
  // userInfo 保存当前登录用户信息，登录后可立即更新布局展示。
  const [userInfo, setUserInfo] = React.useState<UserInfoVo | null>(initialUserInfo)
  // sidebarOpen 保存侧边栏当前展开状态，供页面切换后继续复用。
  const [sidebarOpen, setSidebarOpen] = React.useState(defaultSidebarOpen)
  const setAlbums = useAlbumStore((state) => state.setAlbums)
  const setStorages = useStorageStore((state) => state.setStorages)
  const setInfoOpen = usePhotoStore((state) => state.setInfoOpen)
  // isMobile 判断当前是否为移动端视口。
  const isMobile = useIsMobile()

  useEffect(() => {
    setUserInfo(initialUserInfo)
  }, [initialUserInfo])

  // 查询正常存储配置并写入全局存储选项。
  useEffect(() => {
    void storageSelect().then((storages) => {
      setStorages(storages)
    })
  }, [setStorages])

  // 查询相册列表并写入全局相册选项。
  useEffect(() => {
    void albumList().then((albums) => {
      setAlbums(albums)
    })
  }, [setAlbums])

  // 移动端默认收起照片信息侧栏。
  useEffect(() => {
    if (isMobile) {
      setInfoOpen(false)
    }
  }, [isMobile, setInfoOpen])

  // 重新查询正常存储配置并写入全局存储选项。
  const refreshStorages = React.useCallback(() => {
    return storageSelect().then((storages) => {
      setStorages(storages)
    })
  }, [setStorages])

  // 重新查询相册列表并写入全局相册选项。
  const refreshAlbums = React.useCallback(() => {
    return albumList().then((albums) => {
      setAlbums(albums)
    })
  }, [setAlbums])

  const value = React.useMemo<AppContextValue>(
    () => ({
      title,
      userInfo,
      setUserInfo,
      sidebarOpen,
      setSidebarOpen,
      refreshAlbums,
      refreshStorages,
      listStyle: listStyle || SettingListStyleEnum.MASONRY,
    }),
    [title, userInfo, sidebarOpen, refreshAlbums, refreshStorages, listStyle]
  )

  return (
    <AppContext.Provider value={value}>
      <TooltipProvider>
        {children}
        <PhotoUploadDialog />
      </TooltipProvider>
    </AppContext.Provider>
  )
}

export { Provider, useApp }
