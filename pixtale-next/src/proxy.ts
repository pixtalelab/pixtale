import { NextResponse, type NextRequest } from 'next/server';
import { TOKEN_COOKIE_NAME } from '@/server/const/global';
import { AUTH_CACHE_KEY } from '@/server/const/cache';
import { getLoginInfo } from '@/lib/cookie';
import { UserTypeEnum } from '@/server/enums/user-enum';
import { type AuthInfo } from '@/server/entity/vo/auth';
import { cache } from '@/server/infra/cache';
import { setProxyUserHeaders } from '@/server/lib/proxy-user';
import { settingService } from '@/server/service/setting-service';
import { SettingPublicAlbumEnum } from '@/server/enums/setting-enum';

// 这个模块代理页面路由，未登录时跳转登录页。

const SYSTEM_PATHS = ['/users', '/settings', '/storage'];
const PUBLIC_FILE_REG = /\.(?:png|jpg|jpeg|gif|webp|svg|ico|woff2?|ttf|otf)$/i;

// 判断当前路径是否允许未登录访问。
function isPublicPath(pathname: string) {
  return pathname.startsWith('/auth')
    || pathname.startsWith('/api')
    || pathname.startsWith('/media')
    || pathname.startsWith('/_next')
    || pathname === '/favicon.ico'
    || pathname === '/robots.txt'
    || PUBLIC_FILE_REG.test(pathname);
}

// 判断当前路径是否命中指定页面或其子页面。
function isPathMatched(pathname: string, path: string) {
  return pathname === path || pathname.startsWith(`${path}/`);
}

// 判断当前路径是否属于系统设置页面。
function isSystemPath(pathname: string) {
  return SYSTEM_PATHS.some((path) => isPathMatched(pathname, path));
}

// 判断系统是否开启公开相册首页。
async function isPublicHomeEnabled(pathname: string) {
  if (pathname !== '/' && pathname !== '/public/albums' && !pathname.startsWith('/public/albums/')) {
    return false;
  }

  try {
    const setting = await settingService.get();
    return setting.publicAlbum === SettingPublicAlbumEnum.ENABLE;
  } catch {
    return false;
  }
}

// 清除登录相关 Cookie，并返回传入响应。
function clearLoginCookies(response: NextResponse) {
  response.cookies.set(TOKEN_COOKIE_NAME, '', {
    path: '/',
    maxAge: 0,
  });

  return response;
}

// 继续请求，并把 userId、type 以哈希头名写入下游。
function nextWithUser(req: NextRequest, authInfo: Pick<AuthInfo, 'userId' | 'type'>) {
  const requestHeaders = new Headers(req.headers);
  setProxyUserHeaders(requestHeaders, authInfo.userId, authInfo.type);

  return NextResponse.next({
    request: {
      headers: requestHeaders,
    },
  });
}

// 代理未登录页面访问，API 和媒体资源交给各自后端处理。
export async function proxy(req: NextRequest) {

  const { pathname } = req.nextUrl;

  // 旧登录路径已废弃，直接返回 404。
  if (pathname === '/login' || pathname.startsWith('/login/')) {
    const notFoundUrl = req.nextUrl.clone();
    notFoundUrl.pathname = '/_not-found';
    return NextResponse.rewrite(notFoundUrl, { status: 404 });
  }

  // 公开相册开启时，首页直接放行，不参与登录鉴权。
  if (await isPublicHomeEnabled(pathname)) {
    return NextResponse.next();
  }

  const cookie = req.headers.get('cookie');
  const { userId, uuid, type } = await getLoginInfo(cookie);

  if (!userId || !uuid) {
    if (isPublicPath(pathname)) {
      return clearLoginCookies(NextResponse.next());
    }

    const loginUrl = req.nextUrl.clone();
    loginUrl.pathname = '/auth';
    // 未登录时内部改写到登录页，避免 307 重定向。
    return clearLoginCookies(NextResponse.rewrite(loginUrl));
  }

  // Vercel 使用签名 JWT 中的身份与角色，其他环境仍校验缓存会话。
  const authInfo = process.env.VERCEL
    ? { userId, type: type!, uuidList: [uuid] }
    : await cache.get<AuthInfo>(AUTH_CACHE_KEY + userId);

  if (!authInfo || !authInfo.uuidList.includes(uuid)) {
    if (isPublicPath(pathname)) {
      return clearLoginCookies(NextResponse.next());
    }

    const loginUrl = req.nextUrl.clone();
    loginUrl.pathname = '/auth';
    // 会话失效时同样内部改写到登录页，避免 307 重定向。
    return clearLoginCookies(NextResponse.rewrite(loginUrl));
  }

  if (pathname === '/') {
    const url = req.nextUrl.clone();
    url.pathname = '/photos';
    return NextResponse.redirect(url);
  }

  if (pathname.startsWith('/auth')) {
    const photoUrl = req.nextUrl.clone();
    photoUrl.pathname = '/photos';
    return NextResponse.redirect(photoUrl);
  }

  // 系统设置页面仅管理员与演示用户可进入。
  if (
    isSystemPath(pathname)
    && authInfo.type !== UserTypeEnum.ADMIN
    && authInfo.type !== UserTypeEnum.DEMO
  ) {
    const notFoundUrl = req.nextUrl.clone();
    notFoundUrl.pathname = '/_not-found';

    return NextResponse.rewrite(notFoundUrl, { status: 404 });
  }

  return nextWithUser(req, authInfo);
}

export const config = {
  matcher: ['/((?!api|media|_next/static|_next/image|favicon.ico|robots.txt|.*\\.(?:png|jpg|jpeg|gif|webp|svg|ico|woff2?|ttf|otf)$).*)'],
};
