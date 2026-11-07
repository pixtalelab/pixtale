"use client"

import { create } from "zustand"

// 这个模块管理回收站入口的刷新状态。

interface TrashState {
  // refreshKey 记录需要刷新回收站数量和封面的照片变更次数。
  refreshKey: number
  increaseRefreshKey: () => void
  resetRefreshKey: () => void
}

// 读取和更新回收站刷新标记。
const useTrashStore = create<TrashState>((set) => ({
  refreshKey: 0,

  // 照片变更成功后标记回收站入口需要刷新。
  increaseRefreshKey: () => set((state) => ({ refreshKey: state.refreshKey + 1 })),

  // 回收站入口发起刷新时清除已记录的变更次数。
  resetRefreshKey: () => set({ refreshKey: 0 }),
}))

export { useTrashStore }
