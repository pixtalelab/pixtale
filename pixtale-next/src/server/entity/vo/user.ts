import { type User } from '@/server/entity/user';

// 这个模块定义用户接口返回对象。

interface UserVo extends Omit<User, 'password' | 'salt'> {
  photoTotal: number;
  usedCapacity: number;
}

interface UserInfoVo {
  userId: string;
  username: string;
  avatar: string;
  type: number;
}

export type { UserVo, UserInfoVo };
