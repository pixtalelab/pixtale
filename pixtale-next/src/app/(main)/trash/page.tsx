'use client';

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
import dynamic from "next/dynamic"
import { useEffect } from "react"
import { useRouter } from "next/navigation"
import { useTrashContext } from "./provider"
import { useApp } from "@/app/(main)/provider"
import { useTrashStore } from "@/store/trash-store"
import { useTranslations } from "next-intl"

const AlbumMasonry = dynamic(
  () => import("@/components/album/album-masonry").then((mod) => mod.AlbumMasonry),
  { ssr: false },
)

// 展示回收站入口，并在照片变更后返回时刷新数量和封面。
export default function Page() {
  const t = useTranslations()
  const router = useRouter()
  const { initialAlbum } = useTrashContext()
  const { sidebarOpen, setSidebarOpen } = useApp()
  // refreshKey 大于零表示照片变更后需要重新读取回收站数量和封面。
  const refreshKey = useTrashStore((state) => state.refreshKey)
  // album 保存带页面跳转地址的回收站入口相册。
  const album = {
    ...initialAlbum,
    albumId: "../trash/photos",
    name: t(initialAlbum.name),
  }

  // 返回入口时消费照片变更标记，并重新读取服务端统计和封面。
  useEffect(() => {
    if (refreshKey > 0) {
      useTrashStore.getState().resetRefreshKey()
      router.refresh()
    }
  }, [refreshKey, router])

  return (
    <>
      <SidebarProvider open={sidebarOpen} onOpenChange={setSidebarOpen}>
        <AppSidebar />
        <SidebarInset>
          <header
            className="flex h-12 shrink-0 items-center justify-between gap-2 bg-background transition-[width,height] ease-linear">
            <div className="flex min-w-0 items-center gap-2 px-4">
              <SidebarTrigger className="-ml-1" />
              <Separator
                orientation="vertical"
                className="mr-2 data-vertical:h-4 data-vertical:self-auto"
              />
              <Breadcrumb>
                <BreadcrumbList>
                  <BreadcrumbItem>
                    <BreadcrumbPage>{t("trash.title")}</BreadcrumbPage>
                  </BreadcrumbItem>
                </BreadcrumbList>
              </Breadcrumb>
            </div>
          </header>
          <div className="px-4 pt-1 md:pt-2 md:px-5">
            <AlbumMasonry
              albums={[album]}
            />
          </div>
        </SidebarInset>
      </SidebarProvider>
    </>
  )
}
