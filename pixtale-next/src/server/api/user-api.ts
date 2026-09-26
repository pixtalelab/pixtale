import { app } from '../hono/hono';
import { Context } from 'hono';
import result from '@/server/model/result';
import { type UserAddBo, type UserDeleteBo, type UserSetAvatarBo, type UserSetBo, type UserPasswordBo, type UserToggleStatusBo } from '@/server/entity/bo/user';
import { getUserId } from '@/server/security/context';
import { userService } from '@/server/service/user-service';

// 这个模块注册用户相关接口。

// 查询当前登录用户信息。
app.post('/user/info', async (c: Context) => {
  const data = await userService.getById(getUserId());
  return c.json(result.ok(data));
});

// 查询全部用户列表。
app.post('/user/list', async (c: Context) => {
  const data = await userService.list();
  return c.json(result.ok(data));
});

// 添加用户。
app.post('/user/add', async (c: Context) => {
  const params = await c.req.json<UserAddBo>();
  await userService.add(params);
  return c.json(result.ok());
});

// 修改用户信息。
app.post('/user/set', async (c: Context) => {
  const params = await c.req.json<UserSetBo>();
  await userService.set(params);
  return c.json(result.ok());
});

// 修改当前登录用户密码。
app.post('/user/setUserPassword', async (c: Context) => {
  const params = await c.req.json<UserPasswordBo>();
  await userService.setUserPassword(params, getUserId());
  return c.json(result.ok());
});

// 设置当前用户头像。
app.post('/user/setAvatar', async (c: Context) => {
  const params = await c.req.json<UserSetAvatarBo>();
  const user = await userService.setAvatar(params, getUserId());
  return c.json(result.ok(user.avatar));
});

// 根据头像 key 从存储读取头像图片，浏览器 img 标签直接加载。
app.get('/user/avatar/:key', async (c: Context) => {

  const key = c.req.param('key');
  const file = await userService.getAvatar(key);

  if (!file) {
    return c.body(null, 404);
  }

  return c.body(file.body, 200, {
    'Content-Type': 'image/webp',
    'Cache-Control': 'public, max-age=31536000, immutable',
    'Content-Length': String(file.size),
  });
});

// 切换指定用户启用状态。
app.post('/user/toggleStatus', async (c: Context) => {
  const params = await c.req.json<UserToggleStatusBo>();
  await userService.toggleStatus(params);
  return c.json(result.ok());
});

// 删除指定用户及其关联数据。
app.post('/user/delete', async (c: Context) => {
  const params = await c.req.json<UserDeleteBo>();
  await userService.delete(params.userId);
  return c.json(result.ok());
});
