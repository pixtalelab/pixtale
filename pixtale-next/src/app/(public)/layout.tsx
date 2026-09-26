import { NextIntlClientProvider } from "next-intl"
import { getMessages } from "next-intl/server"
import { cookies } from "next/headers"

import { PhotoProvider } from "@/app/(main)/photos/provider"
import { getLoginInfo } from "@/lib/cookie"
import { PHOTO_LIST_PAGE_SIZE } from "@/server/const/global"
import { photoService } from "@/server/service/photo-service"
import { settingService } from "@/server/service/setting-service"
import { PublicProvider } from "./provider"

interface PublicLayoutProps {
  children: React.ReactNode
}

// 服务端查询公开照片首屏数据，并提供照片页文案和初始化列表。
export default async function PublicLayout({ children }: PublicLayoutProps) {
  const [data, messages, setting, cookieStore] = await Promise.all([
    photoService.publicList({
      size: PHOTO_LIST_PAGE_SIZE,
      cursorPhotoId: null,
      cursorTime: null,
      favorite: null,
      status: null,
      albumId: null,
    }),
    getMessages(),
    settingService.get(),
    cookies(),
  ])
  const { userId } = await getLoginInfo(cookieStore.toString())

  return (
    <NextIntlClientProvider messages={{ albums: messages.albums, photos: messages.photos }}>
      <PublicProvider title={setting.title} isLoggedIn={Boolean(userId)} listStyle={setting.listStyle}>
        <PhotoProvider initialPhotos={data.list}>
          {children}
        </PhotoProvider>
      </PublicProvider>
    </NextIntlClientProvider>
  )
}
