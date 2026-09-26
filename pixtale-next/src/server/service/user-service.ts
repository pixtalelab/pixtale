import { hashPassword } from '@/server/lib/crypto';
import { createId } from '@/server/lib/id';
import { count, eq, inArray, sum } from 'drizzle-orm';
import { userTab } from '@/server/entity/user';
import { type UserAddBo, type UserSetAvatarBo, type UserSetBo, type UserPasswordBo, type UserToggleStatusBo } from '@/server/entity/bo/user';
import { photoTab } from '@/server/entity/photo';
import { type PageVo } from '@/server/entity/vo/common';
import { type UserInfoVo, type UserVo } from '@/server/entity/vo/user';
import { type AuthInfo } from '@/server/entity/vo/auth';
import { UserStatusEnum, UserTypeEnum } from '@/server/enums/user-enum';
import BizError from '@/server/error/biz-error';
import { orm } from '@/server/infra/db';
import { cache } from '@/server/infra/cache';
import { AUTH_CACHE_KEY } from '@/server/const/cache';
import { AUTH_CACHE_TTL } from '@/server/const/global';
import { albumService } from '@/server/service/album-service';
import { photoService } from '@/server/service/photo-service';
import { storage } from '@/server/storage/storage';

// 这个模块处理用户数据查询和写入相关业务。

