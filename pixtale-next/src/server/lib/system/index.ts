import os from 'node:os';
import { linuxSystemInfoProvider } from './linux';
import { windowsSystemInfoProvider } from './win';
import type { SystemInfoProvider } from './types';
import type { SystemInfoVo, SystemUsageVo } from '../../entity/vo/system';

// 这个模块根据运行平台选择系统信息采集实现，并对外提供统一入口。

// 根据平台选择对应采集器，明确拒绝未支持的平台。
function getSystemInfoProvider(): SystemInfoProvider {
  switch (os.platform()) {
    case 'win32':
      return windowsSystemInfoProvider;
    default:
      return linuxSystemInfoProvider;
  }
}

const systemInfo = {
  // 读取当前平台的 CPU、内存使用情况。
  getUsage(): Promise<SystemUsageVo> {
    return getSystemInfoProvider().getUsage();
  },

  // 读取当前平台的内存总量和系统静态信息。
  getInfo(): Promise<SystemInfoVo> {
    return getSystemInfoProvider().getInfo();
  },
};

export { systemInfo };
