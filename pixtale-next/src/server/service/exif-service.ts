import { inArray } from 'drizzle-orm';
import { type ExifSaveBo } from '@/server/entity/bo/exif';
import { type Exif, exifTab } from '@/server/entity/exif';
import { orm } from '@/server/infra/db';

// 这个模块处理照片 Exif 的读写。

const exifService = {

  // 按多个照片 id 批量查询 exif 记录。
  async listByPhotoIds(photoIds: string[]): Promise<Map<string, Exif>> {
    if (!photoIds.length) {
      return new Map();
    }

    const rows = await orm
      .select()
      .from(exifTab)
      .where(inArray(exifTab.photoId, photoIds));

    return new Map(rows.map((row) => [row.photoId, row]));
  },

  // 保存照片 exif JSON 与位置信息。
  async save(photoId: string, params: ExifSaveBo): Promise<void> {
    const { exif, latitude, longitude, altitude } = params;

    if (!exif && latitude == null && longitude == null && altitude == null) {
      return;
    }

    await orm.insert(exifTab).values({
      photoId,
      exif,
      latitude,
      longitude,
      altitude
    });
  }
};

export { exifService };
