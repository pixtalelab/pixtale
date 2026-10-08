import os from 'node:os';
import { readFile } from 'node:fs/promises';
import type { SystemInfoVo, SystemUsageVo } from '../../entity/vo/system';
import type { SystemInfoProvider } from './types';

// 这个模块通过 /proc/stat 和 Node.js 采集 Linux 系统资源。

let previousCpuTimes: number[] | undefined;
let previousCpuUsage = 0;

// 读取整机累计 CPU 时间，guest 和 guest_nice 已包含在 user 和 nice 中，不重复计入。
async function readCpuTimes(): Promise<number[]> {
  const stat = await readFile('/proc/stat', 'utf8');
  const [label, ...fields] = stat.split('\n', 1)[0].trim().split(/\s+/);
  const times = fields.slice(0, 8).map(Number);

  if (label !== 'cpu' || times.length !== 8 || times.some((value) => !Number.isFinite(value) || value < 0)) {
    throw new Error('Invalid CPU counters in /proc/stat');
  }

  return times;
}

// 按相邻采集的累计时间差计算非空闲比例，首次采集等待一秒建立有效区间。
async function getCpuUsage(): Promise<number> {
  let start = previousCpuTimes;
  if (!start) {
    start = await readCpuTimes();
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }

  const end = await readCpuTimes();
  previousCpuTimes = end;
  const startTimes = start;

  // iowait 等计数可能回退；逐项忽略负增量，避免影响总时间。
  const deltas = end.map((value, index) => Math.max(value - startTimes[index], 0));
  const total = deltas.reduce((sum, value) => sum + value, 0);

  if (total > 0) {
    previousCpuUsage = Math.min(Math.max(Math.round((1 - deltas[3] / total) * 1000) / 10, 0), 100);
  }

  return previousCpuUsage;
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
