import { http } from "@/request/request";
import { type UserAddBo, type UserDeleteBo, type UserSetAvatarBo, type UserSetBo, type UserPasswordBo, type UserToggleStatusBo } from "@/server/entity/bo/user";
import { type PageVo } from "@/server/entity/vo/common";
import { type UserInfoVo, type UserVo } from "@/server/entity/vo/user";

// 这个模块封装用户相关接口请求。

// 查询当前登录用户信息。
export function userInfo() {
  return http.post<UserInfoVo | null>('/user/info');
}

// 查询全部用户列表。
export function userList() {
  return http.post<PageVo<UserVo>>('/user/list');
}

// 添加用户。
export function userAdd(params: UserAddBo) {
  return http.post<void>('/user/add', params);
}

// 修改用户信息。
export function userSet(params: UserSetBo) {
  return http.post<void>('/user/set', params);
}

// 修改当前登录用户密码。
export function userSetUserPassword(params: UserPasswordBo) {
  return http.post<void>('/user/setUserPassword', params);
}

// 设置当前用户头像。
export function userSetAvatar(params: UserSetAvatarBo) {
  return http.post<string>('/user/setAvatar', params);
}

// 切换用户启用状态。
export function userToggleStatus(params: UserToggleStatusBo) {
  return http.post<void>('/user/toggleStatus', params);
}

// 删除用户。
export function userDelete(userId: string) {
  return http.post<void>('/user/delete', { userId } satisfies UserDeleteBo);
}
