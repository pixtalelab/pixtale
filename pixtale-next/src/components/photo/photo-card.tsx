"use client"

import { useLayoutEffect, useMemo, useRef, useState, type MouseEvent } from "react"
import { HeartIcon } from "lucide-react"
import { type RenderComponentProps } from "masonic"
import { Button } from "@/components/ui/button"
import { Checkbox } from "@/components/ui/checkbox"
import { formatPhotoTakenDate, formatRecycleTime } from "@/lib/date"
import { getThumbHashUrl } from "@/lib/thumb-hash"
import { PhotoFavoriteEnum, PhotoStatusEnum } from "@/server/enums/photo-enum"
import { SettingListStyleEnum } from "@/server/enums/setting-enum"
import { type PhotoVo } from "@/server/entity/vo/photo"
import { usePhotoStore } from "@/store/photo-store"
import { useLocale, useTranslations } from "next-intl"

type TouchHoverCloseRef = {
  current: (() => void) | null
}

type PhotoCardProps = RenderComponentProps<PhotoVo> & {
  // isMobile 由瀑布流统一判断，避免每张卡片重复监听媒体查询。
  isMobile: boolean
  listStyle?: number
  selected?: boolean
  readOnly?: boolean
  selectionActive?: boolean
  onOpen?: () => void
  onFavoriteChange?: (index: number, setFavorite: (favorite: boolean) => void) => void
  onSelectedChange?: (photoId: string, selected: boolean) => void
  touchHoverCloseRef?: TouchHoverCloseRef
}

// 格式化照片展示名称，去掉文件后缀名。
function formatPhotoName(name: string) {
  const index = name.lastIndexOf('.')

  return index > 0 ? name.slice(0, index) : name
}

