"use client"

import { createContext, useContext } from "react"
import {
  type DashboardSummaryVo,
  type DashboardSystemInfoVo,
} from "@/server/entity/vo/dashboard"

interface DashboardContextValue {
  // initialSystemInfo 保存服务端查询到的仪表盘系统数据。
  initialSystemInfo: DashboardSystemInfoVo
  // initialDashboardSummary 保存服务端查询到的仪表盘汇总数据。
  initialDashboardSummary: DashboardSummaryVo
}

interface DashboardProviderProps {
  // children 是仪表盘页面内容。
  children: React.ReactNode
  // initialSystemInfo 保存服务端预取的仪表盘系统数据。
  initialSystemInfo: DashboardSystemInfoVo
  // initialDashboardSummary 保存服务端预取的仪表盘汇总数据。
  initialDashboardSummary: DashboardSummaryVo
}

const DashboardContext = createContext<DashboardContextValue | null>(null)

// 读取仪表盘页面服务端预取的系统数据。
function useDashboardContext() {
  const context = useContext(DashboardContext)

  if (!context) {
    throw new Error("useDashboardContext must be used within DashboardProvider.")
  }

  return context
}

// 给仪表盘客户端组件提供服务端预取数据。
function DashboardProvider({
  children,
  initialSystemInfo,
  initialDashboardSummary,
}: DashboardProviderProps) {
  return (
    <DashboardContext.Provider value={{ initialSystemInfo, initialDashboardSummary }}>
      {children}
    </DashboardContext.Provider>
  )
}

export { DashboardProvider, useDashboardContext }
