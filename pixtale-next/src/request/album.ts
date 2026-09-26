import { http } from "@/request/request";
import { type Album } from "@/server/entity/album";
import { type AlbumAddBo, type AlbumAddPhotoBo, type AlbumDeleteBo, type AlbumRecycleBo, type AlbumRemovePhotoBo, type AlbumSetNameBo, type AlbumSetPublicBo, type AlbumSetTopBo } from "@/server/entity/bo/album";
import { type AlbumVo } from "@/server/entity/vo/album";

// 这个模块封装相册相关接口请求。

// 查询全部相册列表。
export function albumList() {
  return http.post<AlbumVo[]>('/album/list');
}

// 添加相册。
export function albumAdd(params: AlbumAddBo) {
  return http.post<Album>('/album/add', params);
}

// 给相册添加照片。
export function albumAddPhoto(params: AlbumAddPhotoBo) {
  return http.post<void>('/album/addPhoto', params);
}

// 移除相册中的照片。
export function albumRemovePhoto(params: AlbumRemovePhotoBo) {
  return http.post<void>('/album/removePhoto', params);
}

// 删除相册。
export function albumDelete(params: AlbumDeleteBo) {
  return http.post<void>('/album/delete', params);
}

// 把相册中的照片移入回收站，保留相册。
export function albumRecycle(params: AlbumRecycleBo) {
  return http.post<void>('/album/recycle', params);
}

// 修改相册名称。
export function albumSetName(params: AlbumSetNameBo) {
  return http.post<void>('/album/setName', params);
}

// 置顶相册。
export function albumSetTop(params: AlbumSetTopBo) {
  return http.post<void>('/album/setTop', params);
}

// 修改相册公开状态。
export function albumSetPublic(params: AlbumSetPublicBo) {
  return http.post<void>('/album/setPublic', params);
}

// 查询回收站虚拟相册。
export function albumTrash() {
  return http.post<AlbumVo>('/album/trash');
}
