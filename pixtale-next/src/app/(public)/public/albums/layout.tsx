import { albumService } from "@/server/service/album-service"
import { PublicAlbumProvider } from "./provider"

interface PublicAlbumLayoutProps {
  // children 是公开相册页面内容。
  children: React.ReactNode
}

// 服务端查询公开相册，并提供给公开相册页面初始化列表。
export default async function PublicAlbumLayout({ children }: PublicAlbumLayoutProps) {
  const albums = await albumService.publicList()

  return (
    <PublicAlbumProvider initialAlbums={albums}>
      {children}
    </PublicAlbumProvider>
  )
}
