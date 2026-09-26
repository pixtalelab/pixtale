// 这个模块在 Next.js 服务启动时注册服务端定时任务。

export async function register() {

  if (process.env.NEXT_RUNTIME === 'edge' || process.env.VERCEL) {
    return
  }

  const { migrate } = await import('@/server/infra/migrate');
  await migrate();

  const { userService } = await import('@/server/service/user-service');
  await userService.init();

  const { dashboardService } = await import('@/server/service/dashboard-service');
  void dashboardService.startSystemUsageMonitor();

  const { startTasks } = await import('@/server/task');
  startTasks();
}
