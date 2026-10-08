import os from 'node:os';
import type { SystemInfoVo, SystemUsageVo } from '../../entity/vo/system';
import type { SystemInfoProvider } from './types';

// 这个模块通过 Node.js 采集 Windows 系统资源。

type CpuTimes = { idle: number; total: number };

let previousCpuTimes: CpuTimes | undefined;
let previousCpuUsage = 0;

// 读取所有逻辑核的累计 CPU 时间，并按字段名保留各状态的含义。
function readCpuTimes(): { idle: number; total: number } {
  return os.cpus().reduce(
    (times, cpu) => {
      const values = Object.values(cpu.times);
      return {
        idle: times.idle + cpu.times.idle,
        total: times.total + values.reduce((sum, value) => sum + value, 0),
      };
    },
    { idle: 0, total: 0 },
  );
}

// 按相邻采集的累计时间差计算非空闲比例，首次采集等待一秒建立有效区间。
async function getCpuUsage(): Promise<number> {
  let start = previousCpuTimes;
  if (!start) {
    start = readCpuTimes();
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }

  const end = readCpuTimes();
  previousCpuTimes = end;
  const startTimes: CpuTimes = start;

  // 计数器回退时忽略负增量，避免异常影响结果。
  const total = Math.max(end.total - startTimes.total, 0);
  const idle = Math.max(end.idle - startTimes.idle, 0);

  if (total > 0) {
    previousCpuUsage = Math.min(Math.max(Math.round((1 - idle / total) * 1000) / 10, 0), 100);
  }

  return previousCpuUsage;
}

const windowsSystemInfoProvider: SystemInfoProvider = {
  // 读取 Windows 当前 CPU 和内存使用情况。
  async getUsage(): Promise<SystemUsageVo> {
    const cpuUsage = await getCpuUsage();
    const memoryTotal = os.totalmem();
    return {
      cpuUsage,
      memoryTotal,
      memoryUsed: Math.max(memoryTotal - os.freemem(), 0),
    };
  },

  // 读取 Windows 主机静态信息和内存总量。
  async getInfo(): Promise<SystemInfoVo> {
    return {
      cpuCount: os.cpus().length,
      memoryTotal: os.totalmem(),
      operatingSystem: "Windows",
      architecture: os.arch(),
    };
  },
};

export { windowsSystemInfoProvider };
