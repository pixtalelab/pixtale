// 这个模块定义系统采集 lib 的统一返回数据，容量单位均为字节。

interface SystemUsageVo {
  cpuUsage: number;
  memoryUsed: number;
  memoryTotal: number;
}

interface SystemInfoVo {
  cpuCount: number;
  memoryTotal: number;
  operatingSystem: string;
  architecture: string;
}

export type { SystemInfoVo, SystemUsageVo };
