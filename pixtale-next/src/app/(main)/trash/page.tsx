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
import { useTrashContext } from "./provider"
import { useApp } from "@/app/(main)/provider"
import { useTranslations } from "next-intl"

const AlbumMasonry = dynamic(
  () => import("@/components/album/album-masonry").then((mod) => mod.AlbumMasonry),
  { ssr: false },
)

export default function Page() {
  const t = useTranslations()
  const { initialAlbum } = useTrashContext()
  const { sidebarOpen, setSidebarOpen } = useApp()
  // album 保存带页面跳转地址的回收站入口相册。
  const album = {
    ...initialAlbum,
    albumId: "../trash/photos",
    name: t(initialAlbum.name),
  }

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
          <div className="px-3 md:pl-5 pl-4 pt-1 md:pt-2 md:pr-2">
            <AlbumMasonry
              albums={[album]}
            />
          </div>
        </SidebarInset>
      </SidebarProvider>
    </>
  )
}
