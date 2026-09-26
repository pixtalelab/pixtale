'use client';

import { useState } from "react"
import { Plus } from "lucide-react"
import { toast } from "sonner"
import { AppSidebar } from "@/components/layout/app-sidebar"
import { AlertDialogDestructive } from "@/components/common/alert-destructive"
import { UserAddDialog } from "@/components/user/user-add-dialog"
import { DataTable } from "@/components/user/user-data-table"
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
import { userAdd, userDelete, userList, userSet, userToggleStatus } from "@/request/user"
import { type UserAddBo, type UserSetBo } from "@/server/entity/bo/user"
import { type UserVo } from "@/server/entity/vo/user"
import { useUserColumns } from "@/components/user/user-columns"
import { useUserContext } from "./provider"
import { useApp } from "@/app/(main)/provider"
import { useTranslations } from "next-intl"

export default function Page() {
  const t = useTranslations("users")
  const { initialUserList } = useUserContext()
  const { sidebarOpen, setSidebarOpen } = useApp()
  // data 保存当前表格展示的用户列表。
  const [data, setData] = useState<UserVo[]>(initialUserList)
  // addOpen 控制新增用户弹框的打开状态。
  const [addOpen, setAddOpen] = useState(false)
  // editOpen 控制编辑用户弹框的打开状态。
  const [editOpen, setEditOpen] = useState(false)
  // editingUser 保存当前正在编辑的用户。
  const [editingUser, setEditingUser] = useState<UserVo | null>(null)
  // deleteOpen 控制删除确认弹框的打开状态。
  const [deleteOpen, setDeleteOpen] = useState(false)
  // deletingUser 保存当前等待删除确认的用户。
  const [deletingUser, setDeletingUser] = useState<UserVo | null>(null)

  // 打开新增用户弹框。
  function openAddUser() {
    setAddOpen(true)
  }

  // 查询用户列表并绑定到表格数据。
  function getUserList() {
    userList().then((res) => {
      setData(res.list)
    })
  }

  // 添加用户。
  function addUser(user: UserAddBo) {
    userAdd(user).then(() => {
      getUserList()
    })
  }

  // 打开编辑用户弹框。
  function openEditUser(user: UserVo) {
    setEditingUser(user)
    setEditOpen(true)
  }

  // 提交修改用户信息。
  function editUser(user: UserSetBo) {
    userSet(user).then(() => {
      toast.success(t("updated"))
      getUserList()
    })
  }

  // 切换用户启用状态后刷新列表。
  function toggleUserStatus(userId: string) {
    userToggleStatus({ userId }).then(() => {
      getUserList()
    })
  }

  // 打开删除确认弹框。
  function openDeleteUser(user: UserVo) {
    setDeletingUser(user)
    setDeleteOpen(true)
  }

  // 删除用户期间显示加载状态，完成后重新查询列表。
  function confirmDeleteUser() {
    const user = deletingUser

    if (!user) {
      return
    }

    setDeleteOpen(false)
    setTimeout(() => {
      setDeletingUser(null)
    }, 300)

    toast.promise(
      userDelete(user.userId).then(() => getUserList()),
      {
        loading: t("deleting"),
        success: t("deleted"),
      }
    )
  }

  // 处理编辑用户弹框打开状态。
  function handleEditOpenChange(open: boolean) {
    setEditOpen(open)

    if (!open) {
      setTimeout(() => {
        setEditingUser(null)
      }, 300)
    }
  }

  // 处理删除确认弹框打开状态。
  function handleDeleteOpenChange(open: boolean) {
    setDeleteOpen(open)

    if (!open) {
      setTimeout(() => {
        setDeletingUser(null)
      }, 300)
    }
  }

  const columns = useUserColumns({
    onEdit: openEditUser,
    onToggleStatus: toggleUserStatus,
    onDelete: openDeleteUser,
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
          <div className="space-y-3 px-4 py-4">
            <DataTable
              columns={columns}
              data={data}
              action={
                <Button type="button" onClick={openAddUser}>
                  <Plus />
                  {t("add")}
                </Button>
              }
            ></DataTable>
          </div>
        </SidebarInset>
      </SidebarProvider>
      <UserAddDialog
        title={t("addTitle")}
        open={addOpen}
        onOpenChange={setAddOpen}
        onUserConfirm={(user) => addUser(user as UserAddBo)}
      />
      <UserAddDialog
        title={t("editTitle")}
        open={editOpen}
        user={editingUser}
        onOpenChange={handleEditOpenChange}
        onUserConfirm={(user) => editUser(user as UserSetBo)}
      />
      <AlertDialogDestructive
        open={deleteOpen}
        onOpenChange={handleDeleteOpenChange}
        title={t("deleteTitle")}
        description={t("deleteDescription")}
        onConfirm={confirmDeleteUser}
      />
    </>
  )
}
