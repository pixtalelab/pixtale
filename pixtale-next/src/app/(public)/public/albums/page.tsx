"use client"

import { useEffect, useLayoutEffect, useState } from "react"
import { Undo2 } from "lucide-react"
import { useRouter } from "next/navigation"
import { useTranslations } from "next-intl"

import { AlbumMasonry } from "@/components/album/album-masonry"
import { Button } from "@/components/ui/button"
import { usePublicAlbumContext } from "./provider"

// 渲染只读的公开相册列表。
export default function PublicAlbumsPage() {
  const router = useRouter()
  const { initialAlbums } = usePublicAlbumContext()
  const t = useTranslations("albums")
  // isBrowser 标记当前是否已经完成浏览器端布局初始化。
  const [isBrowser, setIsBrowser] = useState(false)

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
    // 刷新公开相册页时禁用浏览器滚动恢复，并回到列表顶部。
    const previousScrollRestoration = window.history.scrollRestoration

    window.history.scrollRestoration = "manual"
    window.scrollTo(0, 0)

    return () => {
      window.history.scrollRestoration = previousScrollRestoration
    }
  }, [])

  return (
    <>
      <header data-gallery-page-header className="sticky top-0 z-20 flex h-12 shrink-0 items-center justify-between gap-2 bg-background">
        <div className="flex min-w-0 items-center px-5">
          <span className="text-base font-bold">{t("title")}</span>
        </div>
        <div className="fixed right-0 top-0 flex h-12 items-center gap-1 px-3">
          <Button variant="ghost" size="icon" className="group" onClick={goBack}>
            <Undo2 className="text-muted-foreground transition-colors group-hover:text-foreground" />
          </Button>
        </div>
      </header>
      <main className="px-4 pt-1 md:pt-2 md:px-5">
        {isBrowser && (
          <AlbumMasonry
            albums={initialAlbums}
            albumHref={(album) => `/public/albums/${album.albumId}`}
            showPublicLabel={false}
          />
        )}
      </main>
    </>
  )
}
