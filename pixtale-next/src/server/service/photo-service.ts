import { and, asc, count, desc, eq, getTableColumns, gte, inArray, isNotNull, like, lt, lte, or, sql, sum } from 'drizzle-orm';
import { createId } from '@/server/lib/id';
import { type Photo, photoTab } from '@/server/entity/photo';
import { albumPhotoTab } from '@/server/entity/album-photo';
import { albumTab } from '@/server/entity/album';
import { orm } from '@/server/infra/db';
import BizError from '@/server/error/biz-error';
import { storage } from '@/server/storage/storage';
import {
  type PhotoDeleteBo,
  type PhotoExistsBo,
  type PhotoFavoriteBo,
  type PhotoListBo,
  type PhotoRecycleBo,
  type PhotoRestoreBo,
  type PhotoTakenDateListBo,
} from '@/server/entity/bo/photo';
import { PHOTO_LIST_PAGE_SIZE } from '@/server/const/global';
import { PhotoFavoriteEnum, PhotoStatusEnum } from '@/server/enums/photo-enum';
import { AlbumPublicEnum } from '@/server/enums/album-enum';
import { StorageTypeEnum, StorageTypeOptions } from '@/server/enums/storage-enum';
import { type PageVo } from '@/server/entity/vo/common';
import { type PhotoAddResultVo, type PhotoExistsVo, type PhotoNameSizeVo, type PhotoTakenDateVo, type PhotoTypeUsageVo, type PhotoVo } from '@/server/entity/vo/photo';
import { type Storage } from '@/server/entity/storage';
import { storageService } from '@/server/service/storage-service';
import { buildContentDisposition, buildContentName, formatFileTimestamp, splitFileName } from '@/server/lib/file';
import { albumService } from '@/server/service/album-service';
import { settingService } from '@/server/service/setting-service';
import { SettingPhotoDedupEnum, SettingSyncDeleteEnum } from '@/server/enums/setting-enum';
import { formatHttpUrl, toMediaUrl } from '@/lib/url';
import { fileChecksum } from '@/server/lib/crypto';
import { processPhotoImages } from '@/server/lib/photo-process';
import { readPhotoExifFromBuffer } from '@/server/lib/photo-exif';
import { type Exif } from '@/server/entity/exif';
import { exifService } from '@/server/service/exif-service';
import { buildPhotoKey, buildPreviewKey, buildThumbnailKey } from '@/server/lib/photo-path';
import { type File as PhotoFile, fileTab } from '@/server/entity/file';
import { fileService } from '@/server/service/file-service';
import { FileTypeEnum } from '@/server/enums/file-enum';

// 这个模块处理照片数据查询相关业务。

