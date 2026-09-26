import { and, count, desc, eq, inArray, max } from 'drizzle-orm';
import { createId } from '@/server/lib/id';
import { type Album, albumTab } from '@/server/entity/album';
import { albumPhotoTab } from '@/server/entity/album-photo';
import { photoTab } from '@/server/entity/photo';
import { orm } from '@/server/infra/db';
import BizError from '@/server/error/biz-error';
import { type AlbumAddBo, type AlbumAddPhotoBo, type AlbumDeleteBo, type AlbumRecycleBo, type AlbumRemovePhotoBo, type AlbumSetNameBo, type AlbumSetPublicBo, type AlbumSetTopBo } from '@/server/entity/bo/album';
import { PhotoStatusEnum } from '@/server/enums/photo-enum';
import { AlbumPublicEnum } from '@/server/enums/album-enum';
import { type AlbumVo } from '@/server/entity/vo/album';
import { storageService } from '@/server/service/storage-service';
import { formatHttpUrl, toMediaUrl } from '@/lib/url';
import { fileService } from '@/server/service/file-service';
import { FileTypeEnum } from '@/server/enums/file-enum';
import { type File } from '@/server/entity/file';

// 这个模块处理相册数据写入相关业务。

const albumService = {

  // 按名称查询当前用户的相册。
  async getByName(name: string, userId: string): Promise<Album | null> {
    const albumName = name.trim();

    if (!albumName) {
      return null;
    }

    const [album] = await orm
      .select()
      .from(albumTab)
      .where(and(
        eq(albumTab.name, albumName),
        eq(albumTab.userId, userId)
      ))
      .limit(1);

    return album ?? null;
  },

  // 查询当前用户的全部相册列表。
  async list(userId: string): Promise<AlbumVo[]> {

    const albumList = await orm
      .select()
      .from(albumTab)
      .where(eq(albumTab.userId, userId))
      .orderBy(desc(albumTab.sort));

    if (!albumList.length) {
      return [];
    }

    const fileStorageList = await storageService.list();

    const photoStatList = await orm
      .select({
        albumId: albumPhotoTab.albumId,
        photoId: photoTab.photoId,
        thumbHash: photoTab.thumbHash,
        storageId: photoTab.storageId,
        photoTotal: count(photoTab.photoId),
        takenTime: max(photoTab.takenTime)
      })
      .from(albumPhotoTab)
      .innerJoin(photoTab, eq(albumPhotoTab.photoId, photoTab.photoId))
      .where(and(
        eq(photoTab.status, PhotoStatusEnum.NORMAL),
        eq(photoTab.userId, userId)
      ))
      .groupBy(albumPhotoTab.albumId)
      .orderBy(desc(photoTab.takenTime), desc(photoTab.photoId));

    const fileMap = await fileService.listByPhotoIds(
      photoStatList.map((stat) => stat.photoId).filter(Boolean)
    );

    const list = albumList.map((album) => {
      const photoStat = photoStatList.find((stat) => stat.albumId === album.albumId);
      const fileStorage = fileStorageList.list.find((item) => item.storageId === photoStat?.storageId);
      const domain = formatHttpUrl(fileStorage?.domain);

      let thumbnail: string | null = null;

      if (photoStat?.photoId) {
        const file = (fileMap.get(photoStat.photoId) ?? []).find((item) => item.type === FileTypeEnum.THUMBNAIL);
        thumbnail = file?.key ?? null;
      }

      return {
        ...album,
        thumbnail: thumbnail ? toMediaUrl(thumbnail, domain) : null,
        thumbHash: photoStat?.thumbHash ?? null,
        photoTotal: Number(photoStat?.photoTotal ?? 0)
      };
    });

    return list;
  },

  // 查询所有公开相册列表，不要求登录用户身份。
  async publicList(): Promise<AlbumVo[]> {
    const albumList = await orm
      .select()
      .from(albumTab)
      .where(eq(albumTab.public, AlbumPublicEnum.ENABLE))
      .orderBy(desc(albumTab.sort));

    if (!albumList.length) {
      return [];
    }

    const fileStorageList = await storageService.list();
    const photoStatList = await orm
      .select({
        albumId: albumPhotoTab.albumId,
        photoId: photoTab.photoId,
        thumbHash: photoTab.thumbHash,
        storageId: photoTab.storageId,
        photoTotal: count(photoTab.photoId),
        takenTime: max(photoTab.takenTime),
      })
      .from(albumPhotoTab)
      .innerJoin(photoTab, eq(albumPhotoTab.photoId, photoTab.photoId))
      .where(eq(photoTab.status, PhotoStatusEnum.NORMAL))
      .groupBy(albumPhotoTab.albumId)
      .orderBy(desc(photoTab.takenTime), desc(photoTab.photoId));

    const fileMap = await fileService.listByPhotoIds(
      photoStatList.map((stat) => stat.photoId).filter(Boolean),
    );

    return albumList.map((album) => {
      const photoStat = photoStatList.find((stat) => stat.albumId === album.albumId);
      const fileStorage = fileStorageList.list.find((item) => item.storageId === photoStat?.storageId);
      const domain = formatHttpUrl(fileStorage?.domain);
      const file = photoStat?.photoId
        ? (fileMap.get(photoStat.photoId) ?? []).find((item) => item.type === FileTypeEnum.THUMBNAIL)
        : null;

      return {
        ...album,
        thumbnail: file?.key ? toMediaUrl(file.key, domain) : null,
        thumbHash: photoStat?.thumbHash ?? null,
        photoTotal: Number(photoStat?.photoTotal ?? 0),
      };
    });
  },

  // 查询指定的公开相册。
  async publicGetById(albumId: string): Promise<Album | null> {
    const [album] = await orm
      .select()
      .from(albumTab)
      .where(and(
        eq(albumTab.albumId, albumId),
        eq(albumTab.public, AlbumPublicEnum.ENABLE),
      ))
      .limit(1);

    return album ?? null;
  },

  // 添加当前用户的相册，并阻止同一用户创建重复名称的相册。
  async add(params: AlbumAddBo, userId: string): Promise<Album> {

    const name = params.name?.trim();

    if (!name) {
      throw new BizError('album.nameRequired');
    }

    const [existsAlbum] = await orm
      .select()
      .from(albumTab)
      .where(and(
        eq(albumTab.userId, userId),
        eq(albumTab.name, name)
      ))
      .limit(1);

    if (existsAlbum) {
      throw new BizError('album.nameExists');
    }

    const now = new Date().toISOString();

    const [album] = await orm.insert(albumTab).values({
      albumId: createId(),
      name,
      userId,
      sort: 0,
      public: AlbumPublicEnum.DISABLE,
      createTime: now,
      updateTime: now,
    }).returning();

    return album;
  },

  // 给当前用户指定相册新增照片关联，并跳过已经存在的关联。
  async addPhoto(params: AlbumAddPhotoBo, userId: string): Promise<void> {

    if (!params.photoIds?.length) {
      throw new BizError('photo.selectRequired');
    }

    if (!params.albumIds?.length) {
      throw new BizError('album.selectRequired');
    }

    const photos = await orm
      .select({
        photoId: photoTab.photoId
      })
      .from(photoTab)
      .where(and(
        eq(photoTab.userId, userId),
        inArray(photoTab.photoId, params.photoIds)
      ));
    const photoIds = Array.from(new Set(photos.map((photo) => photo.photoId)));

    if (!photoIds.length) {
      return;
    }

    const existsRows = await orm
      .select({
        albumId: albumPhotoTab.albumId,
        photoId: albumPhotoTab.photoId
      })
      .from(albumPhotoTab)
      .where(and(
        inArray(albumPhotoTab.albumId, params.albumIds),
        inArray(albumPhotoTab.photoId, photoIds)
      ));
    const existsKeys = new Set(existsRows.map((row) => `${row.albumId}:${row.photoId}`));
    const rows = params.albumIds.flatMap((albumId) => (
      photoIds
        .filter((photoId) => !existsKeys.has(`${albumId}:${photoId}`))
        .map((photoId) => ({
          id: createId(),
          photoId,
          albumId
        }))
    ));

    if (rows.length) {
      await orm.insert(albumPhotoTab).values(rows);
    }
  },

  // 把当前用户指定相册中的照片关联移除。
  async removePhoto(params: AlbumRemovePhotoBo, userId: string): Promise<void> {

    if (!params.albumId) {
      throw new BizError('album.selectRequired');
    }

    if (!params.photoIds?.length) {
      throw new BizError('photo.selectRequired');
    }

    const [album] = await orm
      .select({
        albumId: albumTab.albumId
      })
      .from(albumTab)
      .where(and(
        eq(albumTab.albumId, params.albumId),
        eq(albumTab.userId, userId)
      ))
      .limit(1);

    if (!album) {
      return;
    }

    await orm.delete(albumPhotoTab)
      .where(and(
        eq(albumPhotoTab.albumId, params.albumId),
        inArray(albumPhotoTab.photoId, params.photoIds)
      ));
  },

  // 修改当前用户指定相册的名称。
  async setName(params: AlbumSetNameBo, userId: string): Promise<void> {
    const name = params.name?.trim();

    if (!name) {
      throw new BizError('album.nameRequired');
    }

    await orm.update(albumTab)
      .set({
        name,
        updateTime: new Date().toISOString()
      })
      .where(and(
        eq(albumTab.albumId, params.albumId),
        eq(albumTab.userId, userId)
      ));
  },

  // 把当前用户指定相册置顶。
  async setTop(params: AlbumSetTopBo, userId: string): Promise<void> {
    await orm.update(albumTab)
      .set({
        sort: Date.now(),
        updateTime: new Date().toISOString()
      })
      .where(and(
        eq(albumTab.albumId, params.albumId),
        eq(albumTab.userId, userId)
      ));
  },

  // 修改当前用户指定相册的公开状态。
  async setPublic(params: AlbumSetPublicBo, userId: string): Promise<void> {
    if (params.public !== AlbumPublicEnum.DISABLE && params.public !== AlbumPublicEnum.ENABLE) {
      throw new BizError('album.publicInvalid');
    }

    await orm.update(albumTab)
      .set({
        public: params.public,
        updateTime: new Date().toISOString(),
      })
      .where(and(
        eq(albumTab.albumId, params.albumId),
        eq(albumTab.userId, userId),
      ));

  },

  // 把当前用户相册中的正常照片移入回收站，保留相册和照片关联。
  async recycle(params: AlbumRecycleBo, userId: string): Promise<void> {
    if (!params.albumId) {
      throw new BizError('album.selectRequired');
    }

    // 子查询校验相册归属，批量更新避免大量照片触发 SQL 参数数量限制。
    const photoIds = orm
      .select({ photoId: albumPhotoTab.photoId })
      .from(albumPhotoTab)
      .innerJoin(albumTab, eq(albumPhotoTab.albumId, albumTab.albumId))
      .where(and(
        eq(albumTab.albumId, params.albumId),
        eq(albumTab.userId, userId),
      ));

    await orm.update(photoTab)
      .set({
        status: PhotoStatusEnum.DELETE,
        recycleTime: new Date().toISOString(),
      })
      .where(and(
        inArray(photoTab.photoId, photoIds),
        eq(photoTab.userId, userId),
        eq(photoTab.status, PhotoStatusEnum.NORMAL),
      ));
  },

  // 删除当前用户指定相册，并清理相册照片关联。
  async delete(params: AlbumDeleteBo, userId: string): Promise<void> {

    await orm.delete(albumPhotoTab)
      .where(eq(albumPhotoTab.albumId, params.albumId));

    await orm.delete(albumTab)
      .where(and(
        eq(albumTab.albumId, params.albumId),
        eq(albumTab.userId, userId)
      ));

  },

  // 删除指定用户的全部相册，并清理这些相册的照片关联。
  async deleteByUserId(userId: string): Promise<void> {

    const albumList = await orm
      .select({
        albumId: albumTab.albumId
      })
      .from(albumTab)
      .where(eq(albumTab.userId, userId));

    const albumIds = albumList.map((album) => album.albumId);

    for (let index = 0; index < albumIds.length; index += 95) {

      const deleteAlbumIds = albumIds.slice(index, index + 95);
      await orm.delete(albumPhotoTab)
        .where(inArray(albumPhotoTab.albumId, deleteAlbumIds));
    }

    await orm.delete(albumTab)
      .where(eq(albumTab.userId, userId));

  },

  // 查询当前用户回收站虚拟相册，并统计已回收照片数量和最新回收封面。
  async trash(userId: string): Promise<AlbumVo> {
    const fileStorageList = await storageService.list();
    const photoList = await orm
      .select()
      .from(photoTab)
      .where(and(
        eq(photoTab.userId, userId),
        eq(photoTab.status, PhotoStatusEnum.DELETE)
      ))
      .orderBy(desc(photoTab.recycleTime))
    const coverPhoto = photoList[0];
    const fileStorage = fileStorageList.list.find((item) => item.storageId === coverPhoto?.storageId);
    const domain = formatHttpUrl(fileStorage?.domain);

    const fileMap = coverPhoto
      ? await fileService.listByPhotoIds([coverPhoto.photoId])
      : new Map<string, File[]>();

    const thumbnail = coverPhoto
      ? (fileMap.get(coverPhoto.photoId) ?? []).find((file) => file.type === FileTypeEnum.THUMBNAIL)?.key ?? null
      : null;

    const now = new Date().toISOString();

    return {
      albumId: 'trash',
      name: 'trash.title',
      description: '',
      sort: 0,
      public: AlbumPublicEnum.DISABLE,
      createTime: now,
      updateTime: now,
      userId,
      thumbnail: thumbnail ? toMediaUrl(thumbnail, domain) : null,
      thumbHash: coverPhoto?.thumbHash ?? null,
      photoTotal: photoList.length
    };
  }
}

export { albumService };
