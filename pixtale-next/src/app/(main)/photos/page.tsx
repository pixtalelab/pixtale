'use client';
import dynamic from "next/dynamic"
import { AppSidebar } from "@/components/layout/app-sidebar"
import { Button } from "@/components/ui/button"
import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbList,
  BreadcrumbPage,
} from "@/components/ui/breadcrumb"
import { Separator } from "@/components/ui/separator"
import {
  SidebarProvider,
  SidebarInset,
  SidebarTrigger,
} from "@/components/ui/sidebar"
import { usePhotoList } from "@/hooks/use-photo-list"

import { useCallback, useEffect, useLayoutEffect, useState } from 'react'
import { PhotoMasonry } from "@/components/photo/photo-masonry"
import { PHOTO_LIST_PAGE_SIZE } from "@/server/const/global"
import { PhotoFavoriteEnum } from "@/server/enums/photo-enum"
import { photoFavorite, photoRecycle } from "@/request/photo"
import { albumAddPhoto } from "@/request/album"
import { usePhotoStore } from "@/store/photo-store"
import { Plus } from "lucide-react"
import { PhotoDateDrawer } from "@/components/photo/photo-date-drawer"
import { PhotoMasonrySkeleton } from "@/components/photo/photo-masonry-skeleton"
import { PhotoSearch } from "@/components/photo/photo-search"
import { usePhotoContext } from "./provider"
import { useApp } from "@/app/(main)/provider"
import { useTranslations } from "next-intl"

const AlbumSelectDialog = dynamic(
  () => import("@/components/album/album-select-dialog").then((mod) => mod.AlbumSelectDialog),
  { ssr: false }
)

const PhotoViewer = dynamic(
  () => import("@/components/photo/photo-viewer").then((mod) => mod.PhotoViewer),
  { ssr: false }
)

