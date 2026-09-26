import { app } from '../hono/hono';
import { Context } from "hono";
import { deleteCookie, setCookie } from 'hono/cookie';
import { TOKEN_COOKIE_MAX_AGE, TOKEN_COOKIE_NAME } from "@/server/const/global";
import result from "@/server/model/result";
import { type LoginBo } from "@/server/entity/bo/login";
import { type LoginVo } from "@/server/entity/vo/login";
import { getLoginInfo } from "@/lib/cookie";
import { loginService } from "@/server/service/login-service";

// 这个模块注册登录相关接口。

// 用户登录，成功后返回 JWT。
app.post('/login', async (c: Context) => {
  const params = await c.req.json<LoginBo>();
  const token = await loginService.login(params);
  const data: LoginVo = { token };

  setCookie(c, TOKEN_COOKIE_NAME, token, {
    path: '/',
    maxAge: TOKEN_COOKIE_MAX_AGE,
    httpOnly: true,
    sameSite: 'Lax',
  });

  return c.json(result.ok(data));
})

// 用户退出登录，清除当前会话并删除 Cookie。
app.post('/logout', async (c: Context) => {

  const { userId, uuid } = await getLoginInfo(
    c.req.header('cookie'),
    c.req.header('authorization')
  );
  await loginService.logout(userId, uuid);

  deleteCookie(c, TOKEN_COOKIE_NAME, {
    path: '/',
  });

  return c.json(result.ok());
})
