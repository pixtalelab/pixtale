import { inArray } from 'drizzle-orm';
import { type File, type FileInto, fileTab } from '@/server/entity/file';
import { orm } from '@/server/infra/db';

// 这个模块处理照片文件数据查询与写入。

const fileService = {

  // 按多个照片 id 查询文件记录，按 photoId 分组。
  async listByPhotoIds(photoIds: string[]): Promise<Map<string, File[]>> {

    const map = new Map<string, File[]>();

    if (!photoIds.length) {
      return map;
    }

    const list = await orm
      .select()
      .from(fileTab)
      .where(inArray(fileTab.photoId, photoIds));

    for (const file of list) {
      const files = map.get(file.photoId);

      if (files) {
        files.push(file);
      } else {
        map.set(file.photoId, [file]);
      }
    }

    return map;
  },

  // 批量写入照片文件记录。
  async save(files: FileInto[]): Promise<File[]> {
    if (!files.length) {
      return [];
    }

    return orm.insert(fileTab).values(files).returning();
  },

  // 按照片 id 列表删除文件记录。
  async deleteByPhotoIds(photoIds: string[]): Promise<void> {
    if (!photoIds.length) {
      return;
    }

    await orm.delete(fileTab)
      .where(inArray(fileTab.photoId, photoIds));
  }
};

export { fileService };
