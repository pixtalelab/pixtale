import { app } from '../hono/hono';
import { Context } from "hono";
import result from '@/server/model/result';
import { photoService } from '@/server/service/photo-service';
import { getUserId } from "@/server/security/context";
import { type PhotoDeleteBo, type PhotoExistsBo, type PhotoFavoriteBo, type PhotoListBo, type PhotoRecycleBo, type PhotoRestoreBo, type PhotoTakenDateListBo } from '@/server/entity/bo/photo';

// 这个模块注册照片相关接口。

// 分页按条件查询当前用户的照片列表。
app.post('/photo/list', async (c: Context) => {
  const body = await c.req.json<PhotoListBo>();
  const data = await photoService.list(body, getUserId());
  return c.json(result.ok(data));
})

// 分页查询公开相册中的照片列表。
app.post('/photo/publicList', async (c: Context) => {
  const body = await c.req.json<PhotoListBo>();
  const data = await photoService.publicList(body);
  return c.json(result.ok(data));
})

// 按天统计当前用户存在照片的拍摄日期。
app.post('/photo/takenDateList', async (c: Context) => {
  const body = await c.req.json<PhotoTakenDateListBo>();
  const data = await photoService.takenDateList(body, getUserId());
  return c.json(result.ok(data));
})

// 上传单张照片，后端生成 preview、thumbnail 和元信息。
app.post('/photo/add', async (c: Context) => {
  const data = await photoService.add(await c.req.formData(), getUserId());
  return c.json(result.ok(data));
})

// 上传前检查当前用户是否已有相同文件。
app.post('/photo/exists', async (c: Context) => {
  const body = await c.req.json<PhotoExistsBo>();
  const data = await photoService.exists(body, getUserId());
  return c.json(result.ok(data));
})

// 把当前用户的指定照片移动到回收站。
app.post('/photo/recycle', async (c: Context) => {
  const body = await c.req.json<PhotoRecycleBo>();
  await photoService.recycle(body, getUserId());
  return c.json(result.ok());
})

// 设置当前用户指定照片的收藏状态。
app.post('/photo/favorite', async (c: Context) => {
  const body = await c.req.json<PhotoFavoriteBo>();
  await photoService.favorite(body, getUserId());
  return c.json(result.ok());
})

// 恢复当前用户回收站中的指定照片。
app.post('/photo/restore', async (c: Context) => {
  const body = await c.req.json<PhotoRestoreBo>();
  await photoService.restore(body, getUserId());
  return c.json(result.ok());
})

// 彻底删除当前用户的指定照片文件和记录。
app.post('/photo/delete', async (c: Context) => {
  const body = await c.req.json<PhotoDeleteBo>();
  await photoService.delete(body, getUserId());
  return c.json(result.ok());
})

// 清理当前用户回收站中的照片文件和记录。
app.post('/photo/clear', async (c: Context) => {
  await photoService.clear(getUserId());
  return c.json(result.ok());
})
