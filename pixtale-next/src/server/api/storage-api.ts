import { app } from '../hono/hono';
import { Context } from 'hono';
import { type Storage, type StorageInto } from '@/server/entity/storage';
import { type StorageDeleteBo, type StorageSetTopBo, type StorageToggleStatusBo } from '@/server/entity/bo/storage';
import result from '@/server/model/result';
import { getUserId } from '@/server/security/context';
import { storageService } from '@/server/service/storage-service';

// 这个模块注册存储配置相关接口。

// 查询全部正常存储配置选项。
app.post('/storage/select', async (c: Context) => {
  const data = await storageService.select();
  return c.json(result.ok(data));
});

// 查询全部存储配置列表。
app.post('/storage/list', async (c: Context) => {
  const data = await storageService.list();
  return c.json(result.ok(data));
});

// 添加当前用户的存储配置。
app.post('/storage/add', async (c: Context) => {
  const body = await c.req.json<StorageInto>();
  await storageService.add(body, getUserId());
  return c.json(result.ok());
});

// 修改当前用户的存储配置，不返回业务数据。
app.post('/storage/set', async (c: Context) => {
  const body = await c.req.json<Storage>();
  await storageService.set(body);
  return c.json(result.ok());
});

// 把指定存储配置置顶，不返回业务数据。
app.post('/storage/setTop', async (c: Context) => {
  const body = await c.req.json<StorageSetTopBo>();
  await storageService.setTop(body);
  return c.json(result.ok());
});

// 切换指定存储配置的启用状态，不返回业务数据。
app.post('/storage/toggleStatus', async (c: Context) => {
  const body = await c.req.json<StorageToggleStatusBo>();
  await storageService.toggleStatus(body);
  return c.json(result.ok());
});

// 删除当前用户的指定存储配置，不返回业务数据。
app.post('/storage/delete', async (c: Context) => {
  const body = await c.req.json<StorageDeleteBo>();
  await storageService.delete(body.storageId);
  return c.json(result.ok());
});
