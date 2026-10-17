"use client"

import dynamic from "next/dynamic"
import { useCallback, useEffect, useLayoutEffect, useState } from "react"
import { Undo2 } from "lucide-react"
import { useParams, useRouter } from "next/navigation"

import { usePhotoContext } from "@/app/(main)/photos/provider"
import { Button } from "@/components/ui/button"
import { PhotoMasonry } from "@/components/photo/photo-masonry"
import { PhotoMasonrySkeleton } from "@/components/photo/photo-masonry-skeleton"
import { usePhotoList } from "@/hooks/use-photo-list"
import { publicPhotoList } from "@/request/photo"
import { PHOTO_LIST_PAGE_SIZE } from "@/server/const/global"
import { usePublicAlbumPhotoContext } from "./provider"
import { usePublicContext } from "@/app/(public)/provider"

const PhotoViewer = dynamic(
  () => import("@/components/photo/photo-viewer").then((mod) => mod.PhotoViewer),
  { ssr: false },
)

// 渲染指定公开相册中的只读照片列表。
export default function PublicAlbumPhotosPage() {
  const router = useRouter()
  const { albumName } = usePublicAlbumPhotoContext()
  const { listStyle } = usePublicContext()
  const { initialPhotos } = usePhotoContext()
  const { albumId } = useParams<{ albumId: string }>()
  // isBrowser 标记当前是否已经完成浏览器端布局初始化。
  const [isBrowser, setIsBrowser] = useState(false)
  const { photos, masonryKey, loadMorePhotos } = usePhotoList(
    { albumId },
    PHOTO_LIST_PAGE_SIZE,
    initialPhotos,
    publicPhotoList,
  )
  // modelPhotoIndex 保存查看器当前照片索引。
  const [modelPhotoIndex, setModelPhotoIndex] = useState(0)
  // showPhotoViewer 控制公开照片查看器的显示状态。
  const [showPhotoViewer, setShowPhotoViewer] = useState(false)

  // 返回浏览器导航历史中的上一页。
  function goBack() {
    router.back()
  }

  useLayoutEffect(() => {
    // Masonry 依赖浏览器布局，挂载后再显示。
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setIsBrowser(true)
  }, [])

  useEffect(() => {
    // 刷新公开相册照片页时禁用浏览器滚动恢复，并回到列表顶部。
    const previousScrollRestoration = window.history.scrollRestoration

    window.history.scrollRestoration = "manual"
    window.scrollTo(0, 0)

    return () => {
      window.history.scrollRestoration = previousScrollRestoration
    }
  }, [])

  // 打开公开相册照片查看器。
  const openPhoto = useCallback((index: number) => {
    setModelPhotoIndex(index)
    setShowPhotoViewer(true)
  }, [])

  // 关闭公开相册照片查看器。
  function closePhoto() {
    setShowPhotoViewer(false)
  }

  return (
    <>
      <header data-gallery-page-header className="sticky top-0 z-20 flex h-12 shrink-0 items-center justify-between gap-2 bg-background">
        <div className="flex min-w-0 items-center px-5">
          <span className="text-base font-bold">{albumName}</span>
        </div>
        <div className="fixed right-0 top-0 flex h-12 items-center gap-1 px-3">
          <Button variant="ghost" size="icon" className="group" onClick={goBack}>
            <Undo2 className="text-muted-foreground transition-colors group-hover:text-foreground" />
          </Button>
        </div>
      </header>
      <main className="px-1">
        {isBrowser ? (
          <PhotoMasonry
            photos={photos}
            resetKey={masonryKey}
            onReachBottom={loadMorePhotos}
            onPhotoOpen={openPhoto}
            listStyle={listStyle}
            readOnly
          />
        ) : (
          <PhotoMasonrySkeleton photos={initialPhotos} listStyle={listStyle} />
        )}
      </main>
      <PhotoViewer
        open={showPhotoViewer}
        index={modelPhotoIndex}
        photos={photos}
        onBack={closePhoto}
        onBrowserBack={closePhoto}
      />
    </>
  )
}
