import { app } from '../hono/hono';
import { Context } from 'hono';
import result from '@/server/model/result';
import { getUserId } from '@/server/security/context';
import { albumService } from '@/server/service/album-service';
import { type AlbumAddBo, type AlbumAddPhotoBo, type AlbumDeleteBo, type AlbumRecycleBo, type AlbumRemovePhotoBo, type AlbumSetNameBo, type AlbumSetPublicBo, type AlbumSetTopBo } from '@/server/entity/bo/album';

// 这个模块注册相册相关接口。

// 查询当前用户的相册列表。
app.post('/album/list', async (c: Context) => {
  const data = await albumService.list(getUserId());
  return c.json(result.ok(data));
});

// 查询当前用户可选择的相册列表。
app.post('/album/select', async (c: Context) => {
  const data = await albumService.select(getUserId());
  return c.json(result.ok(data));
});

// 查询当前用户的回收站虚拟相册。
app.post('/album/trash', async (c: Context) => {
  const album = await albumService.trash(getUserId());
  return c.json(result.ok(album));
});

// 添加当前用户的相册。
app.post('/album/add', async (c: Context) => {
  const body = await c.req.json<AlbumAddBo>();
  const album = await albumService.add(body, getUserId());
  return c.json(result.ok(album));
});

// 给当前用户指定相册添加照片。
app.post('/album/addPhoto', async (c: Context) => {
  const body = await c.req.json<AlbumAddPhotoBo>();
  await albumService.addPhoto(body, getUserId());
  return c.json(result.ok());
});

// 移除当前用户指定相册中的照片关联。
app.post('/album/removePhoto', async (c: Context) => {
  const body = await c.req.json<AlbumRemovePhotoBo>();
  await albumService.removePhoto(body, getUserId());
  return c.json(result.ok());
});

// 修改当前用户指定相册的名称。
app.post('/album/setName', async (c: Context) => {
  const body = await c.req.json<AlbumSetNameBo>();
  await albumService.setName(body, getUserId());
  return c.json(result.ok());
});

// 把当前用户指定相册置顶。
app.post('/album/setTop', async (c: Context) => {
  const body = await c.req.json<AlbumSetTopBo>();
  await albumService.setTop(body, getUserId());
  return c.json(result.ok());
});

// 修改当前用户指定相册的公开状态。
app.post('/album/setPublic', async (c: Context) => {
  const body = await c.req.json<AlbumSetPublicBo>();
  await albumService.setPublic(body, getUserId());
  return c.json(result.ok());
});

// 把当前用户指定相册中的照片移入回收站，保留相册。
app.post('/album/recycle', async (c: Context) => {
  const body = await c.req.json<AlbumRecycleBo>();
  await albumService.recycle(body, getUserId());
  return c.json(result.ok());
});

// 删除当前用户指定相册，并清理相册照片关联。
app.post('/album/delete', async (c: Context) => {
  const body = await c.req.json<AlbumDeleteBo>();
  await albumService.delete(body, getUserId());
  return c.json(result.ok());
});
