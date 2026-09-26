"use client"

import * as React from "react"
import { NavMain } from "@/components/layout/nav-main"
import { NavUser } from "@/components/layout/nav-user"
import { useApp } from "@/app/(main)/provider"
import { UserTypeEnum } from "@/server/enums/user-enum"
import { useTranslations } from "next-intl"
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarRail,
} from "@/components/ui/sidebar"
import { Image, Heart, Trash2, FolderOpen, Database, User, Settings, ChartPie } from "lucide-react"

// 根据头像 key 生成头像图片访问地址。
function getAvatarUrl(avatar: string | undefined, fallbackAvatar: string) {
  return avatar ? `/api/user/avatar/${avatar}` : fallbackAvatar
}

// 渲染应用侧栏，并根据当前语言生成导航文案。
export function AppSidebar({ ...props }: React.ComponentProps<typeof Sidebar>) {
  const t = useTranslations("layout")
  const { userInfo, title } = useApp()
  // hasChineseTitle 用于判断站点名称是否包含中文字符。
  const hasChineseTitle = /[\u3400-\u9fff]/u.test(title)
  const data = {
    user: {
      name: "",
      email: null,
      avatar: "",
    },
    navMain: [
      { title: t("navigation.photos"), url: "/photos", icon: <Image />, isActive: false },
      { title: t("navigation.favorites"), url: "/favorites", icon: <Heart />, isActive: false },
      { title: t("navigation.albums"), url: "/albums", icon: <FolderOpen />, isActive: true },
      { title: t("navigation.trash"), url: "/trash", icon: <Trash2 />, isActive: false },
    ],
    sysMain: [
      { title: t("navigation.dashboard"), url: "/dashboard", icon: <ChartPie />, isActive: false },
      { title: t("navigation.storage"), url: "/storage", icon: <Database />, isActive: false },
      { title: t("navigation.users"), url: "/users", icon: <User />, isActive: false },
      { title: t("navigation.settings"), url: "/settings", icon: <Settings />, isActive: false },
    ],
  }
  // 管理员与演示用户可进入系统设置入口；写操作由后端安全中间件拦截。
  const canViewSystem = userInfo?.type === UserTypeEnum.ADMIN || userInfo?.type === UserTypeEnum.DEMO
  const navUser = {
    ...data.user,
    name: userInfo?.username ?? data.user.name,
    avatar: getAvatarUrl(userInfo?.avatar, data.user.avatar),
  }

  return (
    <Sidebar collapsible="icon" className="yarl__no_scroll_padding" {...props}>
      <SidebarHeader>
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton size="lg">
              <div className="flex aspect-square size-8 items-center justify-center rounded-lg">
                <img src="/assets/logo.png" alt="" className="size-7 object-contain" />
              </div>
              <div className="flex min-w-0 flex-col gap-0.5 leading-none">
                <span className={`truncate ${hasChineseTitle ? "text-base font-semibold" : "font-bahamas text-xl"}`}>{title}</span>
              </div>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarHeader>
      <SidebarContent>
        <NavMain items={data.navMain} />
        {canViewSystem && (
          <NavMain items={data.sysMain} label={t("systemSettings")} />
        )}
      </SidebarContent>
      <SidebarFooter>
        <NavUser user={navUser} />
      </SidebarFooter>
      <SidebarRail />
    </Sidebar>
  )
}
