import { Hono } from 'hono';
import { compress } from 'hono/compress';
import { contextStorage } from 'hono/context-storage';
import result from '../model/result';
import { cors } from 'hono/cors';
import BizError from '../error/biz-error';
import { security } from '../security/security';
import { i18nMiddleware, t } from '@/server/i18n';
import type { HonoEnv } from './type';

// 这个模块创建 Hono 应用并注册通用中间件与错误处理。

const app = new Hono<HonoEnv>().basePath('/api');

// 按 Accept-Encoding 压缩 JSON 等文本响应，默认超过 1KB 才启用 gzip。
app.use('*', compress());
app.use('*', cors());
app.use('*', contextStorage());
app.use('*', i18nMiddleware);
app.use('*', security);

// 统一处理接口异常并返回约定的响应结构。
app.onError((err, c) => {

  if (err instanceof BizError) {

    const message = t(err.message);

    if (err.code === 401 || err.code === 403) {
      return c.json(result.fail(message, err.code), err.code);
    }

    return c.json(result.fail(message, err.code));
  }

  console.error(err);
  return c.json(result.fail(err.message));
});

export { app };
