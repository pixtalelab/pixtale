import { http, type RequestConfig } from "@/request/request";
import { type PhotoDeleteBo, type PhotoExistsBo, type PhotoFavoriteBo, type PhotoListBo, type PhotoRecycleBo, type PhotoRestoreBo, type PhotoTakenDateListBo } from "@/server/entity/bo/photo";
import { type PageVo } from "@/server/entity/vo/common";
import { type PhotoAddResultVo, type PhotoExistsVo, type PhotoTakenDateVo, type PhotoVo } from "@/server/entity/vo/photo";
// 这个模块封装照片相关接口请求。

// 分页按条件查询照片列表。
export function photoList(params: PhotoListBo) {
  return http.post<PageVo<PhotoVo>>('/photo/list', params, { priority: 'high' });
}

// 分页查询公开相册中的照片列表。
export function publicPhotoList(params: PhotoListBo) {
  return http.post<PageVo<PhotoVo>>('/photo/publicList', params, { priority: 'high' });
}

// 按天查询存在照片的拍摄日期及照片数量。
export function photoTakenDateList(params: PhotoTakenDateListBo) {
  return http.post<PhotoTakenDateVo[]>('/photo/takenDateList', params);
}

// 上传单张照片。
export function photoAdd(params: FormData) {
  return http.post<PhotoAddResultVo>('/photo/add', params);
}

// 上传前检查文件是否已经存在。
export function photoExists(params: PhotoExistsBo) {
  return http.post<PhotoExistsVo>('/photo/exists', params);
}

// 把照片移动到回收站。
export function photoRecycle(params: PhotoRecycleBo) {
  return http.post<void>('/photo/recycle', params);
}

// 设置照片收藏状态。
export function photoFavorite(params: PhotoFavoriteBo) {
  return http.post<void>('/photo/favorite', params);
}

// 恢复回收站照片。
export function photoRestore(params: PhotoRestoreBo) {
  return http.post<void>('/photo/restore', params);
}

// 彻底删除回收站照片。
export function photoDelete(params: PhotoDeleteBo) {
  return http.post<void>('/photo/delete', params);
}

// 清空回收站照片。
export function photoClear(config?: RequestConfig) {
  return http.post<void>('/photo/clear', null, config);
}
