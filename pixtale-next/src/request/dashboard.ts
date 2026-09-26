import { http } from "@/request/request"
import { type DashboardSystemUsageVo } from "@/server/entity/vo/dashboard"

// 这个模块封装仪表盘相关接口请求。

// 查询当前缓存中的 CPU 和内存历史数据。
export function dashboardSystemUsage() {
  return http.post<DashboardSystemUsageVo>("/dashboard/systemUsage")
}
