import { UserProvider } from "./provider"
import { getProxyUser } from "@/server/lib/proxy-user"
import { UserTypeEnum } from "@/server/enums/user-enum"
import { userService } from "@/server/service/user-service"

interface UserLayoutProps {
  children: React.ReactNode
}

// 服务端查询用户列表，并提供给 /user 页面初始化表格。
export default async function UserLayout({ children }: UserLayoutProps) {
  const proxyUser = await getProxyUser()

  if (!proxyUser || proxyUser.type === UserTypeEnum.NORMAL) {
    return null
  }

  const data = await userService.list()

  return (
    <UserProvider initialUserList={data.list}>
      {children}
    </UserProvider>
  )
}
