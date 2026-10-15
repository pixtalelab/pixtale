"use client"

import { useMemo } from "react"
import { type RenderComponentProps } from "masonic"
import Link from "next/link"
import { useTranslations } from "next-intl"

import { AlbumActionMenu } from "@/components/album/album-action-menu"
import { getThumbHashUrl } from "@/lib/thumb-hash"
import { type AlbumVo } from "@/server/entity/vo/album"
import { AlbumPublicEnum } from "@/server/enums/album-enum"
import { useAlbumStore } from "@/store/album-store"

type AlbumCardProps = Partial<RenderComponentProps<AlbumVo>> & {
  data: AlbumVo
  href?: string
  showPublicLabel?: boolean
  onRename?: (album: AlbumVo) => void
  onTop?: (album: AlbumVo) => void
  onPublic?: (album: AlbumVo) => void
  onRecycle?: (album: AlbumVo) => void
  onDelete?: (album: AlbumVo) => void
}

// 渲染虚拟列表中的单个相册卡片。
export function AlbumCard({ data, width, href, showPublicLabel = true, onRename, onTop, onPublic, onRecycle, onDelete }: AlbumCardProps) {
  const t = useTranslations()
  const name = data.nameKey ? t(data.nameKey) : data.name
  const setCurrentAlbumName = useAlbumStore((state) => state.setCurrentAlbumName)
  const setScrollPosition = useAlbumStore((state) => state.setScrollPosition)
  const thumbnailSrc = data.thumbnail
  const placeholder = useMemo(() => getThumbHashUrl(data.thumbHash), [data.thumbHash])

  // 点击进入相册前记录当前相册名称，供照片页面包屑展示。
  function saveCurrentAlbumName() {
    setCurrentAlbumName(name)
    setScrollPosition(window.scrollY)
  }

  // 把重命名操作和当前相册交给上层页面。
  function renameAlbum() {
    onRename?.(data)
  }

  // 把置顶操作和当前相册交给上层页面。
  function topAlbum() {
    onTop?.(data)
  }

  // 把删除操作和当前相册交给上层页面。
  function deleteAlbum() {
    onDelete?.(data)
  }

  // 把相册照片移入回收站操作交给上层页面。
  function recycleAlbum() {
    onRecycle?.(data)
  }

  // 把公开状态操作和当前相册交给上层页面。
  function changePublic() {
    onPublic?.(data)
  }

  return (
    <div
      className="group relative"
      style={{ width }}
    >
      <Link
        href={href ?? `/albums/${data.albumId}`}
        prefetch={false}
        className="block"
        onClick={saveCurrentAlbumName}
      >
        <div className="relative aspect-square overflow-hidden bg-muted rounded-xl">
          {placeholder && (
            <img
              src={placeholder}
              alt=""
              className="absolute inset-0 h-full w-full scale-110 blur-sm"
              aria-hidden
            />
          )}
          {thumbnailSrc ? (
            <img
              src={thumbnailSrc}
              alt={name}
              className="absolute inset-0 h-full w-full object-cover duration-300 group-hover:scale-105"
              onError={(event) => {
                event.currentTarget.style.display = "none"
              }}
            />
          ) : (
            <div className="absolute inset-0 bg-[#DDDDDD] dark:bg-muted" />
          )}
        </div>
        <div className="pt-2 text-left">
          <div className="truncate text-base font-semibold">{name}</div>
          <div className="text-sm text-muted-foreground">
            {data.photoTotal}
            {showPublicLabel && data.public === AlbumPublicEnum.ENABLE && (
              <>
                <span className="px-1.5">•</span>
                公开
              </>
            )}
          </div>
        </div>
      </Link>
      {onRename && onTop && onPublic && onDelete && (
        <div className="absolute top-[4px] right-[4px] z-10">
          <AlbumActionMenu
            albumId={data.albumId}
            shadow={Boolean(thumbnailSrc)}
            onRename={renameAlbum}
            onTop={topAlbum}
            onPublic={changePublic}
            public={data.public}
            onRecycle={onRecycle ? recycleAlbum : undefined}
            onDelete={deleteAlbum}
          />
        </div>
      )}
    </div>
  )
}
