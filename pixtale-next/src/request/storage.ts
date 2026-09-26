import { http } from "@/request/request";
import { type Storage, type StorageInto } from "@/server/entity/storage";
import { type StorageDeleteBo, type StorageSetTopBo, type StorageToggleStatusBo } from "@/server/entity/bo/storage";
import { type PageVo } from "@/server/entity/vo/common";
import { type StorageSelectVo, type StorageVo } from "@/server/entity/vo/storage";

// 这个模块封装存储配置相关接口请求。

// 查询全部存储配置列表。
export function storageList() {
  return http.post<PageVo<StorageVo>>('/storage/list');
}

// 查询正常存储配置选项。
export function storageSelect() {
  return http.post<StorageSelectVo[]>('/storage/select');
}

// 添加存储配置。
export function storageAdd(params: StorageInto) {
  return http.post<void>('/storage/add', params);
}

// 修改存储配置。
export function storageSet(params: Storage) {
  return http.post<void>('/storage/set', params);
}

// 置顶存储配置。
export function storageSetTop(params: StorageSetTopBo) {
  return http.post<void>('/storage/setTop', params);
}

// 切换存储启用状态。
export function storageToggleStatus(params: StorageToggleStatusBo) {
  return http.post<void>('/storage/toggleStatus', params);
}

// 删除存储配置。
export function storageDelete(storageId: string) {
  return http.post<void>('/storage/delete', { storageId } satisfies StorageDeleteBo);
}
