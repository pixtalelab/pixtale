import { Context } from 'hono';
import { app } from '@/server/hono/hono';
import { type SyncCheckBo, type SyncConfigBo } from '@/server/entity/bo/sync';
import result from '@/server/model/result';
import { getUserId } from '@/server/security/context';
import { syncService } from '@/server/service/sync-service';

// 这个模块注册照片同步相关接口。

// 按名称查询当前用户可用的存储和相册配置。
app.post('/sync/getConfig', async (c: Context) => {
  const body = await c.req.json<SyncConfigBo>();
  const data = await syncService.getConfig(body, getUserId());
  return c.json(result.ok(data));
});

// 检查并返回当前用户照片库中不存在的文件。
app.post('/sync/check', async (c: Context) => {
  const body = await c.req.json<SyncCheckBo[]>();
  const data = await syncService.check(body, getUserId());
  return c.json(result.ok(data));
});
