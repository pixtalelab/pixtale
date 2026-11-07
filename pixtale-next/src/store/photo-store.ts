"use client"

import { create } from "zustand"
import { persist } from "zustand/middleware"
import { type PhotoVo } from "@/server/entity/vo/photo"

// 这个模块管理照片上传弹窗状态、信息侧栏开关和上传成功照片队列。

interface UploadedPhoto extends PhotoVo {
  // uploadAlbumId 记录这张新上传照片被加入的相册 id。
  uploadAlbumId: string | null
}

interface PhotoState {
  uploadOpen: boolean
  uploadAlbumId: string | null
  infoOpen: boolean
  videoMuted: boolean
  pageLoading: boolean
  uploadedPhotos: UploadedPhoto[]
  photoCache: Map<string, string>
  // thumbHashCache 按 ThumbHash 缓存转换后的背景图地址。
  thumbHashCache: Map<string, string>
  openUpload: (albumId: string | null) => void
  closeUpload: () => void
  setInfoOpen: (open: boolean) => void
  setVideoMuted: (muted: boolean) => void
  toggleInfoOpen: () => void
  setPageLoading: (loading: boolean) => void
  addUploadedPhoto: (photo: PhotoVo, albumId: string | null) => void
  takeUploadedPhotos: () => UploadedPhoto[]
  getPhotoCache: (photoId: string) => string | undefined
  setPhotoCache: (photoId: string, src: string) => void
}

// 读取和更新照片与视频状态，侧栏开关和视频静音偏好通过 persist 保存。
const usePhotoStore = create<PhotoState>()(persist((set, get) => ({
  uploadOpen: false,
  uploadAlbumId: null,
  infoOpen: true,
  videoMuted: false,
  pageLoading: false,
  uploadedPhotos: [],
  photoCache: new Map(),
  thumbHashCache: new Map(),

  // 打开上传弹窗，并记录本次添加新照片时使用的相册 id。
  openUpload: (albumId) => set({
    uploadOpen: true,
    uploadAlbumId: albumId,
  }),

  // 关闭上传弹窗，保留上传列表里的本地状态。
  closeUpload: () => set({ uploadOpen: false }),

  // 设置信息侧栏展开状态。
  setInfoOpen: (open) => set({ infoOpen: open }),

  // 保存视频播放器的静音状态。
  setVideoMuted: (videoMuted) => set((state) => state.videoMuted === videoMuted ? state : { videoMuted }),

  // 切换信息侧栏展开状态。
  toggleInfoOpen: () => set({ infoOpen: !get().infoOpen }),

  // 设置页面高优先级请求状态。
  setPageLoading: (loading) => set({ pageLoading: loading }),

  // 记录上传成功后返回的照片，等待照片列表页面消费。
  addUploadedPhoto: (photo, albumId) => set((state) => ({
    uploadedPhotos: [...state.uploadedPhotos, {
      ...photo,
      uploadAlbumId: albumId,
    }],
  })),

  // 取出上传成功照片队列，并同步清空队列。
  takeUploadedPhotos: () => {
    const photos = get().uploadedPhotos

    set({ uploadedPhotos: [] })
    return photos
  },

  // 读取已经完成加载的照片缓存。
  getPhotoCache: (photoId) => get().photoCache.get(photoId),

  // 保存已经完成加载的照片缓存。
  setPhotoCache: (photoId, src) => set((state) => {
    const photoCache = new Map(state.photoCache)

    photoCache.set(photoId, src)
    return { photoCache }
  }),
}), {
  name: "photo-store",
  // 只持久化界面偏好，上传队列和缓存不写入本地。
  partialize: (state) => ({ infoOpen: state.infoOpen, videoMuted: state.videoMuted }),
}))

export { usePhotoStore }
