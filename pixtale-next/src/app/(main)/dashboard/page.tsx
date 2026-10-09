"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { Database, HardDrive, Images, Users } from "lucide-react";
import {
  Area,
  AreaChart,
  CartesianGrid,
  Pie,
  PieChart,
  XAxis,
  YAxis,
} from "recharts";
import { type DashboardSystemInfoVo } from "@/server/entity/vo/dashboard";
import { useApp } from "@/app/(main)/provider";
import { AppSidebar } from "@/components/layout/app-sidebar";
import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbList,
  BreadcrumbPage,
} from "@/components/ui/breadcrumb";
import { Separator } from "@/components/ui/separator";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  SidebarInset,
  SidebarProvider,
  SidebarTrigger,
} from "@/components/ui/sidebar";
import {
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
  type ChartConfig,
} from "@/components/ui/chart";
import { formatCapacity } from "@/lib/file";
import { dashboardSystemUsage } from "@/request/dashboard";
import { useDashboardContext } from "./provider";

const cpuConfig = {
  cpu: { label: "CPU", color: "#2b7fff" },
} satisfies ChartConfig;
const memoryConfig = {
  memory: { label: "Memory", color: "#982eb6" },
} satisfies ChartConfig;
// 两张饼图分别使用独立调色板，数据项按颜色数组顺序映射。
const photoTypeColors = ["#0868ac", "#43a2ca", "#7bccc4", "#bae4bc", "#f0f9e8"];
const storageColors = ["#0868ac", "#43a2ca", "#7bccc4", "#bae4bc", "#f0f9e8"];
// 内存容量在 GB 以下四舍五入为整数，GB 及以上保留一位小数。
function formatMemoryCapacity(size: number) {
  return formatCapacity(size, size < 1024 ** 3 ? 0 : 1);
}

// 把服务端返回的 CPU 和内存历史数据转换为图表数据。
function createResourceUsage(systemInfo: DashboardSystemInfoVo) {
  const size = Math.max(
    systemInfo.cpuUsage.length,
    systemInfo.memoryUsage.length,
  );

  return Array.from({ length: size }, (_, index) => ({
    time: String(Math.round(60 - (index * 60) / Math.max(size - 1, 1))),
    cpu: systemInfo.cpuUsage[index]?.usage ?? 0,
    memory: systemInfo.memoryUsage[index]?.used ?? 0,
    memoryBytes: systemInfo.memoryUsage[index]?.usedBytes ?? 0,
    cpuCreatedAt: systemInfo.cpuUsage[index]?.createTime,
    memoryCreatedAt: systemInfo.memoryUsage[index]?.createTime,
  }));
}

// 将采样时间转换为浏览器本地时分秒。
function formatUsageTime(createTime?: string) {
  if (!createTime) {
    return "";
  }

  return new Date(createTime).toLocaleTimeString("en-GB", {
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  });
}