// 渲染瀑布流中的单张照片卡片。
export function PhotoCard({
  data,
  index,
  width,
  isMobile,
  listStyle = SettingListStyleEnum.MASONRY,
  selected = false,
  readOnly = false,
  selectionActive = false,
  onOpen,
  onFavoriteChange,
  onSelectedChange,
  touchHoverCloseRef,
}: PhotoCardProps) {
  const t = useTranslations("photos")
  const locale = useLocale()
  const src = data.thumbnail || data.preview || data.key
  const ratio = data.width && data.height ? data.height / data.width : 1
  const placeholder = useMemo(() => getThumbHashUrl(data.thumbHash), [data.thumbHash])
  // showTouchHover 记录移动端长按后是否展示悬浮信息。
  const [showTouchHover, setShowTouchHover] = useState(false)
  // holdHover 点击打开查看器时短暂锁定悬浮信息，避免放大动画瞬间缩回。
  const [holdHover, setHoldHover] = useState(false)
  // imageError 记录当前照片缩略图是否加载失败。
  const [imageError, setImageError] = useState(false)
  // imageLoaded 记录当前卡片的图片是否已经完成加载。
  const [imageLoaded, setImageLoaded] = useState(false)
  // imageRef 保存封面元素，用于卸载时清除图片来源。
  const imageRef = useRef<HTMLImageElement>(null)
  // pageLoading 表示页面正在处理高优先级请求，用于暂停未完成的封面请求。
  const pageLoading = usePhotoStore((state) => state.pageLoading)
  // favorite 记录当前照片收藏状态，只刷新当前卡片。
  const [favorite, setFavorite] = useState(data.favorite === PhotoFavoriteEnum.YES)
  const showHover = showTouchHover || holdHover
  const shouldRenderImage = imageLoaded || !pageLoading

  // 清除旧封面来源，并在 effect 重新建立时恢复当前图片地址。
  useLayoutEffect(() => {
    const image = imageRef.current
    if (!image) {
      return
    }

    image.setAttribute("src", src)

    return () => {
      image.removeAttribute("srcset")
      image.removeAttribute("src")
    }
  }, [src])

  // 切换当前照片的选择状态。
  function changeSelected(checked: boolean) {
    onSelectedChange?.(data.photoId, checked)
  }

  // 点击照片时按当前模式执行打开或选择。
  function handlePhotoClick(event: MouseEvent<HTMLDivElement>) {
    if (showTouchHover) {
      event.stopPropagation()
      setShowTouchHover(false)
      if (touchHoverCloseRef) {
        touchHoverCloseRef.current = null
      }
      return
    }

    if (selectionActive) {
      changeSelected(!selected)
      return
    }

    // 移动端没有 hover 放大，不需要锁定悬浮信息。
    if (!isMobile) {
      setHoldHover(true)
      setTimeout(() => setHoldHover(false), 200)
    }

    onOpen?.()
  }

  // 长按照片时阻止系统菜单，并显示原本 hover 才出现的信息。
  function handlePhotoContextMenu(event: MouseEvent<HTMLDivElement>) {
    if (window.innerWidth >= 1024) {
      return
    }

    event.preventDefault()

    if (showTouchHover) {
      setShowTouchHover(false)

      if (touchHoverCloseRef) {
        touchHoverCloseRef.current = null
      }

      return
    }

    touchHoverCloseRef?.current?.()
    setShowTouchHover(true)

    if (touchHoverCloseRef) {
      touchHoverCloseRef.current = () => setShowTouchHover(false)
    }
  }

  // 把当前照片位置交给页面切换收藏状态。
  function handleFavoriteClick(event: MouseEvent<HTMLButtonElement>) {
    event.stopPropagation()
    onFavoriteChange?.(index, setFavorite)
  }

  return (
    <div
      className="group relative overflow-hidden bg-muted"
      onClick={handlePhotoClick}
      onContextMenu={handlePhotoContextMenu}
      style={{
        width,
        height: listStyle === SettingListStyleEnum.GRID
          ? width
          : Math.max(1, Math.round(width * ratio)),
      }}
    >
      {placeholder && (
        <img
          src={placeholder}
          alt=""
          className="absolute inset-0 h-full w-full scale-110 blur-sm"
          aria-hidden
          draggable={false}
        />
      )}
      {imageError ? (
        <div className="absolute inset-0 flex items-center justify-center px-3 text-center text-sm text-muted-foreground">
          {t("imageLoadFailed")}
        </div>
      ) : shouldRenderImage ? (
        <img
          ref={imageRef}
          src={src}
          alt={data.name}
          draggable={false}
          className={[
            "absolute inset-0 h-full w-full object-cover duration-350",
            selectionActive ? "" : "group-hover:scale-105",
            showHover && !selectionActive ? "scale-105" : "",
          ].join(" ")}
          onLoad={() => {
            setImageLoaded(true)
          }}
          onError={(event) => {
            event.currentTarget.style.display = "none"
            setImageError(true)
          }}
        />
      ) : null}
      {selected && (
        <div className="pointer-events-none absolute inset-0 bg-black/60" />
      )}
      {data.status === PhotoStatusEnum.DELETE && (
        <div
          className="pointer-events-none absolute top-[7px] left-[7px] z-10 text-base font-semibold text-white"
          style={{
            filter: "drop-shadow(0 1px 2px rgba(0,0,0,0.4)) drop-shadow(0 0 1px rgba(0,0,0,0.3))",
          }}
        >
          {formatRecycleTime(data.recycleTime, locale)}
        </div>
      )}
      {!readOnly && (
        <div
          className={[
            "absolute top-[6px] right-[6px] z-10 flex size-6 items-center justify-center opacity-0 transition-opacity duration-200 group-hover:opacity-100",
            selected || selectionActive || showHover ? "opacity-100" : "",
          ].join(" ")}
          onClick={(event) => event.stopPropagation()}
        >
          <Checkbox
            aria-label={`Select photo ${data.name}`}
            checked={selected}
            className="!size-4.5 rounded-full border-0 !bg-white/35 data-[state=checked]:!bg-[#e5e5e5] data-[state=checked]:!text-black [&_svg]:!size-3"
            onCheckedChange={(checked) => changeSelected(checked === true)}
          />
        </div>
      )}
      {!selectionActive && (
        <div
          className={[
            "pointer-events-none absolute inset-0 bg-[linear-gradient(to_bottom,rgba(0,0,0,0.20),rgba(0,0,0,0.05)_24%,rgba(0,0,0,0.10)_65%,rgba(0,0,0,0.50))] opacity-0 transition-opacity duration-300 group-hover:opacity-100",
            showHover ? "opacity-100" : "",
          ].join(" ")}
        />
      )}
      {onFavoriteChange && !selectionActive && !selected && (
        <Button
          type="button"
          size="icon-sm"
          className={[
            "absolute right-1 bottom-1 z-10 rounded-full bg-transparent opacity-0 transition-opacity duration-200 hover:bg-transparent group-hover:opacity-100",
            favorite
              ? "text-pink-500 opacity-100"
              : ["text-white/90", isMobile ? "pointer-events-none" : ""].join(" "),
            showHover ? "opacity-100 pointer-events-auto" : "",
          ].join(" ")}
          onClick={handleFavoriteClick}
          aria-label={favorite ? `Remove ${data.name} from favorites` : `Add ${data.name} to favorites`}
        >
          <HeartIcon className="size-[18px] fill-current" />
        </Button>
      )}
      {!selectionActive && (
        <div className="pointer-events-none absolute inset-x-0 bottom-0 p-2.5 pr-11 pb-2.5 text-white">
          <div className="**:duration-300">
            <h3 className={["mb-1 truncate text-sm  opacity-0 group-hover:opacity-100", showHover ? "opacity-100" : ""].join(" ")}>
              {formatPhotoName(data.name)}
            </h3>
            <div className="flex justify-start">
              <span className={["text-xs text-white/90 opacity-0 group-hover:opacity-100", showHover ? "opacity-100" : ""].join(" ")}>
                {formatPhotoTakenDate(data.takenTime, locale)}
              </span>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
