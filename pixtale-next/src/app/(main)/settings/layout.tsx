import { SettingProvider } from "./provider"
import { getProxyUser } from "@/server/lib/proxy-user"
import { UserTypeEnum } from "@/server/enums/user-enum"
import { settingService } from "@/server/service/setting-service"

interface SettingLayoutProps {
  children: React.ReactNode
}

// 服务端查询系统设置，并提供给 /setting 页面初始化展示。
export default async function SettingLayout({ children }: SettingLayoutProps) {
  const proxyUser = await getProxyUser()

  if (!proxyUser || proxyUser.type === UserTypeEnum.NORMAL) {
    return null
  }

  const initialSetting = await settingService.get()

  return (
    <SettingProvider initialSetting={initialSetting}>
      {children}
    </SettingProvider>
  )
}
