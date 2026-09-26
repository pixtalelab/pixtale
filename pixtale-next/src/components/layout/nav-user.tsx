"use client"

import { useEffect, useRef, useState, type ChangeEvent } from "react"
import dynamic from "next/dynamic"
import { useRouter } from "next/navigation"

import {
  Avatar,
  AvatarFallback,
  AvatarImage,
} from "@/components/ui/avatar"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import {
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  useSidebar,
} from "@/components/ui/sidebar"
import { ThemeSwitcher } from "@/components/layout/theme-switcher"
import { ChevronsUpDownIcon, UserRound, Key, BookOpen, LogOutIcon } from "lucide-react"
import { logout } from "@/request/login"
import { useApp } from "@/app/(main)/provider"
import { useTranslations } from "next-intl"

const AvatarUpload = dynamic(
  () => import("@/components/layout/avatar-upload").then((mod) => mod.AvatarUpload),
  { ssr: false }
)
const UpdatePassword = dynamic(
  () => import("@/components/layout/update-password").then((mod) => mod.UpdatePassword),
  { ssr: false }
)

// 获取头像占位文字，取用户名第一个字符。
function getAvatarFallback(name: string) {
  return Array.from(name.trim()).slice(0, 1).join("").toUpperCase()
}

// 渲染当前用户菜单。
export function NavUser({
  user,
}: {
  user: {
    name: string
    /*    email: string*/
    avatar: string
  }
}) {
  const t = useTranslations("layout.userMenu")
  const { isMobile } = useSidebar()
  const router = useRouter()
  const { setUserInfo } = useApp()
  const fallback = getAvatarFallback(user.name)
  // fileInputRef 用于先选择头像图片，再打开裁剪弹框。
  const fileInputRef = useRef<HTMLInputElement | null>(null)
  // objectUrlRef 保存当前待裁剪图片地址，便于释放内存。
  const objectUrlRef = useRef<string | null>(null)
  // image 保存当前传给头像裁剪弹框的图片地址。
  const [image, setImage] = useState("")
  // avatarOpen 控制头像上传弹框打开状态。
  const [avatarOpen, setAvatarOpen] = useState(false)
  // passwordOpen 控制修改密码弹框打开状态。
  const [passwordOpen, setPasswordOpen] = useState(false)

  useEffect(() => {
    return () => {
      if (objectUrlRef.current) {
        URL.revokeObjectURL(objectUrlRef.current)
      }
    }
  }, [])

  // 退出登录并跳转回登录页。
  function logoutUser() {
    logout().then(() => {
      router.replace("/")
    })
  }

  // 打开头像图片选择器。
  function openAvatarUpload() {
    fileInputRef.current?.click()
  }

  // 选择头像图片后打开裁剪弹框。
  function changeAvatarFile(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0]
    event.target.value = ""

    if (!file) {
      return
    }

    if (objectUrlRef.current) {
      URL.revokeObjectURL(objectUrlRef.current)
    }

    objectUrlRef.current = URL.createObjectURL(file)
    setImage(objectUrlRef.current)
    setAvatarOpen(true)
  }

  // 保存头像 key 后更新全局用户信息，展示地址由 props 计算。
  function updateAvatar(avatarKey: string) {
    setUserInfo((prev) => prev ? { ...prev, avatar: avatarKey } : prev)
  }

  // 打开修改密码弹框。
  function openUpdatePassword() {
    setPasswordOpen(true)
  }

  return (
    <>
      <SidebarMenu>
        <SidebarMenuItem>
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <SidebarMenuButton
                size="lg"
                className="data-[state=open]:bg-sidebar-accent data-[state=open]:text-sidebar-accent-foreground"
              >
                <Avatar className="h-8 w-8 rounded-lg after:rounded-lg">
                  {user.avatar ? (
                    <AvatarImage className="rounded-lg" src={user.avatar} alt={user.name} />
                  ) : null}
                  <AvatarFallback className="rounded-lg">{fallback}</AvatarFallback>
                </Avatar>
                <div className="grid flex-1 text-left text-sm leading-tight">
                  <span className="truncate font-medium">{user.name}</span>
                  {/*<span className="truncate text-xs">{user.email}</span>*/}
                </div>
                <ChevronsUpDownIcon className="ml-auto size-4" />
              </SidebarMenuButton>
            </DropdownMenuTrigger>
            <DropdownMenuContent
              className="w-(--radix-dropdown-menu-trigger-width) min-w-56 rounded-lg"
              side={isMobile ? "bottom" : "right"}
              align="end"
              sideOffset={4}
            >
              <DropdownMenuLabel className="p-0 font-normal">
                <div className="flex items-center gap-2 px-1 py-1.5 text-left text-sm">
                  <Avatar className="h-8 w-8 rounded-lg after:rounded-lg">
                    {user.avatar ? (
                      <AvatarImage className="rounded-lg" src={user.avatar} alt={user.name} />
                    ) : null}
                    <AvatarFallback className="rounded-lg">{fallback}</AvatarFallback>
                  </Avatar>
                  <div className="grid flex-1 text-left text-sm leading-tight">
                    <span className="truncate font-medium">{user.name}</span>
                    {/*<span className="truncate text-xs">{user.email}</span>*/}
                  </div>
                </div>
              </DropdownMenuLabel>
              <DropdownMenuSeparator />
              <ThemeSwitcher />
              <DropdownMenuSeparator />
              <DropdownMenuGroup>
                <DropdownMenuItem onClick={openAvatarUpload}>
                  <UserRound />
                  {t("changeAvatar")}
                </DropdownMenuItem>
                <DropdownMenuItem onClick={openUpdatePassword}>
                  <Key />
                  {t("changePassword")}
                </DropdownMenuItem>
                <DropdownMenuItem>
                  <BookOpen />
                  {t("documentation")}
                </DropdownMenuItem>
              </DropdownMenuGroup>
              <DropdownMenuSeparator />
              <DropdownMenuItem onClick={logoutUser}>
                <LogOutIcon />
                {t("signOut")}
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </SidebarMenuItem>
      </SidebarMenu>
      <input
        ref={fileInputRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={changeAvatarFile}
      />
      <AvatarUpload
        open={avatarOpen}
        image={image}
        name={user.name}
        onOpenChange={setAvatarOpen}
        onAvatarChange={updateAvatar}
      />
      <UpdatePassword
        open={passwordOpen}
        onOpenChange={setPasswordOpen}
      />
    </>
  )
}
