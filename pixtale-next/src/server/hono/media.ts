import { Hono } from 'hono';
import type { Context, Next } from 'hono';
import { storage } from '@/server/storage/storage';
import { orm } from '@/server/infra/db';
import { photoTab } from '@/server/entity/photo';
import { fileTab } from '@/server/entity/file';
import { albumPhotoTab } from '@/server/entity/album-photo';
import { albumTab } from '@/server/entity/album';
import { desc, eq } from 'drizzle-orm';
import { contextStorage } from 'hono/context-storage';
import { cors } from 'hono/cors';
import { buildContentDisposition } from '@/server/lib/file';
import { FileTypeEnum } from '@/server/enums/file-enum';
import { AlbumPublicEnum } from '@/server/enums/album-enum';
import BizError from '@/server/error/biz-error';
import { i18nMiddleware, t } from '@/server/i18n';
import { getUserId } from '@/server/security/context';
import { security } from '../security/security';
import type { HonoEnv } from './type';

// 这个模块处理照片媒体读取接口，路径为 /media/{key}。

const media = new Hono<HonoEnv>();
media.use('*', cors());
media.use('*', contextStorage());
media.use('*', i18nMiddleware);
media.onError((err, c) => {
  if (err instanceof BizError) {
    return c.text(t(err.message), 500);
  }
  console.error(err);
  return c.text(err.message, 500);
});

// 根据文件 key 查询对应的文件、照片和相册公开信息。
async function getPhotoFile(key: string) {
  const [row] = await orm
    .selectDistinct({
      key: fileTab.key,
      type: fileTab.type,
      fileType: fileTab.fileType,
      name: photoTab.name,
      photoId: photoTab.photoId,
      storageId: photoTab.storageId,
      photoUserId: photoTab.userId,
      albumId: albumTab.albumId,
      albumPublic: albumTab.public
    })
    .from(fileTab)
    .innerJoin(photoTab, eq(fileTab.photoId, photoTab.photoId))
    .leftJoin(albumPhotoTab, eq(photoTab.photoId, albumPhotoTab.photoId))
    .leftJoin(albumTab, eq(albumPhotoTab.albumId, albumTab.albumId))
    .where(eq(fileTab.key, key))
    .orderBy(desc(albumTab.public))
    .limit(1);

  return row;
}

// 根据照片文件名和类型生成 Content-Disposition。
function getContentDisposition(name: string, type: number) {
  let suffix = '';

  if (type === FileTypeEnum.PREVIEW) {
    suffix = '_preview.jpg';
  }

  if (type === FileTypeEnum.THUMBNAIL) {
    suffix = '_thumb.webp';
  }

  return buildContentDisposition(name, suffix);
}

media.get('*', async (c: Context, next: Next) => {

  if (!c.req.path.startsWith('/media/')) {
    return next();
  }

  const key = decodeURIComponent(c.req.path.slice('/media/'.length));

  const photoFile = await getPhotoFile(key);

  if (!photoFile?.key || !photoFile?.storageId) {
    return next();
  }

  const photoKey = photoFile.key;
  const storageId = photoFile.storageId;

  // 读取照片文件并生成媒体响应。
  const sendPhoto = async () => {
    const obj = await storage.get(photoKey, storageId);
    const disposition = getContentDisposition(photoFile.name, photoFile.type);
    const headers: Record<string, string> = {
      'Cache-Control': 'private, max-age=604800',
      'Content-Length': String(obj.size)
    };

    if (photoFile.fileType) {
      headers['Content-Type'] = photoFile.fileType;
    }

    if (disposition) {
      headers['Content-Disposition'] = disposition;
    }

    return c.body(obj.body, 200, headers);
  };

  if (photoFile.albumPublic === AlbumPublicEnum.ENABLE) {
    return sendPhoto();
  }

  await security(c, async () => {});

  if (getUserId() !== photoFile.photoUserId) {
    return next();
  }

  return sendPhoto();
})

export { media };
