"use client"

import { create } from "zustand"
import { persist } from "zustand/middleware"
import { type StorageSelectVo } from "@/server/entity/vo/storage"

// 这个模块管理存储配置下拉选项状态。

interface StorageState {
  storages: StorageSelectVo[]
  selectedStorageId: string | null
  setStorages: (storages: StorageSelectVo[]) => void
  setSelectedStorageId: (storageId: string) => void
}

// 读取和更新全局存储配置选项。
const useStorageStore = create<StorageState>()(persist((set) => ({
  storages: [],
  selectedStorageId: null,

  // 设置存储配置选项列表。
  setStorages: (storages) => set({ storages }),

  // 保存上传组件最近选中的存储配置 id。
  setSelectedStorageId: (selectedStorageId) => set({ selectedStorageId }),
}), {
  name: "storage-store",
  // 只持久化上传组件的存储选择，列表始终从后端重新加载。
  partialize: (state) => ({ selectedStorageId: state.selectedStorageId }),
}))

export { useStorageStore }
