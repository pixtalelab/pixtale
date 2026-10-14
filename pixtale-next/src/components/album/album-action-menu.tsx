"use client"

import { useState } from "react"
import { BrushCleaningIcon, GlobeIcon, LockIcon, MoreHorizontalIcon, PencilIcon, PinIcon, Trash2Icon } from "lucide-react"
import { useTranslations } from "next-intl"

import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { AlbumPublicEnum } from "@/server/enums/album-enum"

interface AlbumActionMenuProps {
  albumId: string
  // 当前按钮图标是否显示阴影。
  shadow?: boolean
  onRename: () => void
  onTop: () => void
  onPublic: () => void
  public: number
  onRecycle?: () => void
  onDelete: () => void
}

// 渲染相册卡片右上角的更多操作菜单。
export function AlbumActionMenu({ albumId, shadow = true, onRename, onTop, onPublic, public: publicStatus, onRecycle, onDelete }: AlbumActionMenuProps) {
  const t = useTranslations("albums")
  // 默认相册仅提供清理操作。
  const isDefaultAlbum = albumId === "default"
  // open 记录当前下拉菜单是否打开，用于打开时隐藏图标阴影。
  const [open, setOpen] = useState(false)
  const showShadow = shadow && !open

  return (
    <DropdownMenu open={open} onOpenChange={setOpen}>
      <DropdownMenuTrigger asChild>
        <Button
          type="button"
          size="icon"
          variant="ghost"
          className="size-8 bg-transparent text-white/90 shadow-none hover:bg-transparent hover:text-white"
          aria-label="More album actions"
        >
          <MoreHorizontalIcon
            style={showShadow ? {
              filter: "drop-shadow(0 1px 2px rgba(0,0,0,0.5)) drop-shadow(0 0 1px rgba(0,0,0,0.3))",
            } : undefined}
          />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-33">
        {!isDefaultAlbum && (
          <DropdownMenuGroup>
            <DropdownMenuItem onSelect={onRename}>
              <PencilIcon />
              {t("actions.rename")}
            </DropdownMenuItem>
            <DropdownMenuItem onSelect={onTop}>
              <PinIcon />
              {t("actions.pin")}
            </DropdownMenuItem>
            <DropdownMenuItem onSelect={onPublic}>
              {publicStatus === AlbumPublicEnum.ENABLE ? <LockIcon /> : <GlobeIcon />}
              {publicStatus === AlbumPublicEnum.ENABLE ? t("actions.private") : t("actions.public")}
            </DropdownMenuItem>
          </DropdownMenuGroup>
        )}
        {!isDefaultAlbum && <DropdownMenuSeparator />}
        <DropdownMenuGroup>
          {onRecycle && (
            <DropdownMenuItem variant="destructive" onSelect={onRecycle}>
              <BrushCleaningIcon />
              {t("actions.recycle")}
            </DropdownMenuItem>
          )}
          {!isDefaultAlbum && (
            <DropdownMenuItem variant="destructive" onSelect={onDelete}>
              <Trash2Icon />
              {t("actions.delete")}
            </DropdownMenuItem>
          )}
        </DropdownMenuGroup>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
