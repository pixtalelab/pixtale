import type { Context, Next } from 'hono';
import { deleteCookie } from 'hono/cookie';
import { TOKEN_COOKIE_NAME } from '@/server/const/global';
import { AUTH_CACHE_KEY } from '@/server/const/cache';
import BizError from '@/server/error/biz-error';
import { getLoginInfo } from '@/lib/cookie';
import { setUserId } from '@/server/security/context';
import { cache } from '@/server/infra/cache';
import { type AuthInfo } from '@/server/entity/vo/auth';
import { UserTypeEnum } from '@/server/enums/user-enum';

// 这个模块提供全局接口鉴权中间件。

const SYSTEM_PATHS = [
  '/setting',
  '/user/list',
  '/user/add',
  '/user/set',
  '/user/toggleStatus',
  '/user/delete',
  '/storage/list',
  '/storage/add',
  '/storage/set',
  '/storage/setTop',
  '/storage/toggleStatus',
  '/storage/delete'
];

// 演示用户允许访问的只读接口（系统设置页靠 SSR，不开放对应管理 API）。
const DEMO_READ_PATHS = [
  '/photo/list',
  '/photo/takenDateList',
  '/photo/exists',
  '/user/info',
  '/user/avatar',
  '/album/list',
  '/album/trash',
  '/storage/select',
  '/dashboard/systemUsage',
];

// 判断当前路径是否命中指定接口或其子路径。
function isPathMatched(path: string, target: string) {
  return path === target || path.startsWith(`${target}/`);
}

// 判断当前接口是否属于系统管理接口。
function isSystemPath(path: string) {
  return SYSTEM_PATHS.some((target) => isPathMatched(path, target));
}

// 判断演示用户是否允许访问当前接口。
function isDemoReadPath(path: string) {
  if (path.startsWith('/media')) {
    return true;
  }

  return DEMO_READ_PATHS.some((target) => isPathMatched(path, target));
}

// 清除登录相关 Cookie。
function clearLoginCookies(c: Context) {
  deleteCookie(c, TOKEN_COOKIE_NAME, {
    path: '/',
  });
}

// 校验登录信息与会话 uuid，通过后写入上下文；公开路径直接放行。
async function security(c: Context, next: Next) {

  const path = c.req.path.replace(/^\/api/, '');

  if (path.startsWith('/login') || path.startsWith('/logout')) {
    return next();
  }

  if (path === '/photo/publicList') {
    return next();
  }

  const { userId, uuid } = await getLoginInfo(
    c.req.header('cookie') ?? null,
    c.req.header('authorization')
  );

  if (!userId || !uuid) {
    clearLoginCookies(c);
    throw new BizError('auth.failed', 401);
  }

  // 从缓存读取登录信息，并确认当前 uuid 仍有效。
  const authInfo = await cache.get<AuthInfo>(AUTH_CACHE_KEY + userId);

  if (!authInfo || !authInfo.uuidList.includes(uuid)) {
    clearLoginCookies(c);
    throw new BizError('auth.failed', 401);
  }

  if (isSystemPath(path) && authInfo.type !== UserTypeEnum.ADMIN) {
    throw new BizError('auth.forbidden', 403);
  }

  // 演示用户仅允许只读接口。
  if (authInfo.type === UserTypeEnum.DEMO && !isDemoReadPath(path)) {
    throw new BizError('system.demoReadonly', 403);
  }

  setUserId(authInfo.userId);

  return next();
}

export { security };