// 渲染仪表盘页面。
export default function Page() {
  const t = useTranslations("dashboard");
  const { sidebarOpen, setSidebarOpen } = useApp();
  const { initialSystemInfo, initialDashboardSummary } = useDashboardContext();
  // systemInfo 保存服务端初始数据和短轮询更新后的系统数据。
  const [systemInfo, setSystemInfo] = useState(initialSystemInfo);

  useEffect(() => {
    let active = true;
    let timer: ReturnType<typeof setTimeout> | undefined;

    // 顺序请求最新资源数据，完成后再安排下一轮轮询。
    const pollSystemUsage = async () => {
      try {
        const usage = await dashboardSystemUsage();

        if (active) {
          setSystemInfo((current) => ({
            ...current,
            cpuUsage: usage.cpuUsage,
            memoryUsage: usage.memoryUsage,
            currentCpuUsage: usage.currentCpuUsage,
            currentMemoryUsed: usage.currentMemoryUsed,
          }));
        }
      } catch {
        // 请求失败时保留上一轮数据，等待下一次轮询重试。
      }

      if (active) {
        timer = setTimeout(() => {
          void pollSystemUsage();
        }, 3000);
      }
    };

    void pollSystemUsage();

    return () => {
      active = false;
      if (timer) {
        clearTimeout(timer);
      }
    };
  }, []);

  const resourceUsage = createResourceUsage(systemInfo);
  // photoTypeUsage 将类型分组数量转换为切片，使用稳定的图表键避免类型名影响 CSS。
  const photoTypeUsage = initialDashboardSummary.photoTypeUsage.map((item, index) => ({
    typeId: `type-${index}`,
    name: item.typeDesc === "other" ? t("other") : item.typeDesc.toUpperCase(),
    value: item.count,
    fill: photoTypeColors[index % photoTypeColors.length],
  }));
  // photoTypeConfig 将切片标识关联到类型名称和对应颜色。
  const photoTypeConfig: ChartConfig = Object.fromEntries(
    photoTypeUsage.map((item) => [item.typeId, { label: item.name, color: item.fill }]),
  );
  // storageUsage 将服务端返回的存储用量转换为饼图切片。
  const storageUsage = [
    ...initialDashboardSummary.storageUsage.map((item, index) => ({
      ...item,
      name: item.storageId === "other" ? t("other") : item.name,
      value: item.size,
      fill: storageColors[index % storageColors.length],
    })),
  ];
  // storageConfig 用存储 ID 关联图例名称与切片颜色。
  const storageConfig: ChartConfig = Object.fromEntries(
    storageUsage.map((item) => [item.storageId, { label: item.name, color: item.fill }]),
  );

  return (
    <SidebarProvider open={sidebarOpen} onOpenChange={setSidebarOpen}>
      <AppSidebar />
      <SidebarInset>
        <header className="flex h-13 shrink-0 items-center gap-2 bg-background">
          <div className="flex min-w-0 items-center gap-2 px-4">
            <SidebarTrigger className="-ml-1" />
            <Separator orientation="vertical" className="mr-2 data-vertical:h-4 data-vertical:self-auto"/>
            <Breadcrumb>
              <BreadcrumbList>
                <BreadcrumbItem>
                  <BreadcrumbPage>{t("title")}</BreadcrumbPage>
                </BreadcrumbItem>
              </BreadcrumbList>
            </Breadcrumb>
          </div>
        </header>
        <main className="flex flex-1 flex-col gap-4 px-4 py-4 md:gap-5 md:px-6 md:py-4">
          <div className="grid gap-5 sm:grid-cols-2 xl:grid-cols-4">
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">
                  {t("photoCount")}
                </CardTitle>
                <Images className="size-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">
                  {initialDashboardSummary.photoCount.toLocaleString()}
                </div>
                <CardDescription>{t("photoCountDescription")}</CardDescription>
              </CardContent>
            </Card>
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">
                  {t("storageUsed")}
                </CardTitle>
                <HardDrive className="size-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">
                  {formatCapacity(initialDashboardSummary.storageUsed)}
                </div>
                <CardDescription>{t("storageUsedDescription")}</CardDescription>
              </CardContent>
            </Card>
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">
                  {t("databaseUsed")}
                </CardTitle>
                <Database className="size-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">
                  {formatCapacity(initialDashboardSummary.databaseUsed)}
                </div>
                <CardDescription>{t("databaseUsedDescription")}</CardDescription>
              </CardContent>
            </Card>
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">
                  {t("userCount")}
                </CardTitle>
                <Users className="size-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">
                  {initialDashboardSummary.userCount.toLocaleString()}
                </div>
                <CardDescription>{t("userCountDescription")}</CardDescription>
              </CardContent>
            </Card>
          </div>
          <div className="grid gap-5 md:grid-cols-2">
            <Card>
              <CardHeader>
                <div className="flex items-center justify-between gap-4">
                  <CardTitle className="text-sm font-medium">
                    {t("cpu")}
                  </CardTitle>
                  <span className="text-sm font-medium">
                    {systemInfo.currentCpuUsage}%
                  </span>
                </div>
              </CardHeader>
              <CardContent className="px-2 pt-2 sm:px-4 sm:pt-4">
                <ChartContainer config={cpuConfig} className="aspect-auto h-[200px] w-full">
                  <AreaChart data={resourceUsage}>
                    <defs>
                      <linearGradient id="fillCpu" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor="var(--color-cpu)" stopOpacity={0.8}/>
                        <stop offset="95%" stopColor="var(--color-cpu)" stopOpacity={0.1}/>
                      </linearGradient>
                    </defs>
                    <CartesianGrid vertical={false} />
                    <XAxis
                      dataKey="time"
                      type="category"
                      ticks={["60", "0"]}
                      tickFormatter={(value: string) => value === "60" ? "60s" : value}
                      interval={0}
                      tickLine={false}
                      axisLine={false}
                      tickMargin={8}
                    />
                    <YAxis
                      domain={[0, 100]}
                      ticks={[0, 25, 50, 75, 100]}
                      tickFormatter={(value: number) => String(value)}
                      tickLine={false}
                      axisLine={false}
                      width={26}
                    />
                    <ChartTooltip
                      cursor={false}
                      content={
                        <ChartTooltipContent
                          indicator="dot"
                          valueFormatter={(value) => `${value}%`}
                          labelFormatter={(_, payload) =>
                            formatUsageTime(payload[0]?.payload?.cpuCreatedAt)
                          }
                        />
                      }
                    />
                    <Area type="monotoneX" dataKey="cpu" stroke="var(--color-cpu)" fill="url(#fillCpu)" strokeWidth={2} dot={false} activeDot={{ r: 4 }} isAnimationActive={false}/>
                  </AreaChart>
                </ChartContainer>
              </CardContent>
            </Card>
            <Card>
              <CardHeader>
                <div className="flex items-center justify-between gap-4">
                  <CardTitle className="text-sm font-medium">
                    {t("memory")}
                  </CardTitle>
                  <span className="text-sm font-medium">
                    {formatMemoryCapacity(systemInfo.currentMemoryUsed)} /{" "}
                    {formatMemoryCapacity(systemInfo.memoryTotal)}
                  </span>
                </div>
              </CardHeader>
              <CardContent className="px-2 pt-2 sm:px-4 sm:pt-4">
                <ChartContainer config={memoryConfig} className="aspect-auto h-[200px] w-full">
                  <AreaChart data={resourceUsage}>
                    <defs>
                      <linearGradient id="fillMemory" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor="var(--color-memory)" stopOpacity={0.8}/>
                        <stop offset="95%" stopColor="var(--color-memory)" stopOpacity={0.1}/>
                      </linearGradient>
                    </defs>
                    <CartesianGrid vertical={false} />
                    <XAxis
                      dataKey="time"
                      type="category"
                      ticks={["60", "0"]}
                      tickFormatter={(value: string) => value === "60" ? "60s" : value}
                      interval={0}
                      tickLine={false}
                      axisLine={false}
                      tickMargin={8}
                    />
                    <YAxis
                      domain={[0, 100]}
                      ticks={[0, 25, 50, 75, 100]}
                      tickFormatter={(value: number) => String(value)}
                      tickLine={false}
                      axisLine={false}
                      width={26}
                    />
                    <ChartTooltip
                      cursor={false}
                      content={
                        <ChartTooltipContent
                          indicator="dot"
                          formatter={(_, _name, item) => (
                            <>
                              <span
                                className="size-2.5 shrink-0 rounded-[2px]"
                                style={{ backgroundColor: item.color }}
                              />
                              <div className="flex flex-1 justify-between gap-4">
                                <span className="text-muted-foreground">
                                  {memoryConfig.memory.label}
                                </span>
                                <span className="font-mono font-medium text-foreground tabular-nums">
                                  {formatMemoryCapacity(Number(item.payload.memoryBytes))}
                                </span>
                              </div>
                            </>
                          )}
                          labelFormatter={(_, payload) =>
                            formatUsageTime(payload[0]?.payload?.memoryCreatedAt)
                          }
                        />
                      }
                    />
                    <Area type="monotoneX" dataKey="memory" stroke="var(--color-memory)" fill="url(#fillMemory)" strokeWidth={2} dot={false} activeDot={{ r: 4 }} isAnimationActive={false}/>
                  </AreaChart>
                </ChartContainer>
              </CardContent>
            </Card>
          </div>
          <div className="grid gap-5 md:grid-cols-3">
            <Card>
              <CardHeader>
                <CardTitle className="text-sm font-medium">
                  {t("photoTypes")}
                </CardTitle>
              </CardHeader>
              <CardContent>
                <ChartContainer config={photoTypeConfig} className="h-[180px] w-full">
                  <PieChart>
                    <ChartTooltip
                      content={
                        <ChartTooltipContent
                          hideLabel
                          nameKey="typeId"
                          valueFormatter={(value) => Number(value).toLocaleString()}
                        />
                      }
                    />
                    <Pie data={photoTypeUsage} dataKey="value" nameKey="name" innerRadius={52} outerRadius={72} strokeWidth={3} isAnimationActive={false}/>
                  </PieChart>
                </ChartContainer>
              </CardContent>
            </Card>
            <Card>
              <CardHeader>
                <CardTitle className="text-sm font-medium">
                  {t("storage")}
                </CardTitle>
              </CardHeader>
              <CardContent>
                <ChartContainer config={storageConfig} className="h-[180px] w-full">
                  <PieChart>
                    <ChartTooltip
                      content={
                        <ChartTooltipContent
                          hideLabel
                          nameKey="storageId"
                          valueFormatter={(value) => formatCapacity(Number(value))}
                        />
                      }
                    />
                    <Pie data={storageUsage} dataKey="value" nameKey="name" innerRadius={52} outerRadius={72} strokeWidth={3} isAnimationActive={false}/>
                  </PieChart>
                </ChartContainer>
              </CardContent>
            </Card>
            <Card>
              <CardHeader>
                <CardTitle className="text-sm font-medium">
                  {t("systemInfo")}
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-3 text-sm">
                  <div className="flex items-center justify-between gap-4">
                    <span className="text-muted-foreground">
                      {t("operatingSystem")}
                    </span>
                    <span className="font-medium">
                      {systemInfo.operatingSystem || "-"}
                    </span>
                  </div>
                  <div className="flex items-center justify-between gap-4">
                    <span className="text-muted-foreground">
                      {t("systemArchitecture")}
                    </span>
                    <span className="font-medium">
                      {systemInfo.systemArchitecture || "-"}
                    </span>
                  </div>
                  <div className="flex items-center justify-between gap-4">
                    <span className="text-muted-foreground">
                      {t("cpuCount")}
                    </span>
                    <span className="font-medium">
                      {systemInfo.cpuCount > 0 ? `${systemInfo.cpuCount}${t("cpuCountUnit")}` : "-"}
                    </span>
                  </div>
                  <div className="flex items-center justify-between gap-4">
                    <span className="text-muted-foreground">
                      {t("memoryTotal")}
                    </span>
                    <span className="font-medium">
                      {formatMemoryCapacity(systemInfo.memoryTotal)}
                    </span>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        </main>
      </SidebarInset>
    </SidebarProvider>
  );
}
