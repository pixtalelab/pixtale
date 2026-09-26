"use client"

import { useCallback, useEffect, useMemo, useRef, useState } from "react"

import { photoList } from "@/request/photo"
import { PHOTO_LIST_PAGE_SIZE } from "@/server/const/global"
import { type PhotoListBo } from "@/server/entity/bo/photo"
import { PhotoStatusEnum } from "@/server/enums/photo-enum"
import { type PhotoVo } from "@/server/entity/vo/photo"
import { usePhotoStore } from "@/store/photo-store"

type PhotoSortField = "takenTime" | "recycleTime"

// 按照片列表排序规则比较两张照片，顺序与后端 desc(time), desc(photoId) 一致。
function comparePhotos(a: PhotoVo, b: PhotoVo, sortField: PhotoSortField) {
  const timeA = a[sortField] ?? ""
  const timeB = b[sortField] ?? ""

  if (timeA !== timeB) {
    return timeB.localeCompare(timeA)
  }

  return b.photoId.localeCompare(a.photoId)
}

// 在已排序列表中找到新照片应插入的位置。
function findPhotoInsertIndex(list: PhotoVo[], photo: PhotoVo, sortField: PhotoSortField) {
  const index = list.findIndex((item) => comparePhotos(photo, item, sortField) < 0)

  return index === -1 ? list.length : index
}

// 管理照片分页列表、触底加载和瀑布流刷新标记。
function usePhotoList(
  params: Partial<PhotoListBo> = {},
  pageSize = PHOTO_LIST_PAGE_SIZE,
  initialPhotos?: PhotoVo[],
  request = photoList,
) {
  const paramsKey = JSON.stringify(params)
  const initialParams = useMemo<Partial<PhotoListBo>>(() => JSON.parse(paramsKey) as Partial<PhotoListBo>, [paramsKey])
  const paramsRef = useRef<Partial<PhotoListBo>>(initialParams) // 保存当前列表请求参数，由显式刷新方法更新。
  const setPageLoading = usePhotoStore((state) => state.setPageLoading)
  const sortField: PhotoSortField = paramsRef.current.status === PhotoStatusEnum.DELETE ? "recycleTime" : "takenTime"
  const initialUsedRef = useRef(false) // 标记服务端首屏数据是否已经用于初始化列表。
  const loadingRef = useRef(false) // 标记当前是否正在加载照片列表。
  const photosRef = useRef<PhotoVo[]>(initialPhotos ?? []) // 保存最新照片列表，供游标分页读取最后一张。
  const hasMoreRef = useRef(initialPhotos ? initialPhotos.length === pageSize : true) // 标记当前查询条件下是否还有下一页。
  const [photos, setPhotos] = useState<PhotoVo[]>(initialPhotos ?? []) // 存储当前页面展示的照片列表。
  const [masonryKey, setMasonryKey] = useState(0) // 控制瀑布流在列表结构变化后重新计算布局。

  useEffect(() => {
    // 有服务端第一页数据时跳过浏览器第一页请求。
    if (!initialUsedRef.current) {
      initialUsedRef.current = true
      photosRef.current = initialPhotos ?? []
      hasMoreRef.current = initialPhotos ? initialPhotos.length === pageSize : true
      return
    }

  }, [initialPhotos, pageSize])

  // 刷新瀑布流布局计算。
  const refreshMasonry = useCallback(() => {
    setMasonryKey((prev) => prev + 1)
  }, [])

  // 加载照片列表，并按当前最后一张照片生成下一页游标。
  const loadPhotoList = useCallback((append: boolean) => {
    if ((append && loadingRef.current) || (!hasMoreRef.current && append)) {
      return
    }

    const queryParams = paramsRef.current

    loadingRef.current = true
    setPageLoading(true)

    const lastPhoto = append ? photosRef.current.at(-1) : null
    const cursorTime = lastPhoto
      ? (queryParams.status === PhotoStatusEnum.DELETE ? lastPhoto.recycleTime : lastPhoto.takenTime)
      : null

    request({
      ...queryParams,
      size: pageSize,
      cursorPhotoId: lastPhoto?.photoId ?? null,
      cursorTime: cursorTime ?? null,
    })
      .then((data) => {
        setPhotos((prev) => {
          const nextPhotos = append ? [...prev, ...data.list] : data.list
          photosRef.current = nextPhotos
          return nextPhotos
        })
        hasMoreRef.current = data.list.length === pageSize
        if (!append) {
          refreshMasonry()
          window.scrollTo(0, 0)
        }
      })
      .finally(() => {
        loadingRef.current = false
        setPageLoading(false)
      })
  }, [pageSize, refreshMasonry, request, setPageLoading])

  // 按传入参数显式刷新第一页列表。
  const refreshPhotoList = useCallback((nextParams?: Partial<PhotoListBo>) => {
    if (nextParams) {
      paramsRef.current = {
        ...paramsRef.current,
        ...nextParams,
      }
    }

    photosRef.current = []
    hasMoreRef.current = true
    loadPhotoList(false)
  }, [loadPhotoList])

  // 处理照片列表触底后的下一页请求。
  const loadMorePhotos = useCallback(() => {
    loadPhotoList(true)
  }, [loadPhotoList])

  // 把新照片按 taken_time 顺序插入列表对应位置，并过滤掉已经存在的照片。
  const prependPhotos = useCallback((photosToAdd: PhotoVo[]) => {
    setPhotos((prev) => {
      const photoIds = new Set(prev.map((photo) => photo.photoId))
      const newPhotos = photosToAdd.filter((photo) => !photoIds.has(photo.photoId))

      if (!newPhotos.length) {
        return prev
      }

      const nextPhotos = [...prev]
      const sortedNewPhotos = [...newPhotos].sort((a, b) => comparePhotos(a, b, sortField))

      for (const photo of sortedNewPhotos) {
        const index = findPhotoInsertIndex(nextPhotos, photo, sortField)
        nextPhotos.splice(index, 0, photo)
      }

      photosRef.current = nextPhotos
      return nextPhotos
    })
    refreshMasonry()
  }, [refreshMasonry, sortField])

  // 从照片列表移除指定照片，列表不足 95 张时继续加载下一页。
  const removePhotos = useCallback((photoIds: string[]) => {
    const photoIdSet = new Set(photoIds)
    const nextPhotos = photosRef.current.filter((photo) => !photoIdSet.has(photo.photoId))

    photosRef.current = nextPhotos
    setPhotos(nextPhotos)
    refreshMasonry()

    if (nextPhotos.length < 95) {
      loadPhotoList(true)
    }
  }, [loadPhotoList, refreshMasonry])

  return {
    photos,
    setPhotos,
    masonryKey,
    loadMorePhotos,
    refreshPhotoList,
    prependPhotos,
    removePhotos,
    refreshMasonry,
  }
}

export { usePhotoList }
