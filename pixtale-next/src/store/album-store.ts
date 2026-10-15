"use client"

import { create } from "zustand"
import { type AlbumVo } from "@/server/entity/vo/album"

// 这个模块管理当前正在进入的相册状态。

interface AlbumState {
  albums: AlbumVo[]
  currentAlbumName: string
  scrollPosition: number
  // refreshKey 记录需要刷新相册列表的照片变更次数。
  refreshKey: number
  increaseRefreshKey: () => void
  resetRefreshKey: () => void
  setAlbums: (albums: AlbumVo[]) => void
  setCurrentAlbumName: (name: string) => void
  setScrollPosition: (position: number) => void
}

// 读取和更新当前相册名称。
const useAlbumStore = create<AlbumState>((set) => ({
  albums: [],
  currentAlbumName: "",
  scrollPosition: 0,
  refreshKey: 0,

  // 照片变更成功后标记相册列表需要刷新。
  increaseRefreshKey: () => set((state) => ({ refreshKey: state.refreshKey + 1 })),

  // 相册列表发起刷新时清除已记录的变更次数。
  resetRefreshKey: () => set({ refreshKey: 0 }),

  // 设置全局相册列表。
  setAlbums: (albums) => set({ albums }),

  // 设置当前相册名称。
  setCurrentAlbumName: (name) => set({ currentAlbumName: name }),

  // 设置相册列表滚动位置。
  setScrollPosition: (position) => set({ scrollPosition: position }),
}))

export { useAlbumStore }
