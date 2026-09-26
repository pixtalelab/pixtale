import { AlbumProvider } from "./provider"
import { getProxyUser } from "@/server/lib/proxy-user"
import { albumService } from "@/server/service/album-service"

interface AlbumLayoutProps {
  children: React.ReactNode
}

// 服务端查询全部相册，并提供给 /album 页面初始化列表。
export default async function AlbumLayout({ children }: AlbumLayoutProps) {
  const proxyUser = await getProxyUser()

  if (!proxyUser) {
    return null
  }

  const data = await albumService.list(proxyUser.userId)

  return (
    <AlbumProvider initialAlbums={data}>
      {children}
    </AlbumProvider>
  )
}
