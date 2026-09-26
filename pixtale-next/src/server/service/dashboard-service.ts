import {
  type DashboardCpuUsageVo,
  type DashboardMemoryUsageVo,
  type DashboardSystemUsageVo,
  type DashboardSystemInfoVo,
  type DashboardSummaryVo,
} from '@/server/entity/vo/dashboard';
import { DASHBOARD_CPU_USAGE_CACHE_KEY, DASHBOARD_MEMORY_USAGE_CACHE_KEY } from '@/server/const/cache';
import { cache } from '@/server/infra/cache';
import { photoService } from '@/server/service/photo-service';
import { storageService } from '@/server/service/storage-service';
import { userService } from '@/server/service/user-service';
import { systemInfo } from '@/server/lib/system';

// 这个模块处理系统资源监控相关业务。

const SYSTEM_USAGE_INTERVAL = 2000;
const SYSTEM_USAGE_MAX_SIZE = 30;

const dashboardService = {

  // 汇总照片、存储、数据库和用户统计数据。
  async getDashboardSummary(): Promise<DashboardSummaryVo> {
    const [photoCount, photoTypeUsage, storageUsed, storageUsage, databaseUsed, userCount] = await Promise.all([
      photoService.getAllCount(),
      photoService.getTopTypeUsage(),
      photoService.getAllSize(),
      storageService.getTopStorageUsage(),
      storageService.getDatabaseSize(),
      userService.getAllCount(),
    ]);

    // 超过五种类型时保留前四项，其余数量合并为其他，保持饼图总量一致。
    if (photoTypeUsage.length > 5) {
      const visibleTypes = photoTypeUsage.slice(0, 4);
      const visibleCount = visibleTypes.reduce((total, item) => total + item.count, 0);

      photoTypeUsage.length = 0;
      photoTypeUsage.push(...visibleTypes, {
        typeDesc: 'other',
        count: photoCount - visibleCount,
      });
    }

    if (storageUsage.length > 5) {
      const visibleStorageUsage = storageUsage.slice(0, 4);
      const visibleStorageUsageTotal = visibleStorageUsage.reduce((total, item) => total + item.size, 0);

      storageUsage.length = 0;
      storageUsage.push(...visibleStorageUsage);
      storageUsage.push({
        storageId: 'other',
        name: 'Other',
        size: storageUsed - visibleStorageUsageTotal,
      });
    }

    return { photoCount, photoTypeUsage, storageUsed, storageUsage, databaseUsed, userCount };
  },

  // 立即采集系统资源，并在每轮完成后安排下一次采集。
  async startSystemUsageMonitor(): Promise<void> {
    const collectAndSchedule = async (): Promise<void> => {
      await this.saveSystemUsage();

      setTimeout(() => {
        void collectAndSchedule();
      }, SYSTEM_USAGE_INTERVAL);
    };

    await collectAndSchedule();
  },

  // 读取当前 CPU 和内存数据，并追加到对应缓存数组。
  async saveSystemUsage(): Promise<void> {
    try {
      const usage = await systemInfo.getUsage();
      const createTime = new Date().toISOString();

      await Promise.all([
        this.appendUsage<DashboardCpuUsageVo>(DASHBOARD_CPU_USAGE_CACHE_KEY, {
          usage: usage.cpuUsage,
          createTime,
        }),
        this.appendUsage<DashboardMemoryUsageVo>(DASHBOARD_MEMORY_USAGE_CACHE_KEY, {
          used: usage.memoryTotal > 0 ? Math.floor((usage.memoryUsed / usage.memoryTotal) * 100) : 0,
          usedBytes: usage.memoryUsed,
          createTime,
        }),
      ]);
    } catch (error) {
      console.error('Failed to save system usage:', error);
    }
  },

  // 读取缓存数组，删除最早记录后追加新记录并写回缓存。
  async appendUsage<T extends object>(key: string, item: T): Promise<void> {
    const list = (await cache.get<T[]>(key)) ?? [];

    if (list.length >= SYSTEM_USAGE_MAX_SIZE) {
      list.shift();
    }

    list.push(item);
    await cache.set(key, list);
  },

  // 查询当前缓存中的 CPU 和内存历史数据。
  async getSystemUsage(): Promise<DashboardSystemUsageVo> {
    const [cpuUsage, memoryUsage] = await Promise.all([
      cache.get<DashboardCpuUsageVo[]>(DASHBOARD_CPU_USAGE_CACHE_KEY),
      cache.get<DashboardMemoryUsageVo[]>(DASHBOARD_MEMORY_USAGE_CACHE_KEY),
    ]);

    return {
      cpuUsage: cpuUsage ?? [],
      memoryUsage: memoryUsage ?? [],
      currentCpuUsage: cpuUsage?.at(-1)?.usage ?? 0,
      currentMemoryUsed: memoryUsage?.at(-1)?.usedBytes ?? 0,
    };
  },

  // 查询当前服务器 CPU、内存使用情况和系统信息。
  async getSystemInfo(): Promise<DashboardSystemInfoVo> {
    const [cpuUsage, memoryUsage, info] = await Promise.all([
      cache.get<DashboardCpuUsageVo[]>(DASHBOARD_CPU_USAGE_CACHE_KEY),
      cache.get<DashboardMemoryUsageVo[]>(DASHBOARD_MEMORY_USAGE_CACHE_KEY),
      systemInfo.getInfo(),
    ]);

    return {
      cpuUsage: cpuUsage ?? [],
      memoryUsage: memoryUsage ?? [],
      currentCpuUsage: cpuUsage?.at(-1)?.usage ?? 0,
      currentMemoryUsed: memoryUsage?.at(-1)?.usedBytes ?? 0,
      cpuCount: info.cpuCount,
      memoryTotal: info.memoryTotal,
      operatingSystem: info.operatingSystem,
      systemArchitecture: info.architecture,
    };
  },
};

export { dashboardService };
