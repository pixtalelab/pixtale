import { Context } from 'hono';
import { app } from '../hono/hono';
import result from '@/server/model/result';
import { dashboardService } from '@/server/service/dashboard-service';

// 这个模块注册仪表盘相关接口。

// 查询仪表盘顶部统计数据。
app.post('/dashboard/summary', async (c: Context) => {
  const data = await dashboardService.getDashboardSummary();
  return c.json(result.ok(data));
});

// 查询当前服务器实时资源使用情况。
app.post('/dashboard/systemInfo', async (c: Context) => {
  const data = await dashboardService.getSystemInfo();
  return c.json(result.ok(data));
});

// 查询当前缓存中的 CPU 和内存历史数据。
app.post('/dashboard/systemUsage', async (c: Context) => {
  const data = await dashboardService.getSystemUsage();
  return c.json(result.ok(data));
});
