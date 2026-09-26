"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { useEffect } from "react"
import {
  SidebarGroup,
  SidebarGroupLabel,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar"
import { usePhotoStore } from "@/store/photo-store"

export function NavMain({
  items,
  label,
}: {
  items: {
    title: string
    url: string
    icon?: React.ReactNode
    isActive?: boolean
  }[]
  label?: string
}) {
  const pathname = usePathname()
  const setPageLoading = usePhotoStore((state) => state.setPageLoading)

  useEffect(() => {
    // 菜单路由切换完成后恢复照片图片加载。
    setPageLoading(false)
  }, [pathname, setPageLoading])

  // 判断当前浏览器路径是否命中菜单 URL。
  function isUrlMatched(url: string) {
    return pathname === url || pathname.startsWith(`${url}/`)
  }

  return (
    <SidebarGroup>
      {label && <SidebarGroupLabel>{label}</SidebarGroupLabel>}
      <SidebarMenu>
        {items.map((item) => (
          <SidebarMenuItem key={item.title} className="mb-1">
            <SidebarMenuButton asChild isActive={isUrlMatched(item.url)} tooltip={item.title}>
              <Link
                href={item.url}
                onClick={() => {
                  // 菜单开始切换时暂停未完成的照片图片请求。
                  setPageLoading(true)
                }}
              >
                {item.icon}
                <span >{item.title}</span>
              </Link>
            </SidebarMenuButton>
          </SidebarMenuItem>
        ))}
      </SidebarMenu>
    </SidebarGroup>
  )
}
