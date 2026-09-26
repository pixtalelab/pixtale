import { PhotoProvider } from "./provider"
import { getProxyUser } from "@/server/lib/proxy-user"
import { PHOTO_LIST_PAGE_SIZE } from "@/server/const/global"
import { photoService } from "@/server/service/photo-service"

interface PhotoLayoutProps {
  children: React.ReactNode
}

// 服务端查询照片第一页，并提供给 /photo 页面初始化列表。
export default async function PhotoLayout({ children }: PhotoLayoutProps) {
  const proxyUser = await getProxyUser()

  if (!proxyUser) {
    return null
  }

  const data = await photoService.list({
    size: PHOTO_LIST_PAGE_SIZE,
    cursorPhotoId: null,
    cursorTime: null,
    favorite: null,
    status: null,
    albumId: null,
  }, proxyUser.userId)

  return (
    <PhotoProvider initialPhotos={data.list}>
      {children}
    </PhotoProvider>
  )
}
