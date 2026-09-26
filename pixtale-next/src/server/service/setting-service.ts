import { eq } from 'drizzle-orm';
import { SETTING_KEY } from '@/server/const/global';
import { settingTab, type Setting } from '@/server/entity/setting';
import { orm } from '@/server/infra/db';
import { SettingListStyleEnum, SettingPublicAlbumEnum } from '@/server/enums/setting-enum';

// 这个模块处理系统设置的数据查询业务。

const settingService = {

  // 读取系统配置，数据在建表时已写入，必定存在。
  async get(): Promise<Setting> {
    const [row] = await orm
      .select()
      .from(settingTab)
      .where(eq(settingTab.key, SETTING_KEY))
      .limit(1);

    const setting = JSON.parse(row.value) as Partial<Setting>;

    return {
      ...setting,
      title: setting.title ?? 'Pixtale',
      publicAlbum: setting.publicAlbum ?? SettingPublicAlbumEnum.DISABLE,
      listStyle: setting.listStyle ?? SettingListStyleEnum.MASONRY,
    } as Setting;
  },

  // 覆盖写入整份系统配置。
  async set(params: Setting): Promise<void> {
    await orm
      .update(settingTab)
      .set({ value: JSON.stringify(params) })
      .where(eq(settingTab.key, SETTING_KEY));
  }
};

export { settingService };
