import type { SystemInfoVo, SystemUsageVo } from '../../entity/vo/system';

// 这个模块定义 Windows 和 Linux 采集器共同实现的接口。

interface SystemInfoProvider {
  // 采集 CPU 和内存实时使用情况。
  getUsage(): Promise<SystemUsageVo>;
  // 采集内存总量和系统标识信息。
  getInfo(): Promise<SystemInfoVo>;
}

export type { SystemInfoProvider };
