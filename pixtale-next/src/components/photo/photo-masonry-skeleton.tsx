"use client"

import { Skeleton } from "@/components/ui/skeleton"
import { type PhotoVo } from "@/server/entity/vo/photo"
import { SettingListStyleEnum } from "@/server/enums/setting-enum"

interface PhotoMasonrySkeletonProps {
  // photos 是用于生成骨架高度的照片初始数据。
  photos: PhotoVo[]
  // listStyle 控制骨架屏是否按原图比例或固定高度展示。
  listStyle?: number
}

// 渲染照片瀑布流加载骨架屏，照片少于 20 张时不显示。
export function PhotoMasonrySkeleton({
  photos,
  listStyle = SettingListStyleEnum.MASONRY,
}: PhotoMasonrySkeletonProps) {
  if (photos.length < 20) {
    return null
  }

  return (
    <div className="w-full overflow-x-hidden columns-2 gap-1 md:columns-[240px]">
      {photos.map((photo) => (
        <Skeleton
          key={photo.photoId}
          className="mb-1 w-full break-inside-avoid rounded-none animate-none"
          style={{
            aspectRatio: listStyle === SettingListStyleEnum.GRID
              ? "1 / 1"
              : `${photo.width || 1} / ${photo.height || 1}`,
          }}
        />
      ))}
    </div>
  )
}