const userService = {

  // 统计全部用户数量，不按用户状态或类型过滤。
  async getAllCount(): Promise<number> {
    const [result] = await orm
      .select({ total: count(userTab.userId) })
      .from(userTab);

    return Number(result.total);
  },

  // 根据环境变量 ADMIN、PASSWORD 初始化管理员，不存在则创建，已存在则跳过。
  async init(): Promise<void> {
    const username = process.env.ADMIN?.trim();
    const password = process.env.PASSWORD?.trim();

    if (!username || !password) {
      console.warn('ADMIN or PASSWORD is not set, skip creating');
      return;
    }

    const [user] = await orm
      .select({
        userId: userTab.userId,
      })
      .from(userTab)
      .where(eq(userTab.username, username))
      .limit(1);

    if (user) {
      console.warn('ADMIN user already exists, skip creating');
      return;
    }

    await this.add({
      username,
      password,
      type: UserTypeEnum.ADMIN,
    });
  },

  // 根据用户 id 查询用户基础信息。
  async getById(userId: string): Promise<UserInfoVo | null> {
    const [user] = await orm
      .select({
        userId: userTab.userId,
        username: userTab.username,
        avatar: userTab.avatar,
        type: userTab.type
      })
      .from(userTab)
      .where(eq(userTab.userId, userId))
      .limit(1);

    return user ?? null;
  },

  // 根据用户名查询用户基础信息。
  async getByName(username: string): Promise<UserInfoVo> {
    const name = username?.trim();

    if (!name) {
      throw new BizError('user.usernameRequired');
    }

    const [user] = await orm
      .select({
        userId: userTab.userId,
        username: userTab.username,
        avatar: userTab.avatar,
        type: userTab.type
      })
      .from(userTab)
      .where(eq(userTab.username, name))
      .limit(1);


    return user;
  },

  // 设置当前用户头像，并返回最新用户基础信息。
  async setAvatar(params: UserSetAvatarBo, userId: string): Promise<UserInfoVo> {

    const [user] = await orm
      .select({
        userId: userTab.userId,
        username: userTab.username,
        avatar: userTab.avatar,
        type: userTab.type
      })
      .from(userTab)
      .where(eq(userTab.userId, userId))
      .limit(1);

    if (user?.avatar) {
      await storage.delete(`profile/${user.avatar}`, 'local');
    }

    const avatarKey = `${createId()}.webp`;
    const match = params.avatar.match(/^data:image\/webp;base64,(.+)$/);

    if (!match?.[1]) {
      throw new BizError('user.avatarInvalid');
    }

    await storage.put([{
      key: `profile/${avatarKey}`,
      body: Buffer.from(match[1], 'base64'),
      type: 'image/webp',
    }], 'local');

    await orm.update(userTab)
      .set({
        avatar: avatarKey
      })
      .where(eq(userTab.userId, userId));

    return {
      ...user,
      avatar: avatarKey
    };
  },

  // 根据头像 key 从存储读取头像文件。
  async getAvatar(key?: string) {

    if (!key) {
      return null;
    }

    try {
      return await storage.get(`profile/${key}`, 'local');
    } catch {
      return null;
    }
  },

  // 查询全部用户，并统计每个用户的照片数量和已用容量。
  async list(): Promise<PageVo<UserVo>> {
    const userList = await orm
      .select()
      .from(userTab);

    if (!userList.length) {
      return { list: [], total: 0 };
    }

    const userIds = userList.map((user) => user.userId);

    const photoStatList = await orm
      .select({
        userId: photoTab.userId,
        photoTotal: count(photoTab.photoId),
        usedCapacity: sum(photoTab.size)
      })
      .from(photoTab)
      .where(inArray(photoTab.userId, userIds))
      .groupBy(photoTab.userId);

    const list = userList.map((user) => {
      const photoStat = photoStatList.find((stat) => stat.userId === user.userId);
      const { password: _password, salt: _salt, ...safeUser } = user;

      return {
        ...safeUser,
        photoTotal: Number(photoStat?.photoTotal ?? 0),
        usedCapacity: Number(photoStat?.usedCapacity ?? 0)
      };
    });

    return { list, total: list.length };
  },

  // 添加用户，并把明文密码转换为带盐哈希后保存。
  async add(params: UserAddBo): Promise<void> {
    const username = params.username?.trim();

    if (!username || !params.password?.trim()) {
      throw new BizError('user.credentialsRequired');
    }

    if (!params.type) {
      throw new BizError('user.typeRequired');
    }

    const [user] = await orm.select().from(userTab).where(eq(userTab.username, username)).limit(1);

    if (user) {
      throw new BizError('user.usernameExists');
    }

    const password = await hashPassword(params.password);
    const userId = createId();
    const now = new Date().toISOString();

    await orm.insert(userTab).values({
      userId,
      username,
      password: password.hash,
      salt: password.salt,
      type: params.type,
      createTime: now,
    });

  },

  // 修改用户信息。
  async set(params: UserSetBo): Promise<void> {
    const userId = params.userId?.trim();
    const username = params.username?.trim();

    if (!userId) {
      throw new BizError('user.selectRequired');
    }

    if (!username) {
      throw new BizError('user.usernameRequired');
    }

    if (!params.type) {
      throw new BizError('user.typeRequired');
    }

    const [user] = await orm
      .select({
        userId: userTab.userId
      })
      .from(userTab)
      .where(eq(userTab.userId, userId))
      .limit(1);

    if (!user) {
      throw new BizError('user.notFound');
    }

    const [existsUser] = await orm
      .select({
        userId: userTab.userId
      })
      .from(userTab)
      .where(eq(userTab.username, username))
      .limit(1);

    if (existsUser && existsUser.userId !== userId) {
      throw new BizError('user.usernameExists');
    }

    const nextPassword = params.password?.trim();
    const updateData: {
      username: string;
      type: number;
      password?: string;
      salt?: string;
    } = {
      username,
      type: params.type,
    };

    if (nextPassword) {
      const password = await hashPassword(nextPassword);
      updateData.password = password.hash;
      updateData.salt = password.salt;
    }

    await orm.update(userTab)
      .set(updateData)
      .where(eq(userTab.userId, userId));

    // 若存在登录缓存，同步更新其中的用户类型。
    const authInfo = await cache.get<AuthInfo>(AUTH_CACHE_KEY + userId);

    if (authInfo) {
      await cache.set(AUTH_CACHE_KEY + userId, {
        ...authInfo,
        type: params.type,
      }, { ttl: AUTH_CACHE_TTL });
    }
  },

  // 修改当前登录用户密码，并重新生成盐和密码哈希。
  async setUserPassword(params: UserPasswordBo, userId: string): Promise<void> {

    if (!params.password?.trim()) {
      throw new BizError('user.passwordRequired');
    }

    const password = await hashPassword(params.password.trim());

    await orm.update(userTab)
      .set({
        password: password.hash,
        salt: password.salt
      })
      .where(eq(userTab.userId, userId));
  },

  // 切换指定用户的启用状态。
  async toggleStatus(params: UserToggleStatusBo): Promise<void> {
    if (!params.userId) {
      throw new BizError('user.selectRequired');
    }

    const [user] = await orm
      .select({
        status: userTab.status
      })
      .from(userTab)
      .where(eq(userTab.userId, params.userId))
      .limit(1);

    if (!user) {
      throw new BizError('user.notFound');
    }

    await orm.update(userTab)
      .set({
        status: user.status === UserStatusEnum.DISABLE
          ? UserStatusEnum.NORMAL
          : UserStatusEnum.DISABLE
      })
      .where(eq(userTab.userId, params.userId));

    // 切换状态后清除登录缓存。
    await cache.delete(AUTH_CACHE_KEY + params.userId);
  },

  // 删除指定用户及其关联相册，并立即删除关联照片。
  async delete(deleteUserId: string): Promise<void> {

    const [user] = await orm
      .select({
        avatar: userTab.avatar
      })
      .from(userTab)
      .where(eq(userTab.userId, deleteUserId))
      .limit(1);

    if (user?.avatar) {
      await storage.delete(`profile/${user.avatar}`, 'local');
    }

    await photoService.deleteByUserOrStorage(deleteUserId);
    await albumService.deleteByUserId(deleteUserId);

    await orm.delete(userTab)
      .where(eq(userTab.userId, deleteUserId));

    // 删除用户后清除登录缓存。
    await cache.delete(AUTH_CACHE_KEY + deleteUserId);
  },
}

export { userService }
