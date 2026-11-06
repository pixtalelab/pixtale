import { and, desc, eq, inArray, notExists, sql } from 'drizzle-orm';
import { createId } from '@/server/lib/id';
import { type Album, albumTab } from '@/server/entity/album';
import { albumPhotoTab } from '@/server/entity/album-photo';
import { photoTab } from '@/server/entity/photo';
import { orm } from '@/server/infra/db';
import BizError from '@/server/error/biz-error';
import { type AlbumAddBo, type AlbumAddMissingPhotoBo, type AlbumAddPhotoBo, type AlbumDeleteBo, type AlbumRecycleBo, type AlbumRemovePhotoBo, type AlbumSetNameBo, type AlbumSetPublicBo, type AlbumSetTopBo } from '@/server/entity/bo/album';
import { PhotoStatusEnum } from '@/server/enums/photo-enum';
import { AlbumPublicEnum } from '@/server/enums/album-enum';
import { type AlbumVo } from '@/server/entity/vo/album';
import { storageService } from '@/server/service/storage-service';
import { formatHttpUrl, toMediaUrl } from '@/lib/url';
import { fileService } from '@/server/service/file-service';
import { type File } from '@/server/entity/file';
import { FileTypeEnum } from '@/server/enums/file-enum';

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
      const defaultAlbum = await this.getDefaultAlbum(userId);
      return defaultAlbum ? [defaultAlbum] : [];
    }

    const list = await this.buildAlbumVoList(albumList, userId);

    const defaultAlbum = await this.getDefaultAlbum(userId);
    if (defaultAlbum) {
      list.push(defaultAlbum);
    }
    return list;
  },

  // 给相册补上封面、缩略图和正常照片数量。传入 userId 时只统计该用户的照片。
  async buildAlbumVoList(albumList: Album[], userId?: string): Promise<AlbumVo[]> {
    // 只统计正常照片。传入用户时再限定为该用户的照片。
    const whereList = [eq(photoTab.status, PhotoStatusEnum.NORMAL)];

    if (userId) {
      whereList.push(eq(photoTab.userId, userId));
    }

    // 按相册统计照片数量，并按拍摄时间给照片编号，最新的一张编号为 1。
    const ranked = orm
      .select({
        albumId: albumPhotoTab.albumId,
        photoId: photoTab.photoId,
        thumbHash: photoTab.thumbHash,
        storageId: photoTab.storageId,
        photoTotal: sql<number>`count(*) over (partition by ${albumPhotoTab.albumId})`.as('photo_total'),
        rn: sql<number>`row_number() over (partition by ${albumPhotoTab.albumId} order by ${photoTab.takenTime} desc, ${photoTab.photoId} desc)`.as('rn'),
      })
      .from(photoTab)
      .innerJoin(albumPhotoTab, eq(albumPhotoTab.photoId, photoTab.photoId))
      .where(and(...whereList))
      .as('ranked');
    // 每个相册只保留最新的一张，作为封面。
    const photoStatList = await orm
      .select({
        albumId: ranked.albumId,
        photoId: ranked.photoId,
        thumbHash: ranked.thumbHash,
        storageId: ranked.storageId,
        photoTotal: ranked.photoTotal,
      })
      .from(ranked)
      .where(eq(ranked.rn, 1));

    // 读取存储配置和封面缩略图，供后面拼接访问地址。
    const storageList = await storageService.getStorageList();
    const photoStatMap = new Map(photoStatList.map((stat) => [stat.albumId, stat]));
    const fileMap = await fileService.listByPhotoIds(photoStatList.map((stat) => stat.photoId));

    // 把封面、模糊色和照片数量写回每个相册。
    return albumList.map((album) => {
      const stat = photoStatMap.get(album.albumId);
      const fileStorage = storageList.find((item) => item.storageId === stat?.storageId);
      const domain = formatHttpUrl(fileStorage?.domain);
      const file = stat?.photoId
        ? (fileMap.get(stat.photoId) ?? []).find((item) => item.type === FileTypeEnum.THUMBNAIL)
        : null;

      return {
        ...album,
        thumbnail: file?.key ? toMediaUrl(file.key, domain) : null,
        thumbHash: stat?.thumbHash ?? null,
        photoTotal: Number(stat?.photoTotal ?? 0),
      };
    });
  },

  // 统计当前用户未关联相册的正常照片，并以拍摄时间最新的一张作为默认相册封面。
  async getDefaultAlbum(userId: string): Promise<AlbumVo | null> {
    // 统计未归入任何相册的正常照片，并取拍摄时间最新的一张作为封面。
    const [coverPhoto] = await orm
      .select({
        photoId: photoTab.photoId,
        storageId: photoTab.storageId,
        thumbHash: photoTab.thumbHash,
        photoTotal: sql<number>`count(*) over ()`.as('photo_total'),
      })
      .from(photoTab)
      .where(and(
        eq(photoTab.userId, userId),
        eq(photoTab.status, PhotoStatusEnum.NORMAL),
        notExists(orm.select({ id: albumPhotoTab.id }).from(albumPhotoTab)
          .where(eq(albumPhotoTab.photoId, photoTab.photoId)))
      ))
      .orderBy(desc(photoTab.takenTime), desc(photoTab.photoId))
      .limit(1);

    // 没有未归类照片时不返回默认相册。
    if (!coverPhoto) {
      return null;
    }

    // 读取封面所在存储和缩略图，供拼接访问地址。
    const storageList = await storageService.getStorageList();
    const fileStorage = storageList.find((item) => item.storageId === coverPhoto.storageId);
    const domain = formatHttpUrl(fileStorage?.domain);
    const fileMap = await fileService.listByPhotoIds([coverPhoto.photoId]);
    const thumbnail = (fileMap.get(coverPhoto.photoId) ?? [])
      .find((file) => file.type === FileTypeEnum.THUMBNAIL)?.key ?? null;

    // 组装默认相册，照片数量来自上面的统计。
    return {
      albumId: 'default',
      name: 'albums.default',
      nameKey: 'albums.default',
      description: '',
      sort: 0,
      public: AlbumPublicEnum.DISABLE,
      createTime: '',
      updateTime: '',
      userId,
      thumbnail: thumbnail ? toMediaUrl(thumbnail, domain) : null,
      thumbHash: coverPhoto.thumbHash,
      photoTotal: Number(coverPhoto.photoTotal),
    };
  },

  // 复用相册列表查询，排除默认相册后供选择列表使用。
  async select(userId: string): Promise<AlbumVo[]> {
    const list = await this.list(userId);
    return list.filter((album) => album.albumId !== 'default');
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

    return this.buildAlbumVoList(albumList);
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

    const albumIds = Array.from(new Set(params.albumIds));
    const albums = await orm
      .select({
        albumId: albumTab.albumId
      })
      .from(albumTab)
      .where(and(
        eq(albumTab.userId, userId),
        inArray(albumTab.albumId, albumIds)
      ));

    // 批量操作必须先确认所有目标相册都属于当前用户。
    if (albums.length !== albumIds.length) {
      throw new BizError('auth.forbidden', 403);
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
        inArray(albumPhotoTab.albumId, albumIds),
        inArray(albumPhotoTab.photoId, photoIds)
      ));
    const existsKeys = new Set(existsRows.map((row) => `${row.albumId}:${row.photoId}`));
    const rows = albumIds.flatMap((albumId) => (
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

  // 按每批 500 个照片 id 核对相册关联，未关联的才写入。
  async addMissingPhoto(params: AlbumAddMissingPhotoBo, userId: string): Promise<void> {

    const albumId = params.albumId?.trim();
    const photoIds = Array.from(new Set((params.photoIds ?? []).filter(Boolean)));
    const batchSize = 500;

    if (!albumId) {
      throw new BizError('album.selectRequired');
    }

    if (!photoIds.length) {
      return;
    }

    const [album] = await orm
      .select({
        albumId: albumTab.albumId
      })
      .from(albumTab)
      .where(and(
        eq(albumTab.albumId, albumId),
        eq(albumTab.userId, userId)
      ))
      .limit(1);

    if (!album) {
      throw new BizError('auth.forbidden', 403);
    }

    for (let index = 0; index < photoIds.length; index += batchSize) {

      const batchPhotoIds = photoIds.slice(index, index + batchSize);
      const linkedRows = await orm
        .select({
          photoId: albumPhotoTab.photoId
        })
        .from(albumPhotoTab)
        .where(and(
          eq(albumPhotoTab.albumId, albumId),
          inArray(albumPhotoTab.photoId, batchPhotoIds)
        ));

      const linkedIds = new Set(linkedRows.map((row) => row.photoId));
      const missingPhotoIds = batchPhotoIds.filter((photoId) => !linkedIds.has(photoId));

      if (missingPhotoIds.length) {
        await this.addPhoto({
          albumIds: [albumId],
          photoIds: missingPhotoIds,
        }, userId);
      }
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

  // 把当前用户相册中的正常照片移入回收站，默认相册仅匹配未关联任何相册的照片。
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
        params.albumId === 'default'
          ? notExists(orm.select({ id: albumPhotoTab.id }).from(albumPhotoTab)
            .where(eq(albumPhotoTab.photoId, photoTab.photoId)))
          : inArray(photoTab.photoId, photoIds),
        eq(photoTab.userId, userId),
        eq(photoTab.status, PhotoStatusEnum.NORMAL),
      ));
  },

  // 删除当前用户指定相册，并清理相册照片关联。
  async delete(params: AlbumDeleteBo, userId: string): Promise<void> {

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
  },
}

export { albumService };
