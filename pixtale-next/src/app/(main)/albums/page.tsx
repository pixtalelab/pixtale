"use client"

import { AppSidebar } from "@/components/layout/app-sidebar"
import { AlertDialogDestructive } from "@/components/common/alert-destructive"
import { AlbumAddDialog } from "@/components/album/album-add-dialog"
import { AlbumRenameDialog } from "@/components/album/album-rename-dialog"
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
import { useLayoutEffect, useState } from "react"
import { useAlbumContext } from "./provider"
import { useApp } from "@/app/(main)/provider"
import { useAlbumStore } from "@/store/album-store"
import { albumAdd, albumDelete, albumList, albumRecycle, albumSetName, albumSetPublic, albumSetTop } from "@/request/album"
import { AlbumPublicEnum } from "@/server/enums/album-enum"
import { type AlbumVo } from "@/server/entity/vo/album"
import { useTranslations } from "next-intl"

const AlbumMasonry = dynamic(
  () => import("@/components/album/album-masonry").then((mod) => mod.AlbumMasonry),
  { ssr: false },
)

export default function Page() {
  const t = useTranslations("albums")
  const { initialAlbums } = useAlbumContext()
  const { sidebarOpen, setSidebarOpen, refreshAlbums } = useApp()
  // albums 保存当前页面展示的相册列表。
  const [albums, setAlbums] = useState<AlbumVo[]>(initialAlbums)
  // albumListKey 用于强制刷新相册瀑布流布局。
  const [albumListKey, setAlbumListKey] = useState(0)
  // renameOpen 控制修改名字弹框的打开状态。
  const [renameOpen, setRenameOpen] = useState(false)
  // renamingAlbum 保存当前正在修改名字的相册。
  const [renamingAlbum, setRenamingAlbum] = useState<AlbumVo | null>(null)
  // deleteOpen 控制删除确认弹框的打开状态。
  const [deleteOpen, setDeleteOpen] = useState(false)
  // deletingAlbum 保存当前等待删除确认的相册。
  const [deletingAlbum, setDeletingAlbum] = useState<AlbumVo | null>(null)
  // recycleOpen 控制回收照片确认弹框的打开状态。
  const [recycleOpen, setRecycleOpen] = useState(false)
  // recyclingAlbum 保存当前等待回收照片确认的相册。
  const [recyclingAlbum, setRecyclingAlbum] = useState<AlbumVo | null>(null)

  useLayoutEffect(() => {
    // 仅从相册照片页返回时恢复内存中记录的位置，整页刷新时状态为 0 并回到顶部。
    const previousScrollRestoration = window.history.scrollRestoration
    const scrollPosition = useAlbumStore.getState().scrollPosition

    window.history.scrollRestoration = "manual"
    useAlbumStore.getState().setScrollPosition(0)

    window.scrollTo(0, scrollPosition)

    return () => {
      window.history.scrollRestoration = previousScrollRestoration
    }
  }, [])

  // 加载全部相册数据。
  async function getAlbumList() {
    const data = await albumList()

    setAlbums(data)
    setAlbumListKey((prev) => prev + 1)
  }

  // 重新查询相册页面列表和全局相册选择列表。
  async function refreshAlbumData() {
    await getAlbumList()
    await refreshAlbums()
  }

  // 添加相册，并把新相册展示到列表顶部。
  function addAlbum(name: string) {
    albumAdd({ name }).then(() => {
      void refreshAlbumData()
    })
  }

  // 打开修改相册名字弹框。
  function renameAlbum(album: AlbumVo) {
    setRenamingAlbum(album)
    setRenameOpen(true)
  }

  // 处理相册置顶操作。
  function topAlbum(album: AlbumVo) {
    albumSetTop({
      albumId: album.albumId,
    }).then(() => {
      void refreshAlbumData()
    })
  }

  // 切换相册公开状态并刷新当前相册列表。
  function changeAlbumPublic(album: AlbumVo) {
    albumSetPublic({
      albumId: album.albumId,
      public: album.public === AlbumPublicEnum.ENABLE
        ? AlbumPublicEnum.DISABLE
        : AlbumPublicEnum.ENABLE,
    }).then(() => {
      void refreshAlbumData()
    })
  }

  // 打开回收照片确认弹框。
  function openRecycleAlbum(album: AlbumVo) {
    setRecyclingAlbum(album)
    setRecycleOpen(true)
  }

  // 把相册中的照片移入回收站后刷新相册数量和封面。
  function recycleAlbum(album: AlbumVo) {
    albumRecycle({ albumId: album.albumId }).then(() => {
      void refreshAlbumData()
    })
  }

  // 打开删除确认弹框。
  function openDeleteAlbum(album: AlbumVo) {
    setDeletingAlbum(album)
    setDeleteOpen(true)
  }

  // 删除相册后更新当前列表。
  function deleteAlbum(album: AlbumVo) {
    albumDelete({
      albumId: album.albumId,
    }).then(() => {
      void refreshAlbumData()
    })
  }

  // 确认删除相册后更新当前列表。
  function confirmDeleteAlbum() {
    const album = deletingAlbum

    if (!album) {
      return
    }

    setDeleteOpen(false)
    setTimeout(() => {
      setDeletingAlbum(null)
    }, 300)

    deleteAlbum(album)
  }

  // 确认回收相册照片后更新当前列表。
  function confirmRecycleAlbum() {
    const album = recyclingAlbum

    if (!album) {
      return
    }

    setRecycleOpen(false)
    setTimeout(() => {
      setRecyclingAlbum(null)
    }, 300)

    recycleAlbum(album)
  }

  // 提交相册新名称，成功后更新当前列表中的相册名称。
  function renameAlbumName(name: string) {
    const album = renamingAlbum

    if (!album) {
      return
    }

    setRenameOpen(false)
    setTimeout(() => {
      setRenamingAlbum(null)
    }, 300)

    albumSetName({
      albumId: album.albumId,
      name,
    }).then(() => {
      void refreshAlbumData()
    })
  }

  // 处理修改名字弹框打开状态。
  function handleRenameOpenChange(open: boolean) {
    setRenameOpen(open)

    if (!open) {
      setRenamingAlbum(null)
    }
  }

  // 处理删除确认弹框打开状态。
  function handleDeleteOpenChange(open: boolean) {
    setDeleteOpen(open)

    if (!open) {
      setTimeout(() => {
        setDeletingAlbum(null)
      }, 300)
    }
  }

  // 处理回收照片确认弹框打开状态。
  function handleRecycleOpenChange(open: boolean) {
    setRecycleOpen(open)

    if (!open) {
      setTimeout(() => {
        setRecyclingAlbum(null)
      }, 300)
    }
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
                    <BreadcrumbPage>{t("title")}</BreadcrumbPage>
                  </BreadcrumbItem>
                </BreadcrumbList>
              </Breadcrumb>
            </div>
            <div className="fixed left-[calc(100vw-3.5rem)]  md:left-[calc(100vw-4rem)] top-0 flex h-12 items-center gap-3 px-4">
              <AlbumAddDialog title={t("addTitle")} onNameConfirm={addAlbum} />
            </div>
          </header>
          <div className="px-2 pl-4 pr-4 pt-1 md:pt-2 md:pl-5 md:pr-4">
            <AlbumMasonry
            albums={albums}
            resetKey={albumListKey}
            sidebarOpen={sidebarOpen}
            onAlbumRename={renameAlbum}
              onAlbumTop={topAlbum}
              onAlbumPublic={changeAlbumPublic}
              onAlbumRecycle={openRecycleAlbum}
              onAlbumDelete={openDeleteAlbum}
            />
          </div>
        </SidebarInset>
      </SidebarProvider>
      {renamingAlbum && (
        <AlbumRenameDialog
          open={renameOpen}
          name={renamingAlbum.name}
          onOpenChange={handleRenameOpenChange}
          onNameConfirm={renameAlbumName}
        />
      )}
      <AlertDialogDestructive
        open={deleteOpen}
        onOpenChange={handleDeleteOpenChange}
        title={t("deleteTitle")}
        description={t("deleteDescription")}
        onConfirm={confirmDeleteAlbum}
      />
      <AlertDialogDestructive
        open={recycleOpen}
        onOpenChange={handleRecycleOpenChange}
        title={t("recycleTitle")}
        description={t("recycleDescription")}
        confirmText={t("actions.recycle")}
        onConfirm={confirmRecycleAlbum}
      />
    </>
  )
}
