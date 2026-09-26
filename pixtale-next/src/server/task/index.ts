import { clearExpiredCacheTask } from '@/server/task/cache-task';
import { clearExpiredPhotoTask } from '@/server/task/photo-task';

// 这个模块启动服务端定时任务。

const globalForTask = globalThis as typeof globalThis & { __albumTasksStarted?: boolean };

// 注册并启动全部定时任务，开发热更新时只启动一次。
function startTasks() {
  if (globalForTask.__albumTasksStarted) {
    return;
  }

  globalForTask.__albumTasksStarted = true;
  clearExpiredPhotoTask();
  clearExpiredCacheTask();
}

export { startTasks };
