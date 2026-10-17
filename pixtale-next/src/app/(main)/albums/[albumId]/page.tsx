'use client';
import dynamic from "next/dynamic"
import { useParams, useRouter } from "next/navigation"
import { useTranslations } from "next-intl"

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
} from "@/components/ui/sidebar"
import { usePhotoList } from "@/hooks/use-photo-list"

import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react'
import { PhotoMasonry } from "@/components/photo/photo-masonry"
import { PHOTO_LIST_PAGE_SIZE } from "@/server/const/global"
import { PhotoFavoriteEnum } from "@/server/enums/photo-enum"
import { photoFavorite, photoRecycle } from "@/request/photo"
import { albumAddPhoto, albumRemovePhoto } from "@/request/album"
import { useAlbumStore } from "@/store/album-store"
import { usePhotoStore } from "@/store/photo-store"
import { ArrowLeftIcon, PlusIcon } from "lucide-react"
import { useAlbumPhotoContext } from "./provider"
import { useApp } from "@/app/(main)/provider"
import { PhotoDateDrawer } from "@/components/photo/photo-date-drawer"
import { PhotoMasonrySkeleton } from "@/components/photo/photo-masonry-skeleton"
import { PhotoSearch } from "@/components/photo/photo-search"

const AlbumSelectDialog = dynamic(
  () => import("@/components/album/album-select-dialog").then((mod) => mod.AlbumSelectDialog),
  { ssr: false }
)

const PhotoViewer = dynamic(
  () => import("@/components/photo/photo-viewer").then((mod) => mod.PhotoViewer),
  { ssr: false }
)

export default function Page() {
  const t = useTranslations("albums")
  const router = useRouter()
  const { albumId } = useParams<{ albumId: string }>()
  const { initialPhotos } = useAlbumPhotoContext()
  const { sidebarOpen, setSidebarOpen, refreshAlbums, listStyle } = useApp()
  const currentAlbumName = useAlbumStore((state) => state.currentAlbumName)
  const increaseRefreshKey = useAlbumStore((state) => state.increaseRefreshKey)
  const albumIdRef = useRef(albumId)
  // isBrowser 标记当前是否在浏览器环境，SSR 阶段显示骨架屏。
  const [isBrowser, setIsBrowser] = useState(false)
  const {
    photos,
    masonryKey,
    loadMorePhotos,
    refreshPhotoList,
    prependPhotos,
    removePhotos,
  } = usePhotoList({ albumId }, PHOTO_LIST_PAGE_SIZE, initialPhotos)
  const [modelPhotoIndex, setModelPhotoIndex] = useState(0)
  const [showPhotoViewer, setShowPhotoViewer] = useState(false)
  // albumDialogOpen 控制加入相册弹框的打开状态。
  const [albumDialogOpen, setAlbumDialogOpen] = useState(false)
  // albumPhotoIds 保存本次要加入其他相册的照片 id。
  const [albumPhotoIds, setAlbumPhotoIds] = useState<string[]>([])
  const openUpload = usePhotoStore((state) => state.openUpload)
  const uploadedPhotos = usePhotoStore((state) => state.uploadedPhotos)

  useLayoutEffect(() => {
    setIsBrowser(true)
  }, [])

  useEffect(() => {
    // 刷新相册照片页时禁用浏览器滚动恢复，并回到照片列表顶部。
    const previousScrollRestoration = window.history.scrollRestoration

    window.history.scrollRestoration = 'manual'
    window.scrollTo(0, 0)

    return () => {
      window.history.scrollRestoration = previousScrollRestoration
    }
  }, [])

  useEffect(() => {
    // 同步当前相册 id，供上传成功队列消费时过滤。
    albumIdRef.current = albumId
  }, [albumId])

  useEffect(() => {
    // 消费上传成功队列，把当前相册内的新照片按 taken_time 插入列表对应位置。
    if (!uploadedPhotos.length) {
      return
    }

    const photosToAdd = usePhotoStore.getState().takeUploadedPhotos()
      .filter((photo) => albumIdRef.current === "default"
        ? !photo.uploadAlbumId
        : photo.uploadAlbumId === albumIdRef.current)

    if (!photosToAdd.length) {
      return
    }

    queueMicrotask(() => {
      prependPhotos(photosToAdd)
    })
  }, [prependPhotos, uploadedPhotos])

  // 打开当前相册照片详情 model。
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

  // 批量回收当前相册选中的照片。
  const recyclePhotos = useCallback((photoIds: string[]) => {
    photoRecycle({ photoIds }).then(() => {
      increaseRefreshKey()
      removePhotos(photoIds)
    })
  }, [increaseRefreshKey, removePhotos])

  // 批量把当前相册选中的照片移出相册。
  const removeAlbumPhotos = useCallback((photoIds: string[]) => {
    albumRemovePhoto({ albumId, photoIds }).then(() => {
      increaseRefreshKey()
      removePhotos(photoIds)
      void refreshAlbums()
    })
  }, [albumId, increaseRefreshKey, removePhotos, refreshAlbums])

  // 打开当前相册照片批量加入相册弹框。
  const openAlbumDialog = useCallback((photoIds: string[]) => {
    setAlbumPhotoIds(photoIds)
    setAlbumDialogOpen(true)
  }, [])

  // 选中相册后把当前相册照片加入其他相册。
  function changePhotoAlbum(albumIds: string[]) {
    const targetAlbumIds = albumIds.filter((targetAlbumId) => targetAlbumId !== albumId)

    if (!targetAlbumIds.length) {
      return
    }

    albumAddPhoto({ albumIds: targetAlbumIds, photoIds: albumPhotoIds }).then(() => {
      increaseRefreshKey()
      if (albumId === "default") {
        removePhotos(albumPhotoIds)
      }
      void refreshAlbums()
    })
  }

  // 保存当前选择的相册照片时间范围，并触发列表按拍摄时间筛选。
  function changePhotoTime(range: { startDate: Date, endDate: Date }) {
    refreshPhotoList({
      albumId,
      startTakenTime: range.startDate.toISOString(),
      endTakenTime: range.endDate.toISOString(),
    })
  }

  // 按照片名称或存储名称刷新当前相册照片列表。
  function searchPhotos(keyword: string, searchType: "photo" | "storage") {
    refreshPhotoList({
      albumId,
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
              <Button
                type="button"
                variant="ghost"
                size="icon-sm"
                className="-ml-1"
                onClick={() => router.back()}
              >
                <ArrowLeftIcon />
                <span className="sr-only">Back</span>
              </Button>
              <Separator
                orientation="vertical"
                className="mr-2 data-vertical:h-4 data-vertical:self-auto"
              />
              <Breadcrumb>
                <BreadcrumbList>
                  <BreadcrumbItem>
                    <BreadcrumbPage>{albumId === "default" ? t("default") : currentAlbumName || t("title")}</BreadcrumbPage>
                  </BreadcrumbItem>
                </BreadcrumbList>
              </Breadcrumb>
            </div>
            <div className="fixed right-0 top-0 flex h-12 items-center gap-1 px-3">
              <PhotoSearch onSearch={searchPhotos} />
              <PhotoDateDrawer albumId={albumId} onRangeChange={changePhotoTime} />
              <Button
                type="button"
                size="icon"
                variant="ghost"
                onClick={() => openUpload(albumId === "default" ? null : albumId)}
              >
                <PlusIcon />
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
                onAlbumRemove={albumId === "default" ? undefined : removeAlbumPhotos}
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
