import { type ReactNode } from "react"

interface SettingItemProps {
  // title 是设置项左侧显示的标题。
  title: string
  // description 是设置项标题下方的说明。
  description?: string
  // children 是设置项右侧的自定义内容。
  children: ReactNode
}

// 渲染系统设置页面里的单个设置项。
export function SettingItem({ title, description, children }: SettingItemProps) {
  return (
    <div>
      <div className="flex flex-col items-start gap-5 md:flex-row md:items-center md:justify-between py-3 md:py-5">
        <div className="min-w-0 space-y-1 md:w-1/2">
          <h2 className="text-base font-medium">{title}</h2>
          {description && (
            <p className="text-sm text-muted-foreground">{description}</p>
          )}
        </div>
        <div className="flex w-full items-center justify-start md:w-1/2">
          {children}
        </div>
      </div>
    </div>
  )
}
