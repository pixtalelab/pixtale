'use client';

import { useCallback, useEffect, useLayoutEffect, useState } from 'react'
import { PhotoMasonry } from "@/components/photo/photo-masonry"
import { useRouter } from "next/navigation"

import { AppSidebar } from "@/components/layout/app-sidebar"
import { AlertDialogDestructive } from "@/components/common/alert-destructive"
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
import { photoClear, photoDelete, photoRestore } from "@/request/photo"
import { toast } from "sonner"
import { PHOTO_LIST_PAGE_SIZE } from "@/server/const/global"
import { PhotoStatusEnum } from "@/server/enums/photo-enum"
import { useTrashPhotoContext } from "./provider"
import { useApp } from "@/app/(main)/provider"
import { Button } from "@/components/ui/button"
import { ArrowLeftIcon, BrushCleaning } from "lucide-react"
import { PhotoMasonrySkeleton } from "@/components/photo/photo-masonry-skeleton"
import { useTranslations } from "next-intl"

export default function Page() {
  const t = useTranslations("trash")
  const router = useRouter()
  const { initialPhotos } = useTrashPhotoContext()
  const { sidebarOpen, setSidebarOpen, listStyle } = useApp()
  // isBrowser 标记当前是否在浏览器环境，SSR 阶段显示骨架屏。
  const [isBrowser, setIsBrowser] = useState(false)
  // deleteOpen 控制彻底删除确认弹框的打开状态。
  const [deleteOpen, setDeleteOpen] = useState(false)
  // deletingPhotoIds 保存当前等待彻底删除确认的照片 id。
  const [deletingPhotoIds, setDeletingPhotoIds] = useState<string[]>([])
  // clearOpen 控制清空回收站确认弹框的打开状态。
  const [clearOpen, setClearOpen] = useState(false)
  const {
    photos,
    setPhotos,
    masonryKey,
    loadMorePhotos,
    removePhotos,
    refreshMasonry,
  } = usePhotoList({ status: PhotoStatusEnum.DELETE }, PHOTO_LIST_PAGE_SIZE, initialPhotos)

  useLayoutEffect(() => {
    setIsBrowser(true)
  }, [])

  useEffect(() => {
    // 刷新回收站照片页时禁用浏览器滚动恢复，并回到照片列表顶部。
    const previousScrollRestoration = window.history.scrollRestoration

    window.history.scrollRestoration = 'manual'
    window.scrollTo(0, 0)

    return () => {
      window.history.scrollRestoration = previousScrollRestoration
    }
  }, [])

  // 打开批量彻底删除确认弹框。
  const openDeletePhotos = useCallback((photoIds: string[]) => {
    setDeletingPhotoIds(photoIds)
    setDeleteOpen(true)
  }, [])

  // 打开清空回收站确认弹框。
  function openClearPhotos() {
    if (!photos.length) {
      return
    }

    setClearOpen(true)
  }

  // 批量彻底删除回收站选中的照片。
  function deletePhotos() {
    const photoIds = deletingPhotoIds

    setDeleteOpen(false)
    setTimeout(() => {
      setDeletingPhotoIds([])
    }, 300)

    photoDelete({ photoIds }).then(() => {
      removePhotos(photoIds)
    })
  }

  // 清空当前用户回收站照片，期间提示加载、成功或失败状态。
  function clearPhotos() {
    setClearOpen(false)

    toast.promise(
      photoClear({ showErrorToast: false }).then(() => {
        setPhotos([])
        refreshMasonry()
      }),
      {
        loading: t("clearing"),
        success: t("cleared"),
        error: (error: unknown) => error instanceof Error ? error.message : t("clearFailed"),
      }
    )
  }

  // 恢复回收站选中的照片，并从当前回收站列表移除。
  const restorePhotos = useCallback((photoIds: string[]) => {
    photoRestore({ photoIds }).then(() => {
      removePhotos(photoIds)
    })
  }, [removePhotos])

  // 处理彻底删除确认弹框打开状态。
  function handleDeleteOpenChange(open: boolean) {
    setDeleteOpen(open)

    if (!open) {
      setTimeout(() => {
        setDeletingPhotoIds([])
      }, 300)
    }
  }

  // 处理清空回收站确认弹框打开状态。
  function handleClearOpenChange(open: boolean) {
    setClearOpen(open)
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
                    <BreadcrumbPage className="flex items-center gap-2">
                      <span>{t("title")}</span>
                    </BreadcrumbPage>
                  </BreadcrumbItem>
                </BreadcrumbList>
              </Breadcrumb>
            </div>
            <div className="fixed left-[calc(100vw-3.5rem)]  md:left-[calc(100vw-4rem)] top-0 flex h-12 items-center gap-3 px-4">
              <Button
                type="button"
                size="icon"
                variant="ghost"
                onClick={openClearPhotos}
              >
                <BrushCleaning />
              </Button>
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
                onPhotoDelete={openDeletePhotos}
                onPhotoRestore={restorePhotos}
              />
            ) : (
              <PhotoMasonrySkeleton photos={initialPhotos} listStyle={listStyle} />
            )}
          </div>
        </SidebarInset>
      </SidebarProvider>
      <AlertDialogDestructive
        open={deleteOpen}
        onOpenChange={handleDeleteOpenChange}
        title={t("deletePhotosTitle")}
        description={t("deletePhotosDescription")}
        onConfirm={deletePhotos}
      />
      <AlertDialogDestructive
        open={clearOpen}
        onOpenChange={handleClearOpenChange}
        title={t("clearTitle")}
        description={t("clearDescription")}
        confirmText={t("clear")}
        onConfirm={clearPhotos}
      />
    </>
  )
}
