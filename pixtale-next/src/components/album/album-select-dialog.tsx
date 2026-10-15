"use client"

import { useEffect, useState } from "react"
import { useTranslations } from "next-intl"

import { Dialog } from "@/components/common/dialog"
import { Checkbox } from "@/components/ui/checkbox"
import {
  Item,
  ItemContent,
  ItemDescription,
  ItemGroup,
  ItemMedia,
  ItemTitle,
} from "@/components/ui/item"
import { useAlbumStore } from "@/store/album-store"

interface AlbumSelectDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  onAlbumSelect: (albumIds: string[]) => void
}

// 渲染加入相册时使用的相册选择弹框。
export function AlbumSelectDialog({ open, onOpenChange, onAlbumSelect }: AlbumSelectDialogProps) {
  const t = useTranslations("albums")
  const albums = useAlbumStore((state) => state.albums)
  // selectedAlbumIds 保存当前选中的相册 id 列表。
  const [selectedAlbumIds, setSelectedAlbumIds] = useState<string[]>([])

  // 关闭弹框后清空已选相册。
  useEffect(() => {
    if (!open) {
      setSelectedAlbumIds([])
    }
  }, [open])

  // 切换当前多选相册。
  function changeAlbum(albumId: string) {
    setSelectedAlbumIds((prev) => (
      prev.includes(albumId)
        ? prev.filter((item) => item !== albumId)
        : [...prev, albumId]
    ))
  }

  // 选中相册后把相册 id 列表交给父组件，并关闭弹框。
  function selectAlbum(albumIds: string[]) {
    onAlbumSelect(albumIds)
    onOpenChange(false)
  }

  // 保存当前选择，没有选择时直接关闭弹框。
  function saveAlbum() {
    if (!selectedAlbumIds.length) {
      onOpenChange(false)
      return
    }

    selectAlbum(selectedAlbumIds)
  }

  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t("addPhotosTitle")}
      showCloseButton={false}
      onConfirm={saveAlbum}
    >
      <div className="flex flex-col gap-3 max-h-[60vh] overflow-auto pb-0.25">
        {!albums.length && (
          <div className="py-8 text-center text-sm text-muted-foreground">
            {t("empty")}
          </div>
        )}
        {!!albums.length && (
          <ItemGroup className="gap-2">
            {albums.map((album) => (
              <Item
                key={album.albumId}
                variant="outline"
                role="listitem"
                className="h-20.5 [contain-intrinsic-size:100%_82px] [content-visibility:auto]"
                onClick={() => changeAlbum(album.albumId)}
              >
                <ItemMedia variant="image" className="size-14 rounded-md">
                  {album.thumbnail ? (
                    <img
                      src={album.thumbnail}
                      alt={album.name}
                    />
                  ) : (
                    <span className="h-full w-full bg-muted" />
                  )}
                </ItemMedia>
                <ItemContent className="min-w-0 basis-0">
                  <ItemTitle className="block w-full min-w-0 overflow-hidden text-ellipsis whitespace-nowrap">
                    {album.name}
                  </ItemTitle>
                  <ItemDescription>{album.photoTotal}</ItemDescription>
                </ItemContent>
                <ItemContent className="flex-none">
                  <Checkbox
                    checked={selectedAlbumIds.includes(album.albumId)}
                    aria-label={`Select ${album.name}`}
                    onClick={(event) => event.stopPropagation()}
                    onCheckedChange={() => changeAlbum(album.albumId)}
                  />
                </ItemContent>
              </Item>
            ))}
          </ItemGroup>
        )}
      </div>
    </Dialog>
  )
}
