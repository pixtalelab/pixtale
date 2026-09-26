import { PhotoProvider } from "@/app/(main)/photos/provider"
import { PHOTO_LIST_PAGE_SIZE } from "@/server/const/global"
import { albumService } from "@/server/service/album-service"
import { photoService } from "@/server/service/photo-service"
import { PublicAlbumPhotoProvider } from "./provider"

interface PublicAlbumPhotoLayoutProps {
  // children 是公开相册照片页面内容。
  children: React.ReactNode
  // params 保存当前公开相册路由参数。
  params: Promise<{ albumId: string }>
}

// 服务端查询公开相册照片，并提供给照片列表页面初始化。
export default async function PublicAlbumPhotoLayout({
  children,
  params,
}: PublicAlbumPhotoLayoutProps) {
  const { albumId } = await params
  const [album, data] = await Promise.all([
    albumService.publicGetById(albumId),
    photoService.publicList({
      size: PHOTO_LIST_PAGE_SIZE,
      cursorPhotoId: null,
      cursorTime: null,
      favorite: null,
      status: null,
      albumId,
    }),
  ])

  return (
    <PublicAlbumPhotoProvider albumName={album?.name ?? ""}>
      <PhotoProvider initialPhotos={data.list}>
        {children}
      </PhotoProvider>
    </PublicAlbumPhotoProvider>
  )
}
