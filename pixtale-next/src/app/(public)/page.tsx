"use client"

import dynamic from "next/dynamic"
import Link from "next/link"
import { useCallback, useEffect, useLayoutEffect, useState } from "react"
import { GalleryVerticalEnd, LogIn, UserRound } from "lucide-react"

import { usePhotoContext } from "@/app/(main)/photos/provider"
import { Button } from "@/components/ui/button"
import { usePublicContext } from "./provider"
import { PhotoMasonry } from "@/components/photo/photo-masonry"
import { PhotoMasonrySkeleton } from "@/components/photo/photo-masonry-skeleton"
import { usePhotoList } from "@/hooks/use-photo-list"
import { publicPhotoList } from "@/request/photo"
import { PHOTO_LIST_PAGE_SIZE } from "@/server/const/global"

const PhotoViewer = dynamic(
  () => import("@/components/photo/photo-viewer").then((mod) => mod.PhotoViewer),
  { ssr: false },
)

// 渲染未登录用户可访问的公开照片首页。
export default function PublicHomePage() {
  const { title, isLoggedIn, listStyle } = usePublicContext()
  // hasChineseTitle 用于判断站点名称是否包含中文字符。
  const hasChineseTitle = /[\u3400-\u9fff]/u.test(title)
  const { initialPhotos } = usePhotoContext()
  // isBrowser 标记当前是否已经完成浏览器端布局初始化。
  const [isBrowser, setIsBrowser] = useState(false)
  const { photos, masonryKey, loadMorePhotos } = usePhotoList(
    {},
    PHOTO_LIST_PAGE_SIZE,
    initialPhotos,
    publicPhotoList,
  )
  // modelPhotoIndex 保存查看器当前照片索引。
  const [modelPhotoIndex, setModelPhotoIndex] = useState(0)
  // showPhotoViewer 控制公开照片查看器的显示状态。
  const [showPhotoViewer, setShowPhotoViewer] = useState(false)

  const accountHref = isLoggedIn ? "/photos" : "/auth"

  useLayoutEffect(() => {
    setIsBrowser(true)
  }, [])

  useEffect(() => {
    // 刷新公开首页时禁用浏览器滚动恢复，并回到照片列表顶部。
    const previousScrollRestoration = window.history.scrollRestoration

    window.history.scrollRestoration = "manual"
    window.scrollTo(0, 0)

    return () => {
      window.history.scrollRestoration = previousScrollRestoration
    }
  }, [])

  // 打开公开照片查看器。
  const openPhoto = useCallback((index: number) => {
    setModelPhotoIndex(index)
    setShowPhotoViewer(true)
  }, [])

  // 关闭公开照片查看器。
  function closePhoto() {
    setShowPhotoViewer(false)
  }

  return (
    <>
      <header className="sticky top-0 z-20 flex h-12 shrink-0 items-center justify-between gap-2 bg-background">
        <div className="flex min-w-0 items-center px-5">
          <span className={`${hasChineseTitle ? "text-base font-semibold" : "text-2xl font-bahamas font-semibold"}`}>{title}</span>
        </div>
        <div className="fixed left-[calc(100vw-5.75rem)] top-0 flex h-12 items-center gap-1 px-4 md:left-[calc(100vw-6.25rem)]">
          <Button asChild variant="ghost" size="icon" className="group">
            <Link href="/public/albums">
              <GalleryVerticalEnd strokeWidth={2.5} className="text-muted-foreground transition-colors group-hover:text-foreground" />
            </Link>
          </Button>
          <Button asChild variant="ghost" size="icon" className="group">
            <Link href={accountHref}>
              {isLoggedIn ? (
                <UserRound strokeWidth={2.5} className="text-muted-foreground transition-colors group-hover:text-foreground" />
              ) : (
                <LogIn strokeWidth={2.5} className="text-muted-foreground transition-colors group-hover:text-foreground" />
              )}
            </Link>
          </Button>
        </div>
      </header>
      <main className="px-1 md:pl-1 md:pr-0">
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
