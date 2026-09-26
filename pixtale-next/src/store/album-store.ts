"use client"

import { create } from "zustand"
import { type AlbumVo } from "@/server/entity/vo/album"

// 这个模块管理当前正在进入的相册状态。

interface AlbumState {
  albums: AlbumVo[]
  currentAlbumName: string
  setAlbums: (albums: AlbumVo[]) => void
  setCurrentAlbumName: (name: string) => void
}

// 读取和更新当前相册名称。
const useAlbumStore = create<AlbumState>((set) => ({
  albums: [],
  currentAlbumName: "",

  // 设置全局相册列表。
  setAlbums: (albums) => set({ albums }),

  // 设置当前相册名称。
  setCurrentAlbumName: (name) => set({ currentAlbumName: name }),
}))

export { useAlbumStore }
