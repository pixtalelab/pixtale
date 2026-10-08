"use client"

import { create } from "zustand"
import { type AlbumVo } from "@/server/entity/vo/album"

// 这个模块管理当前正在进入的相册状态。

interface AlbumState {
  albums: AlbumVo[]
  currentAlbumName: string
  scrollPosition: number
  setAlbums: (albums: AlbumVo[]) => void
  setCurrentAlbumName: (name: string) => void
  setScrollPosition: (position: number) => void
}

// 读取和更新当前相册名称。
const useAlbumStore = create<AlbumState>((set) => ({
  albums: [],
  currentAlbumName: "",
  scrollPosition: 0,

  // 设置全局相册列表。
  setAlbums: (albums) => set({ albums }),

  // 设置当前相册名称。
  setCurrentAlbumName: (name) => set({ currentAlbumName: name }),

  // 设置相册列表滚动位置。
  setScrollPosition: (position) => set({ scrollPosition: position }),
}))

export { useAlbumStore }
