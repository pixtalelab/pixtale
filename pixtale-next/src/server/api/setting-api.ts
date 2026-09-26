import { app } from '../hono/hono';
import { Context } from 'hono';
import { type Setting } from '@/server/entity/setting';
import result from '@/server/model/result';
import { settingService } from '@/server/service/setting-service';

// 这个模块注册系统设置相关接口。

// 覆盖写入整份系统设置。
app.post('/setting/set', async (c: Context) => {
  const body = await c.req.json<Setting>();
  await settingService.set(body);
  return c.json(result.ok());
});
