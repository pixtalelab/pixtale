import { dashboardService } from "@/server/service/dashboard-service"
import { DashboardProvider } from "./provider"
import { getProxyUser } from "@/server/lib/proxy-user";
import { UserTypeEnum } from "@/server/enums/user-enum";

interface DashboardLayoutProps {
  children: React.ReactNode
}

// 服务端查询仪表盘数据，并提供给仪表盘页面初始化展示。
export default async function DashboardLayout({ children }: DashboardLayoutProps) {

  const proxyUser = await getProxyUser()

  if (!proxyUser || proxyUser.type === UserTypeEnum.NORMAL) {
    return null
  }

  const [systemInfo, dashboardSummary] = await Promise.all([
    dashboardService.getSystemInfo(),
    dashboardService.getDashboardSummary(),
  ])

  return (
    <DashboardProvider
      initialSystemInfo={systemInfo}
      initialDashboardSummary={dashboardSummary}
    >
      {children}
    </DashboardProvider>
  )
}
