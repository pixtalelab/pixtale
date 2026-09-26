import { StorageProvider } from "./provider"
import { getProxyUser } from "@/server/lib/proxy-user"
import { UserTypeEnum } from "@/server/enums/user-enum"
import { storageService } from "@/server/service/storage-service"

interface StorageLayoutProps {
  children: React.ReactNode
}

// 服务端查询存储配置列表，并提供给 /storage 页面初始化表格。
export default async function StorageLayout({ children }: StorageLayoutProps) {
  const proxyUser = await getProxyUser()

  if (!proxyUser || proxyUser.type === UserTypeEnum.NORMAL) {
    return null
  }

  const data = await storageService.list()

  // 演示用户移除存储连接敏感字段，避免随首屏泄露。
  const list = proxyUser.type === UserTypeEnum.DEMO
    ? data.list.map((item) => ({
        ...item,
        accessKey: '******',
        secretKey: '******',
        endpoint: '******',
        bucket: '******',
        region: '******',
        domain: '******',
      }))
    : data.list

  return (
    <StorageProvider initialStorageList={list}>
      {children}
    </StorageProvider>
  )
}
