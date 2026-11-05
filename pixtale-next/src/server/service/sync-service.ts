import { type SyncCheckBo, type SyncConfigBo } from '@/server/entity/bo/sync';
import { type SyncCheckVo, type SyncGetConfigVo } from '@/server/entity/vo/sync';
import BizError from '@/server/error/biz-error';
import { albumService } from '@/server/service/album-service';
import { photoService } from '@/server/service/photo-service';
import { storageService } from '@/server/service/storage-service';

// 这个模块处理照片同步检查相关业务。

const syncService = {

  // 按名称查询同步配置，并创建当前用户缺少的相册。
  async getConfig(params: SyncConfigBo, userId: string): Promise<SyncGetConfigVo> {
    const albumNames = Array.from(new Set(
      (params.albumName ?? []).map((name) => name.trim()).filter(Boolean)
    ));
    const album = [];

    for (const albumName of albumNames) {
      const item = await albumService.getByName(albumName, userId)
        ?? await albumService.add({ name: albumName }, userId);
      album.push(item);
    }

    const storageExists = await storageService.syncExists(params.storageId);

    return { album, storageExists };
  },

  // 筛选当前用户照片库中不存在的文件，并把已存在且未关联的照片挂到指定相册。
  async check(params: SyncCheckBo, userId: string): Promise<SyncCheckVo[]> {
    const albumId = params.albumId?.trim();
    const files = params.files ?? [];

    if (!albumId) {
      throw new BizError('album.selectRequired');
    }

    const photos = await photoService.listNameSize(userId);
    const photoMap = new Map<string, string[]>();

    for (const photo of photos) {
      const key = `${photo.name}\0${photo.size}`;
      const photoIds = photoMap.get(key);

      if (photoIds) {
        photoIds.push(photo.photoId);
      } else {
        photoMap.set(key, [photo.photoId]);
      }
    }

    const missing: SyncCheckVo[] = [];
    const existingPhotoIds: string[] = [];

    for (const file of files) {
      const photoIds = photoMap.get(`${file.name}\0${file.size}`);

      if (photoIds) {
        existingPhotoIds.push(...photoIds);
      } else {
        missing.push(file);
      }
    }

    // 已入库的照片按批核对相册关联，缺的再补上。
    if (existingPhotoIds.length) {
      await albumService.addMissingPhoto({
        albumId,
        photoIds: existingPhotoIds,
      }, userId);
    }

    return missing;
  },
};

export { syncService };
