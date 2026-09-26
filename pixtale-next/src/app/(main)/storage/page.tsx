'use client';

import { useState } from "react"
import { Plus } from "lucide-react"
import { toast } from "sonner"
import { AppSidebar } from "@/components/layout/app-sidebar"
import { AlertDialogDestructive } from "@/components/common/alert-destructive"
import { StorageAddDialog } from "@/components/storage/storage-add-dialog"
import { DataTable } from "@/components/storage/storage-data-table"
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
import { storageAdd, storageDelete, storageList, storageSet, storageSetTop, storageToggleStatus } from "@/request/storage"
import { type Storage, type StorageInto } from "@/server/entity/storage"
import { useStorageColumns } from "@/components/storage/storage-columns";
import { type StorageVo } from "@/server/entity/vo/storage";
import { useStorageContext } from "./provider"
import { useApp } from "@/app/(main)/provider"
import { useTranslations } from "next-intl"

export default function Page() {
  const t = useTranslations("storage")
  const { initialStorageList } = useStorageContext()
  const { sidebarOpen, setSidebarOpen, refreshStorages } = useApp()
  // data 保存当前表格展示的存储配置列表。
  const [data, setData] = useState<StorageVo[]>(initialStorageList)
  // addOpen 控制新增存储弹框的打开状态。
  const [addOpen, setAddOpen] = useState(false)
  // editOpen 控制修改存储弹框的打开状态。
  const [editOpen, setEditOpen] = useState(false)
  // editingStorage 保存当前正在修改的存储配置。
  const [editingStorage, setEditingStorage] = useState<StorageVo | null>(null)
  // deleteOpen 控制删除确认弹框的打开状态。
  const [deleteOpen, setDeleteOpen] = useState(false)
  // deletingStorage 保存当前等待删除确认的存储配置。
  const [deletingStorage, setDeletingStorage] = useState<StorageVo | null>(null)

  // 查询存储列表并绑定到表格数据。
  async function getStorageList() {
    const res = await storageList()

    setData(res.list)
  }

  // 重新查询表格和全局存储下拉选项。
  async function refreshStorageData() {
    await getStorageList()
    await refreshStorages()
  }

  // 打开新增存储弹框。
  function openAddStorage() {
    setAddOpen(true)
  }

  // 添加存储配置。
  function addStorage(storage: StorageInto) {
    storageAdd(storage).then(() => {
      void refreshStorageData()
    })
  }

  // 打开删除确认弹框。
  function openDeleteStorage(storage: StorageVo) {
    setDeletingStorage(storage)
    setDeleteOpen(true)
  }

  // 删除存储配置期间显示加载状态，完成后重新查询列表。
  function confirmDeleteStorage() {
    const storage = deletingStorage

    if (!storage) {
      return
    }

    setDeleteOpen(false)
    setTimeout(() => {
      setDeletingStorage(null)
    }, 300)

    toast.promise(
      storageDelete(storage.storageId).then(() => refreshStorageData()),
      {
        loading: t("deleting"),
        success: t("deleted"),
      }
    )
  }

  // 打开修改存储弹框。
  function openEditStorage(storage: StorageVo) {
    setEditingStorage(storage)
    setEditOpen(true)
  }

  // 提交修改存储配置，成功后刷新列表。
  function editStorage(storage: StorageInto) {
    if (!editingStorage) {
      return
    }

    const nextStorage: Storage = {
      storageId: editingStorage.storageId,
      name: storage.name,
      type: storage.type,
      domain: storage.domain ?? null,
      bucket: storage.bucket ?? null,
      region: storage.region ?? null,
      endpoint: storage.endpoint ?? null,
      accessKey: storage.accessKey ?? null,
      secretKey: storage.secretKey ?? null,
      tgToken: storage.tgToken ?? null,
      tgChatId: storage.tgChatId ?? null,
      userId: editingStorage.userId,
      sort: editingStorage.sort,
      status: storage.status ?? editingStorage.status,
    }

    storageSet(nextStorage).then(() => {
      toast.success(t("updated"))
      void refreshStorageData()
    })
  }

  // 置顶存储配置后刷新列表。
  function setTopStorage(storageId: string) {
    storageSetTop({ storageId }).then(() => {
      void refreshStorageData()
    })
  }

  // 切换存储启用状态后刷新列表。
  function toggleStorageStatus(storageId: string) {
    storageToggleStatus({ storageId }).then(() => {
      void refreshStorageData()
    })
  }

  // 处理修改存储弹框打开状态。
  function handleEditOpenChange(open: boolean) {
    setEditOpen(open)

    if (!open) {
      setEditingStorage(null)
    }
  }

  // 处理删除确认弹框打开状态。
  function handleDeleteOpenChange(open: boolean) {
    setDeleteOpen(open)

    if (!open) {
      setTimeout(() => {
        setDeletingStorage(null)
      }, 300)
    }
  }

  const columns = useStorageColumns({
    onEdit: openEditStorage,
    onSetTop: setTopStorage,
    onToggleStatus: toggleStorageStatus,
    onDelete: openDeleteStorage
  })

  return (
    <>
      <SidebarProvider open={sidebarOpen} onOpenChange={setSidebarOpen}>
        <AppSidebar />
        <SidebarInset>
          <header
            className="flex h-13 shrink-0 items-center justify-between gap-2 bg-background transition-[width,height] ease-linear">
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
          </header>
          <div className="space-y-3 px-4 py-4" >
            <DataTable
              columns={columns}
              data={data}
              action={
                <Button type="button" onClick={openAddStorage}>
                  <Plus />
                  {t("add")}
                </Button>
              }
            ></DataTable>
          </div>
        </SidebarInset>
      </SidebarProvider>
      <StorageAddDialog
        title={t("addTitle")}
        open={addOpen}
        onOpenChange={setAddOpen}
        onStorageConfirm={addStorage}
      />
      {editingStorage && (
        <StorageAddDialog
          title={t("editTitle")}
          open={editOpen}
          storage={editingStorage}
          onOpenChange={handleEditOpenChange}
          onStorageConfirm={editStorage}
        />
      )}
      <AlertDialogDestructive
        open={deleteOpen}
        onOpenChange={handleDeleteOpenChange}
        title={t("deleteTitle")}
        description={t("deleteDescription")}
        onConfirm={confirmDeleteStorage}
      />
    </>
  )
}
