'use client';
import dynamic from "next/dynamic"
import { AppSidebar } from "@/components/layout/app-sidebar"
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
import { PHOTO_LIST_PAGE_SIZE } from "@/server/const/global"
import { PhotoFavoriteEnum } from "@/server/enums/photo-enum"

import { useCallback, useEffect, useLayoutEffect, useState } from 'react'
import { PhotoMasonry } from "@/components/photo/photo-masonry"
import { photoFavorite, photoRecycle } from "@/request/photo"
import { albumAddPhoto } from "@/request/album"
import { useFavoriteContext } from "./provider"
import { useApp } from "@/app/(main)/provider"
import { PhotoDateDrawer } from "@/components/photo/photo-date-drawer"
import { PhotoMasonrySkeleton } from "@/components/photo/photo-masonry-skeleton"
import { useTranslations } from "next-intl"

const AlbumSelectDialog = dynamic(
  () => import("@/components/album/album-select-dialog").then((mod) => mod.AlbumSelectDialog),
  { ssr: false }
)

const PhotoViewer = dynamic(
  () => import("@/components/photo/photo-viewer").then((mod) => mod.PhotoViewer),
  { ssr: false }
)

export default function Page() {
  const t = useTranslations("favorites")
  const { initialPhotos } = useFavoriteContext()
  const { sidebarOpen, setSidebarOpen, refreshAlbums, listStyle } = useApp()
  // isBrowser 标记当前是否在浏览器环境，SSR 阶段显示骨架屏。
  const [isBrowser, setIsBrowser] = useState(false)
  const {
    photos,
    masonryKey,
    loadMorePhotos,
    refreshPhotoList,
    removePhotos,
  } = usePhotoList({ favorite: PhotoFavoriteEnum.YES }, PHOTO_LIST_PAGE_SIZE, initialPhotos)
  const [modelPhotoIndex, setModelPhotoIndex] = useState(0)
  const [showPhotoViewer, setShowPhotoViewer] = useState(false)
  // albumDialogOpen 控制加入相册弹框的打开状态。
  const [albumDialogOpen, setAlbumDialogOpen] = useState(false)
  // albumPhotoIds 保存本次要加入相册的照片 id。
  const [albumPhotoIds, setAlbumPhotoIds] = useState<string[]>([])

  useLayoutEffect(() => {
    setIsBrowser(true)
  }, [])

  useEffect(() => {
    // 刷新收藏页时禁用浏览器滚动恢复，并回到照片列表顶部。
    const previousScrollRestoration = window.history.scrollRestoration

    window.history.scrollRestoration = 'manual'
    window.scrollTo(0, 0)

    return () => {
      window.history.scrollRestoration = previousScrollRestoration
    }
  }, [])

  // 打开收藏照片详情 model。
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

  // 批量回收选中的收藏照片。
  const recyclePhotos = useCallback((photoIds: string[]) => {
    photoRecycle({ photoIds }).then(() => {
      removePhotos(photoIds)
    })
  }, [removePhotos])

  // 打开收藏照片批量加入相册弹框。
  const openAlbumDialog = useCallback((photoIds: string[]) => {
    setAlbumPhotoIds(photoIds)
    setAlbumDialogOpen(true)
  }, [])

  // 选中相册后把收藏照片加入相册。
  function changePhotoAlbum(albumIds: string[]) {
    albumAddPhoto({ albumIds, photoIds: albumPhotoIds }).then(() => {
      void refreshAlbums()
    })
  }

  // 保存当前选择的收藏照片时间范围，并触发列表按拍摄时间筛选。
  function changePhotoTime(range: { startDate: Date, endDate: Date }) {
    refreshPhotoList({
      favorite: PhotoFavoriteEnum.YES,
      startTakenTime: range.startDate.toISOString(),
      endTakenTime: range.endDate.toISOString(),
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
              <SidebarTrigger className="-ml-1" />
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
            <div className="fixed left-[calc(100vw-3.5rem)]  md:left-[calc(100vw-4rem)] top-0 flex h-12 items-center gap-1 px-4">
              <PhotoDateDrawer favorite={PhotoFavoriteEnum.YES} onRangeChange={changePhotoTime} />
            </div>
          </header>
          <div className="px-1 md:pl-1 md:pr-0">
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
