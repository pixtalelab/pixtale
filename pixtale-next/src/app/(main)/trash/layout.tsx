import { TrashProvider } from "./provider"
import { getProxyUser } from "@/server/lib/proxy-user"
import { albumService } from "@/server/service/album-service"

interface TrashLayoutProps {
  children: React.ReactNode
}

// 服务端查询回收站虚拟相册，并提供给 /trash 页面初始化入口。
export default async function TrashLayout({ children }: TrashLayoutProps) {
  const proxyUser = await getProxyUser()

  if (!proxyUser) {
    return null
  }

  const data = await albumService.trash(proxyUser.userId)

  return (
    <TrashProvider initialAlbum={data}>
      {children}
    </TrashProvider>
  )
}