const photoService = {

  // 统计全部照片数量，不按照片状态过滤。
  async getAllCount(): Promise<number> {
    const [result] = await orm
      .select({ total: count(photoTab.photoId) })
      .from(photoTab);

    return Number(result.total);
  },

  // 按类型描述统计全部照片数量，返回前六项供分析页合并其他类型。
  async getTopTypeUsage(): Promise<PhotoTypeUsageVo[]> {
    const total = count(photoTab.photoId);
    return orm
      .select({
        typeDesc: photoTab.typeDesc,
        count: total,
      })
      .from(photoTab)
      .groupBy(photoTab.typeDesc)
      .orderBy(desc(total), asc(photoTab.typeDesc))
      .limit(6);
  },

  // 统计全部照片原文件大小，不按照片状态过滤。
  async getAllSize(): Promise<number> {
    const [result] = await orm
      .select({ total: sum(photoTab.size) })
      .from(photoTab);

    return Number(result.total ?? 0);
  },

  // 查询当前用户全部照片的文件名和大小，供同步检查使用。
  async listNameSize(userId: string): Promise<PhotoNameSizeVo[]> {
    return orm
      .select({
        name: photoTab.name,
        size: photoTab.size,
      })
      .from(photoTab)
      .where(eq(photoTab.userId, userId));
  },

  // 分页查询当前用户照片，并按传入条件和拍摄时间排序。
  async list(params: PhotoListBo, userId: string): Promise<PageVo<PhotoVo>> {

    const size = params.size && params.size > 0 ? params.size : PHOTO_LIST_PAGE_SIZE;
    const status = params.status ?? PhotoStatusEnum.NORMAL;
    const orderColumn = status === PhotoStatusEnum.DELETE
      ? photoTab.recycleTime
      : photoTab.takenTime;

    const whereList = [
      eq(photoTab.status, status),
      eq(photoTab.userId, userId)
    ];
    const fileStorageList = await storageService.getStorageList();

    const keyword = params.keyword?.trim();

    if (keyword) {
      const pattern = `%${keyword}%`;

      if (params.searchType === "storage") {
        const normalizedKeyword = keyword.toLocaleLowerCase();

        const storageIds = fileStorageList
          .filter((fileStorage) => fileStorage.name.toLocaleLowerCase().includes(normalizedKeyword))
          .map((fileStorage) => fileStorage.storageId);

        whereList.push(inArray(photoTab.storageId, storageIds));
      } else {
        whereList.push(like(photoTab.name, pattern));
      }
    }

    if (params.favorite) {
      whereList.push(eq(photoTab.favorite, params.favorite));
    }

    if (params.startTakenTime) {
      whereList.push(gte(photoTab.takenTime, params.startTakenTime));
    }

    if (params.endTakenTime) {
      whereList.push(lte(photoTab.takenTime, params.endTakenTime));
    }

    if (params.cursorPhotoId && params.cursorTime) {
      const cursorWhere = or(
        lt(orderColumn, params.cursorTime),
        and(
          eq(orderColumn, params.cursorTime),
          lt(photoTab.photoId, params.cursorPhotoId)
        )
      );

      if (cursorWhere) {
        whereList.push(cursorWhere);
      }
    }

    const list = params.albumId
      ? await orm
        .select(getTableColumns(photoTab))
        .from(photoTab)
        .innerJoin(albumPhotoTab, eq(photoTab.photoId, albumPhotoTab.photoId))
        .where(and(
          ...whereList,
          eq(albumPhotoTab.albumId, params.albumId)
        ))
        .orderBy(desc(orderColumn), desc(photoTab.photoId))
        .limit(size)
      : await orm
        .select()
        .from(photoTab)
        .where(and(...whereList))
        .orderBy(desc(orderColumn), desc(photoTab.photoId))
        .limit(size);

    const photoIds = list.map((photo) => photo.photoId);
    const [exifMap, fileMap] = await Promise.all([
      exifService.listByPhotoIds(photoIds),
      fileService.listByPhotoIds(photoIds),
    ]);

    const result = list.map((photo) => {
      const fileStorage = fileStorageList.find((item) => item.storageId === photo.storageId);
      const domain = formatHttpUrl(fileStorage?.domain);

      return this.toPhotoVo(photo, fileMap.get(photo.photoId) ?? [], fileStorage, domain, exifMap.get(photo.photoId) ?? null);
    });

    return {
      list: result,
      total: result.length
    };
  },

  // 分页查询公开相册中的正常照片，不要求登录用户身份。
  async publicList(params: PhotoListBo): Promise<PageVo<PhotoVo>> {
    const size = params.size && params.size > 0 ? params.size : PHOTO_LIST_PAGE_SIZE;
    const orderColumn = photoTab.takenTime;
    const whereList = [
      eq(photoTab.status, PhotoStatusEnum.NORMAL),
      eq(albumTab.public, AlbumPublicEnum.ENABLE),
    ];

    if (params.albumId) {
      whereList.push(eq(albumPhotoTab.albumId, params.albumId));
    }

    if (params.cursorPhotoId && params.cursorTime) {
      const cursorWhere = or(
        lt(orderColumn, params.cursorTime),
        and(
          eq(orderColumn, params.cursorTime),
          lt(photoTab.photoId, params.cursorPhotoId),
        ),
      );

      if (cursorWhere) {
        whereList.push(cursorWhere);
      }
    }

    const list = await orm
      .selectDistinct(getTableColumns(photoTab))
      .from(photoTab)
      .innerJoin(albumPhotoTab, eq(photoTab.photoId, albumPhotoTab.photoId))
      .innerJoin(albumTab, eq(albumPhotoTab.albumId, albumTab.albumId))
      .where(and(...whereList))
      .orderBy(desc(orderColumn), desc(photoTab.photoId))
      .limit(size);

    const fileStorageList = await storageService.getStorageList();
    const photoIds = list.map((photo) => photo.photoId);
    const [exifMap, fileMap] = await Promise.all([
      exifService.listByPhotoIds(photoIds),
      fileService.listByPhotoIds(photoIds),
    ]);

    const result = list.map((photo) => {
      const fileStorage = fileStorageList.find((item) => item.storageId === photo.storageId);
      const domain = formatHttpUrl(fileStorage?.domain);

      const photoVo = this.toPhotoVo(
        photo,
        fileMap.get(photo.photoId) ?? [],
        fileStorage,
        domain,
        exifMap.get(photo.photoId) ?? null,
      );

      return {
        ...photoVo,
        storageId: null,
        storageName: null,
        storageTypeDesc: null,
      };
    });

    return { list: result, total: result.length };
  },

  // 按天统计当前用户未删除且有拍摄时间的照片。
  async takenDateList(params: PhotoTakenDateListBo, userId: string): Promise<PhotoTakenDateVo[]> {

    const whereList = [
      eq(photoTab.status, PhotoStatusEnum.NORMAL),
      eq(photoTab.userId, userId),
      isNotNull(photoTab.takenTime),
    ];

    if (params.favorite) {
      whereList.push(eq(photoTab.favorite, params.favorite));
    }

    const tzModifier = params.tzOffset >= 0 ? `+${params.tzOffset} minutes` : `${params.tzOffset} minutes`;
    // 按前端传入时区的自然日分组，与列表展示和筛选边界一致。
    const takenDate = sql<string>`date(${photoTab.takenTime}, ${tzModifier})`;
    const selectColumns = {
      date: takenDate,
      count: count(photoTab.photoId),
    };

    const list = params.albumId
      ? await orm
        .select(selectColumns)
        .from(photoTab)
        .innerJoin(albumPhotoTab, eq(photoTab.photoId, albumPhotoTab.photoId))
        .where(and(
          ...whereList,
          eq(albumPhotoTab.albumId, params.albumId)
        ))
        .groupBy(takenDate)
        .orderBy(asc(takenDate))
      : await orm
        .select(selectColumns)
        .from(photoTab)
        .where(and(...whereList))
        .groupBy(takenDate)
        .orderBy(asc(takenDate));

    return list.map((item) => ({
      date: item.date,
      count: Number(item.count),
    }));
  },

  // 根据原文件名生成存储 key，若 key 已存在则在扩展名前追加时间戳。
  async resolvePhotoKey(userId: string, name: string) {

    const trimmedName = name.trim();

    if (!trimmedName) {
      throw new BizError('photo.fileNameRequired');
    }

    let key = buildPhotoKey(userId, trimmedName);
    const [existing] = await orm
      .select({ fileId: fileTab.fileId })
      .from(fileTab)
      .where(eq(fileTab.key, key))
      .limit(1);

    if (existing) {
      const { baseName, extName } = splitFileName(trimmedName);
      key = buildPhotoKey(userId, `${baseName}_${formatFileTimestamp()}${extName}`);
    }

    return key;
  },

  // 根据去重设置和 SHA-1 判断当前用户是否已有相同文件。
  async exists(params: PhotoExistsBo, userId: string): Promise<PhotoExistsVo> {
    const checksum = params.checksum?.trim();
    const name = params.name?.trim();

    if (!checksum || !name) {
      return { duplicate: false };
    }

    const setting = await settingService.get();

    if (setting.photoDedup !== SettingPhotoDedupEnum.ENABLE) {
      return { duplicate: false };
    }

    const [duplicatePhoto] = await orm
      .select({ photoId: photoTab.photoId })
      .from(photoTab)
      .where(and(
        eq(photoTab.userId, userId),
        eq(photoTab.checksum, checksum),
        eq(photoTab.name, name)
      ))
      .limit(1);

    return { duplicate: Boolean(duplicatePhoto) };
  },

  // 上传单张照片，后端生成 preview、thumbnail 和元信息。
  async add(form: FormData, userId: string): Promise<PhotoAddResultVo> {

    const file = form.get('file') as File;
    const storageId = String(form.get('storageId') ?? '');
    const albumId = String(form.get('albumId') ?? '');
    const lastModified = Number(form.get('lastModified') ?? 0);

    if (!file) {
      throw new BizError('photo.selectRequired');
    }

    if (!storageId) {
      throw new BizError('storage.configRequired');
    }

    const fileStorageList = await storageService.getStorageList();
    const fileStorage = fileStorageList.find((item) => item.storageId === storageId);

    if (!fileStorage) {
      throw new BizError('storage.notFound');
    }

    const { buffer, name, size, type } = await this.readPhotoUpload(file);
    const checksum = await fileChecksum(new Blob([buffer]));

    if ((await this.exists({ checksum, name }, userId)).duplicate) {
      return { photo: null, duplicate: true };
    }

    const images = await processPhotoImages(buffer);
    const meta = await readPhotoExifFromBuffer(buffer);
    const takenTime = meta.takenTime ?? new Date(lastModified > 0 ? lastModified : Date.now()).toISOString();
    const key = await this.resolvePhotoKey(userId, name);
    const photoId = createId();
    const preview = buildPreviewKey(userId, photoId);
    const thumbnail = buildThumbnailKey(userId, photoId);

    const cacheMetadata = [['Cache-Control', 'private, max-age=604800']];
    const originalMetadata = [
      ...cacheMetadata,
      ['Content-Disposition', buildContentDisposition(name)]
    ];
    const previewMetadata = [
      ...cacheMetadata,
      ['Content-Disposition', buildContentDisposition(name, '_preview.jpg')]
    ];
    const thumbnailMetadata = [
      ...cacheMetadata,
      ['Content-Disposition', buildContentDisposition(name, '_thumb.webp')]
    ];

    const uploadFiles = [
      {
        key,
        body: buffer,
        type,
        metadata: originalMetadata,
      },
      {
        key: preview,
        body: images.previewBuffer,
        type: 'image/jpeg',
        metadata: previewMetadata,
      },
      {
        key: thumbnail,
        body: images.thumbnailBuffer,
        type: 'image/webp',
        metadata: thumbnailMetadata,
      },
    ];

    await storage.put(uploadFiles, storageId);

    const now = new Date().toISOString();

    const [photo] = await orm.insert(photoTab).values({
      photoId,
      name,
      thumbHash: images.thumbHash,
      checksum,
      type,
      typeDesc: type.split('/').pop() || type,
      size,
      width: images.width,
      height: images.height,
      takenTime,
      createTime: now,
      userId,
      status: PhotoStatusEnum.NORMAL,
      favorite: PhotoFavoriteEnum.NO,
      storageId
    }).returning();

    const files = await fileService.save([
      { fileId: createId(), photoId, key: uploadFiles[0].key, type: FileTypeEnum.ORIGINAL, fileType: type, size },
      { fileId: createId(), photoId, key: uploadFiles[1].key, type: FileTypeEnum.PREVIEW, fileType: 'image/jpeg', size: images.previewBuffer.length },
      { fileId: createId(), photoId, key: uploadFiles[2].key, type: FileTypeEnum.THUMBNAIL, fileType: 'image/webp', size: images.thumbnailBuffer.length },
    ]);

    await exifService.save(photoId, {
      exif: meta.exif,
      latitude: meta.latitude,
      longitude: meta.longitude,
      altitude: meta.altitude,
    });

    if (albumId) {
      await albumService.addPhoto({
        albumIds: [albumId],
        photoIds: [photo.photoId]
      }, userId);
    }

    const domain = formatHttpUrl(fileStorage.domain);

    return {
      photo: this.toPhotoVo(photo, files, fileStorage, domain, {
        photoId,
        exif: meta.exif,
        latitude: meta.latitude,
        longitude: meta.longitude,
        altitude: meta.altitude,
      }),
      duplicate: false,
    };
  },

  // 把当前用户的指定照片移动到回收站，并记录回收时间。
  async recycle(params: PhotoRecycleBo, userId: string): Promise<void> {
    if (!params.photoIds?.length) {
      throw new BizError('photo.selectRequired');
    }

    await orm.update(photoTab)
      .set({
        status: PhotoStatusEnum.DELETE,
        recycleTime: new Date().toISOString()
      })
      .where(and(
        eq(photoTab.userId, userId),
        inArray(photoTab.photoId, params.photoIds)
      ));
  },

  // 设置当前用户指定照片的收藏状态。
  async favorite(params: PhotoFavoriteBo, userId: string): Promise<void> {
    if (!params.photoIds?.length) {
      throw new BizError('photo.selectRequired');
    }

    if (!params.favorite) {
      throw new BizError('photo.favoriteRequired');
    }

    await orm.update(photoTab)
      .set({
        favorite: params.favorite
      })
      .where(and(
        eq(photoTab.userId, userId),
        inArray(photoTab.photoId, params.photoIds)
      ));
  },

  // 恢复当前用户回收站中的指定照片。
  async restore(params: PhotoRestoreBo, userId: string): Promise<void> {
    if (!params.photoIds?.length) {
      throw new BizError('photo.selectRequired');
    }

    await orm.update(photoTab)
      .set({
        status: PhotoStatusEnum.NORMAL,
        recycleTime: null
      })
      .where(and(
        eq(photoTab.userId, userId),
        inArray(photoTab.photoId, params.photoIds)
      ));
  },

  // 彻底删除当前用户的指定照片文件和数据库记录。
  async delete(params: PhotoDeleteBo, userId: string): Promise<void> {
    if (!params.photoIds?.length) {
      throw new BizError('photo.selectRequired');
    }

    const fileStorageList = await storageService.list();

    const photos = await orm
      .select()
      .from(photoTab)
      .where(and(
        eq(photoTab.userId, userId),
        inArray(photoTab.photoId, params.photoIds)
      ));
    const photoIds = photos.map((photo) => photo.photoId);

    if (!photoIds.length) {
      return;
    }

    const fileMap = await fileService.listByPhotoIds(photoIds);

    for (const fileStorage of fileStorageList.list) {
      const keys = photos
        .filter((photo) => photo.storageId === fileStorage.storageId)
        .flatMap((photo) => (fileMap.get(photo.photoId) ?? []).map((item) => item.key));

      await storage.delete(keys, fileStorage.storageId);
    }

    await orm.delete(albumPhotoTab)
      .where(inArray(albumPhotoTab.photoId, photoIds));

    await fileService.deleteByPhotoIds(photoIds);

    await orm.delete(photoTab)
      .where(and(
        eq(photoTab.userId, userId),
        inArray(photoTab.photoId, photoIds)
      ));
  },

  // 按用户 id 或存储 id 分批删除关联照片，并按系统设置决定是否删除远端文件。
  async deleteByUserOrStorage(userId?: string, storageId?: string): Promise<void> {
    if (!userId && !storageId) {
      return;
    }

    const setting = await settingService.get();
    const syncDelete = setting.syncDelete === SettingSyncDeleteEnum.ENABLE;
    const fileStorageList = syncDelete ? await storageService.list() : null;

    while (true) {
      const whereList = [];

      if (userId) {
        whereList.push(eq(photoTab.userId, userId));
      }

      if (storageId) {
        whereList.push(eq(photoTab.storageId, storageId));
      }

      // 每次只取 100 条，避免一次删除过多照片导致存储请求或 SQL 参数过大。
      const photos = await orm
        .select()
        .from(photoTab)
        .where(and(...whereList))
        .limit(100);

      if (!photos.length) {
        return;
      }

      const photoIds = photos.map((photo) => photo.photoId);
      const fileMap = await fileService.listByPhotoIds(photoIds);

      if (fileStorageList) {
        for (const fileStorage of fileStorageList.list) {
          const keys = photos
            .filter((photo) => photo.storageId === fileStorage.storageId)
            .flatMap((photo) => (fileMap.get(photo.photoId) ?? []).map((item) => item.key));

          await storage.delete(keys, fileStorage.storageId);
        }
      }

      await orm.delete(albumPhotoTab)
        .where(inArray(albumPhotoTab.photoId, photoIds));

      await fileService.deleteByPhotoIds(photoIds);

      await orm.delete(photoTab)
        .where(and(
          ...whereList,
          inArray(photoTab.photoId, photoIds)
        ));
    }
  },

  // 清理当前用户回收站中的照片文件和数据库记录。
  async clear(userId: string): Promise<void> {

    const setting = await settingService.get();
    const syncDelete = setting.syncDelete === SettingSyncDeleteEnum.ENABLE;
    const now = new Date().toISOString();

    await this.clearDeletedPhotos({
      userId,
      recycleTime: now,
      syncDelete
    });
  },

  // 定时清理超过设置保留天数的回收站照片文件和数据库记录。
  async clearExpired(): Promise<void> {

    const setting = await settingService.get();

    const syncDelete = setting.syncDelete === SettingSyncDeleteEnum.ENABLE;
    const expireTime = new Date(Date.now() - setting.clearLast * 24 * 60 * 60 * 1000).toISOString();

    await this.clearDeletedPhotos({
      recycleTime: expireTime,
      syncDelete
    });
  },

  // 按传入值循环清理回收站照片文件和数据库记录。
  async clearDeletedPhotos(params: { userId?: string, recycleTime: string, syncDelete: boolean }): Promise<void> {
    const fileStorageList = params.syncDelete ? await storageService.list() : null;

    while (true) {
      const whereList = [
        lte(photoTab.recycleTime, params.recycleTime),
        eq(photoTab.status, PhotoStatusEnum.DELETE)
      ];

      if (params.userId) {
        whereList.push(eq(photoTab.userId, params.userId));
      }

      // 每次只取 100 条，避免一次清理太多照片导致存储删除请求过大。
      const photos = await orm
        .select()
        .from(photoTab)
        .where(and(...whereList))
        .limit(100);

      if (!photos.length) {
        return;
      }

      const photoIds = photos.map((photo) => photo.photoId);
      const fileMap = await fileService.listByPhotoIds(photoIds);

      if (fileStorageList) {
        for (const fileStorage of fileStorageList.list) {

          const keys = photos
            .filter((photo) => photo.storageId === fileStorage.storageId)
            .flatMap((photo) => (fileMap.get(photo.photoId) ?? []).map((item) => item.key));
          await storage.delete(keys, fileStorage.storageId);

        }
      }

      await orm.delete(albumPhotoTab)
        .where(inArray(albumPhotoTab.photoId, photoIds));

      await fileService.deleteByPhotoIds(photoIds);

      await orm.delete(photoTab)
        .where(and(
          ...whereList,
          inArray(photoTab.photoId, photoIds)
        ));
    }
  },

  // 从文件列表取指定类型的存储 key。
  getFileKey(files: PhotoFile[], type: number): string | null {
    return files.find((file) => file.type === type)?.key ?? null;
  },

  // 把存储信息和文件 key 合并进照片返回对象。
  toPhotoVo(photo: Photo, files: PhotoFile[], fileStorage?: Storage, domain?: string, exifRow: Exif | null = null): PhotoVo {
    const key = this.getFileKey(files, FileTypeEnum.ORIGINAL) ?? '';
    const preview = this.getFileKey(files, FileTypeEnum.PREVIEW) ?? '';
    const thumbnail = this.getFileKey(files, FileTypeEnum.THUMBNAIL) ?? '';

    const isTelegramProxy = fileStorage?.type === StorageTypeEnum.TELEGRAM && Boolean(domain);
    let originalDisposition = '';
    let previewDisposition = '';
    let thumbnailDisposition = '';

    if (isTelegramProxy) {
      originalDisposition = buildContentName(photo.name);
      previewDisposition = buildContentName(photo.name, '_preview.jpg');
      thumbnailDisposition = buildContentName(photo.name, '_thumb.webp');
    }

    return {
      ...photo,
      exif: exifRow?.exif ?? null,
      latitude: exifRow?.latitude ?? null,
      longitude: exifRow?.longitude ?? null,
      altitude: exifRow?.altitude ?? null,
      key: isTelegramProxy ? `${toMediaUrl(key, domain)}&${originalDisposition}` : toMediaUrl(key, domain) ?? null,
      preview: isTelegramProxy ? `${toMediaUrl(preview, domain)}&${previewDisposition}` : toMediaUrl(preview, domain) ?? null,
      thumbnail: isTelegramProxy ? `${toMediaUrl(thumbnail, domain)}&${thumbnailDisposition}` : toMediaUrl(thumbnail, domain) ?? null,
      storageName: fileStorage?.name ?? null,
      storageTypeDesc: fileStorage
        ? StorageTypeOptions.find((item) => item.value === fileStorage.type)?.label ?? null
        : null
    };
  },

  // 从上传文件读取照片 buffer 及名称、大小、类型。
  async readPhotoUpload(file: File): Promise<{ buffer: Buffer; name: string; size: number; type: string }> {
    return {
      buffer: Buffer.from(await file.arrayBuffer()),
      name: file.name.trim(),
      size: file.size,
      type: file.type || '',
    };
  }
}

export { photoService }
