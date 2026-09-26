import os from 'node:os';
import type { SystemInfoVo, SystemUsageVo } from '../../entity/vo/system';
import type { SystemInfoProvider } from './types';

// 这个模块通过 Node.js 采集 Linux 系统资源。

// 通过两次 CPU 时间采样计算一段时间内的平均使用率。
async function getCpuUsage(): Promise<number> {
  const start = os.cpus();
  await new Promise((resolve) => setTimeout(resolve, 100));
  const end = os.cpus();
  let idle = 0;
  let total = 0;

  end.forEach((cpu, index) => {
    const startCpu = start[index];
    if (!startCpu) {
      return;
    }

    const startTotal = Object.values(startCpu.times).reduce((sum, value) => sum + value, 0);
    const endTotal = Object.values(cpu.times).reduce((sum, value) => sum + value, 0);
    idle += cpu.times.idle - startCpu.times.idle;
    total += endTotal - startTotal;
  });

  return total > 0 ? Math.min(Math.max(Math.floor((1 - idle / total) * 100), 0), 100) : 0;
}

const linuxSystemInfoProvider: SystemInfoProvider = {
  // 读取 Linux 当前 CPU 和内存使用情况。
  async getUsage(): Promise<SystemUsageVo> {
    const cpuUsage = await getCpuUsage();
    const memoryTotal = os.totalmem();
    return {
      cpuUsage,
      memoryTotal,
      memoryUsed: Math.max(memoryTotal - os.freemem(), 0),
    };
  },

  // 读取 Linux 主机静态信息和内存总量。
  async getInfo(): Promise<SystemInfoVo> {
    return {
      cpuCount: os.cpus().length,
      memoryTotal: os.totalmem(),
      operatingSystem: os.type(),
      architecture: os.arch(),
    };
  },
};

export { linuxSystemInfoProvider };