// 渲染照片列表页面。
export default function Page() {
  const t = useTranslations("photos")
  const { initialPhotos } = usePhotoContext()
  const { sidebarOpen, setSidebarOpen, refreshAlbums, listStyle } = useApp()
  // isBrowser 标记当前是否在浏览器环境，SSR 阶段显示骨架屏。
  const [isBrowser, setIsBrowser] = useState(false)
  const {
    photos,
    masonryKey,
    loadMorePhotos,
    refreshPhotoList,
    prependPhotos,
    removePhotos,
  } = usePhotoList({}, PHOTO_LIST_PAGE_SIZE, initialPhotos)
  const [modelPhotoIndex, setModelPhotoIndex] = useState(0)
  const [showPhotoViewer, setShowPhotoViewer] = useState(false)
  // albumDialogOpen 控制加入相册弹框的打开状态。
  const [albumDialogOpen, setAlbumDialogOpen] = useState(false)
  // albumPhotoIds 保存本次要加入相册的照片 id。
  const [albumPhotoIds, setAlbumPhotoIds] = useState<string[]>([])
  const openUpload = usePhotoStore((state) => state.openUpload)
  const uploadedPhotos = usePhotoStore((state) => state.uploadedPhotos)

  useLayoutEffect(() => {
    setIsBrowser(true)
  }, [])

  useEffect(() => {
    // 刷新最近页时禁用浏览器滚动恢复，并回到照片列表顶部。
    const previousScrollRestoration = window.history.scrollRestoration

    window.history.scrollRestoration = 'manual'
    window.scrollTo(0, 0)

    return () => {
      window.history.scrollRestoration = previousScrollRestoration
    }
  }, [])

  useEffect(() => {
    // 消费上传成功队列，把成功照片按 taken_time 插入列表对应位置。
    if (!uploadedPhotos.length) {
      return
    }

    const photosToAdd = usePhotoStore.getState().takeUploadedPhotos()

    if (!photosToAdd.length) {
      return
    }

    queueMicrotask(() => {
      prependPhotos(photosToAdd)
    })
  }, [prependPhotos, uploadedPhotos])

  // 打开照片详情 model。
  const openPhoto = useCallback((index: number) => {
    setModelPhotoIndex(index)
    setShowPhotoViewer(true)
  }, [])

  // 关闭照片详情 model。
  function closePhoto() {
    setShowPhotoViewer(false)
  }

  // 根据照片下标切换单张照片收藏状态。
  const changePhotoFavorite = useCallback((index: number, setFavorite: (favorite: boolean) => void) => {
    const photo = photos[index]
    const favorite = photo.favorite === PhotoFavoriteEnum.YES
      ? PhotoFavoriteEnum.NO
      : PhotoFavoriteEnum.YES

    photoFavorite({ photoIds: [photo.photoId], favorite }).then(() => {
      setFavorite(favorite === PhotoFavoriteEnum.YES)
      photo.favorite = favorite
    })
  }, [photos])

  // 批量回收选中的照片。
  const recyclePhotos = useCallback((photoIds: string[]) => {
    photoRecycle({ photoIds }).then(() => {
      removePhotos(photoIds)
    })
  }, [removePhotos])

  // 打开批量加入相册弹框。
  const openAlbumDialog = useCallback((photoIds: string[]) => {
    setAlbumPhotoIds(photoIds)
    setAlbumDialogOpen(true)
  }, [])

  // 选中相册后把照片加入相册。
  function changePhotoAlbum(albumIds: string[]) {
    albumAddPhoto({ albumIds, photoIds: albumPhotoIds }).then(() => {
      void refreshAlbums()
    })
  }

  // 保存当前选择的照片时间范围，并触发列表按拍摄时间筛选。
  function changePhotoTime(range: { startDate: Date, endDate: Date }) {
    refreshPhotoList({
      startTakenTime: range.startDate.toISOString(),
      endTakenTime: range.endDate.toISOString(),
    })
  }

  // 按照片名称或存储名称刷新照片列表。
  function searchPhotos(keyword: string, searchType: "photo" | "storage") {
    refreshPhotoList({
      keyword,
      searchType,
    })
  }

  return (
    <>
      <SidebarProvider open={sidebarOpen} onOpenChange={setSidebarOpen}>
        <AppSidebar />
        <SidebarInset>
          <header
            className="sticky top-0 z-20 flex h-12 shrink-0 items-center justify-between gap-2 bg-background transition-[width,height] ease-linear">
            <div className="flex min-w-0 items-center gap-2 px-4">
              <SidebarTrigger className="ml-1" />
              <Separator
                orientation="vertical"
                className="mr-2 data-vertical:h-4 data-vertical:self-auto"
              />
              <Breadcrumb>
                <BreadcrumbList>
                  <BreadcrumbItem>
                    <BreadcrumbPage className="flex items-center gap-2">
                      <span>{t("title")}</span>
                    </BreadcrumbPage>
                  </BreadcrumbItem>
                </BreadcrumbList>
              </Breadcrumb>
            </div>
            <div className="fixed right-0 top-0 flex h-12 items-center gap-1 px-3">
              <PhotoSearch onSearch={searchPhotos} />
              <PhotoDateDrawer onRangeChange={changePhotoTime} />
              <Button
                type="button"
                size="icon"
                variant="ghost"
                onClick={() => openUpload(null)}
              >
                <Plus />
              </Button>
            </div>
          </header>
          <div className="px-1">
            {isBrowser ? (
              <PhotoMasonry
                photos={photos}
                resetKey={masonryKey}
                sidebarOpen={sidebarOpen}
                listStyle={listStyle}
                onReachBottom={loadMorePhotos}
                onPhotoOpen={openPhoto}
                onPhotoFavorite={changePhotoFavorite}
                onPhotoDelete={recyclePhotos}
                onAlbumOpen={openAlbumDialog}
              />
            ) : (
              <PhotoMasonrySkeleton photos={initialPhotos} listStyle={listStyle} />
            )}
          </div>
        </SidebarInset>
      </SidebarProvider>
      <PhotoViewer
        open={showPhotoViewer}
        index={modelPhotoIndex}
        photos={photos}
        onBack={closePhoto}
        onBrowserBack={closePhoto}
      />
      <AlbumSelectDialog
        open={albumDialogOpen}
        onOpenChange={setAlbumDialogOpen}
        onAlbumSelect={changePhotoAlbum}
      />
    </>
  )
}
