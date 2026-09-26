import { type SyncCheckBo, type SyncConfigBo } from '@/server/entity/bo/sync';
import { type SyncCheckVo, type SyncGetConfigVo } from '@/server/entity/vo/sync';
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

  // 筛选当前用户照片库中不存在的文件。
  async check(params: SyncCheckBo[], userId: string): Promise<SyncCheckVo[]> {
    const photos = await photoService.listNameSize(userId);
    const photoMap = new Map(
      photos.map((photo) => [`${photo.name}\0${photo.size}`, true])
    );

    return params.filter((file) => !photoMap.has(`${file.name}\0${file.size}`));
  },
};

export { syncService };
