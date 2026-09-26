import { type StorageUsageVo } from '@/server/entity/vo/storage';
import { type PhotoTypeUsageVo } from '@/server/entity/vo/photo';

// 这个模块定义仪表盘接口返回对象。

interface DashboardSystemInfoVo {
  cpuUsage: DashboardCpuUsageVo[];
  memoryUsage: DashboardMemoryUsageVo[];
  currentCpuUsage: number;
  currentMemoryUsed: number;
  cpuCount: number;
  memoryTotal: number;
  operatingSystem: string;
  systemArchitecture: string;
}

interface DashboardCpuUsageVo {
  usage: number;
  createTime: string;
}

interface DashboardMemoryUsageVo {
  used: number;
  usedBytes: number;
  createTime: string;
}

interface DashboardSystemUsageVo {
  cpuUsage: DashboardCpuUsageVo[];
  memoryUsage: DashboardMemoryUsageVo[];
  currentCpuUsage: number;
  currentMemoryUsed: number;
}

interface DashboardSummaryVo {
  photoCount: number;
  photoTypeUsage: PhotoTypeUsageVo[];
  storageUsed: number;
  storageUsage: StorageUsageVo[];
  databaseUsed: number;
  userCount: number;
}

export type {
  DashboardSystemInfoVo,
  DashboardCpuUsageVo,
  DashboardMemoryUsageVo,
  DashboardSystemUsageVo,
  DashboardSummaryVo,
};
