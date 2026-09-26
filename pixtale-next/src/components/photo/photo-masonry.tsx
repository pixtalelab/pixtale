"use client"

import { memo, useEffect, useRef, useState, useLayoutEffect } from "react"
import { flushSync } from "react-dom"
import {
  MasonryScroller,
  type Positioner,
  usePositioner,
} from "masonic"

import { useIsMobile } from "@/hooks/use-mobile"
import { PhotoCard } from "@/components/photo/photo-card"
import { PhotoSelectionDrawer } from "@/components/photo/photo-selection-drawer"
import { type PhotoVo } from "@/server/entity/vo/photo"
import { SettingListStyleEnum } from "@/server/enums/setting-enum"

interface PhotoMasonryProps {
  photos: PhotoVo[]
  resetKey?: number
  onReachBottom: () => void
  onPhotoOpen?: (index: number) => void
  onPhotoFavorite?: (index: number, setFavorite: (favorite: boolean) => void) => void
  onPhotoDelete?: (photoIds: string[]) => void
  onPhotoRestore?: (photoIds: string[]) => void
  onAlbumOpen?: (photoIds: string[]) => void
  onAlbumRemove?: (photoIds: string[]) => void
  sidebarOpen?: boolean
  readOnly?: boolean
  listStyle?: number
}

// 把 rem 单位转换为当前根字号下的 px。
function remToPx(rem: number) {
  const rootFontSize = parseFloat(
    getComputedStyle(document.documentElement).fontSize
  )

  return rem * rootFontSize
}

// 根据侧边栏状态计算瀑布流初始化宽度。
function getInitialWrapWidth(sidebarOpen: boolean, readOnly: boolean) {
  const width = window.innerWidth

  if (readOnly || width < 768) {
    return width
  }

  return width - remToPx(sidebarOpen ? 14.25 : 3.25)
}

// 根据列表样式计算照片卡片高度，确保虚拟列表和实际卡片保持一致。
function getPhotoHeight(photo: PhotoVo, columnWidth: number, listStyle: number) {
  if (listStyle === SettingListStyleEnum.GRID) {
    return columnWidth
  }

  const ratio = photo.width && photo.height ? photo.height / photo.width : 1
  return Math.max(1, Math.round(columnWidth * ratio))
}

// 同步每张照片高度到 masonic positioner。
function syncPhotoPositioner(items: PhotoVo[], columnWidth: number, listStyle: number, positioner: Positioner) {
  const updates: number[] = []

  items.forEach((photo, index) => {
    const height = getPhotoHeight(photo, columnWidth, listStyle)
    const current = positioner.get(index)

    if (!current) {
      positioner.set(index, height)
    } else if (current.height !== height) {
      updates.push(index, height)
    }
  })

  if (updates.length) {
    positioner.update(updates)
  }
}

// 渲染照片瀑布流，并在窗口触底时通知父组件加载更多。
const PhotoMasonry = memo(function PhotoMasonry({
  photos,
  resetKey = 0,
  onReachBottom,
  onPhotoOpen,
  onPhotoFavorite,
  onPhotoDelete,
  onPhotoRestore,
  onAlbumOpen,
  onAlbumRemove,
  sidebarOpen = false,
  readOnly = false,
  listStyle = SettingListStyleEnum.MASONRY,
}: PhotoMasonryProps) {
  // isMobile 判断当前是否为移动端视口。
  const isMobile = useIsMobile()
  // wrapRef 用于监听瀑布流外层真实可视宽度。
  const wrapRef = useRef<HTMLDivElement | null>(null)
  // onReachBottomRef 用于保存最新的触底回调。
  const onReachBottomRef = useRef(onReachBottom)
  // windowHeight 用于告诉 masonic 当前虚拟滚动可视高度。
  const [windowHeight, setWindowHeight] = useState(() => window.innerHeight)
  // wrapPosition 记录瀑布流外层容器的页面位置和布局宽度。
  const [wrapPosition, setWrapPosition] = useState({
    offset: 0,
    width: getInitialWrapWidth(sidebarOpen, readOnly),
  })
  // selectedPhotoIds 记录当前选中的照片 id。
  const [selectedPhotoIds, setSelectedPhotoIds] = useState<string[]>([])
  // touchHoverCloseRef 记录当前展示悬浮信息照片的关闭方法。
  const touchHoverCloseRef = useRef<(() => void) | null>(null)
  const width = wrapPosition.width
  const columnWidth = innerWidth < 768 ? (width - 4) / 2 : 240
  const positioner = usePositioner(
    {
      width,
      columnWidth,
      columnGutter: 4,
      rowGutter: 4,
    },
    [resetKey]
  )

  syncPhotoPositioner(photos, positioner.columnWidth, listStyle, positioner)
  const visibleSelectedPhotoIds = selectedPhotoIds.filter((photoId) => photos.some((photo) => photo.photoId === photoId))


  useEffect(() => {
    // 保持触底回调为父组件传入的最新方法。
    onReachBottomRef.current = onReachBottom
  }, [onReachBottom])

  useEffect(() => {
    // 更新窗口高度，供 masonic 计算可视区域。
    function handleResize() {
      setWindowHeight(window.innerHeight)
    }

    window.addEventListener("resize", handleResize)

    return () => {
      window.removeEventListener("resize", handleResize)
    }
  }, [])

  useLayoutEffect(() => {
    // 监听瀑布流外层可视容器宽度变化。
    const container = wrapRef.current

    if (!container) {
      return
    }

    const containerEl = container
    let timerId: number | null = null

    // 计算瀑布流外层距离页面顶部的位置。
    function getOffset() {
      let offset = 0
      let el: HTMLElement | null = containerEl

      while (el) {
        offset += el.offsetTop
        el = el.offsetParent as HTMLElement | null
      }

      return offset
    }

    // 获取瀑布流外层当前的位置和宽度。
    function getWrapPosition() {
      return {
        offset: getOffset(),
        width: containerEl.offsetWidth,
      }
    }

    // 强制同步瀑布流外层的位置和宽度。
    function syncWrapPosition() {
      console.log(wrapPosition.width);
      setWrapPosition(getWrapPosition())
    }

    // 测量瀑布流外层的位置和宽度，首次同步完成后再强制读取一次。
    function measureWrapPosition() {
      const nextPosition = getWrapPosition()
      let needSync = false

      flushSync(() => {
        setWrapPosition((prev) => {
          const widthDiff = Math.abs(prev.width - nextPosition.width)
          const sameOffset = prev.offset === nextPosition.offset

          if (widthDiff <= 10 && sameOffset) {
            return prev
          }

          needSync = true
          return nextPosition
        })
      })

      if (needSync) {
        syncWrapPosition()
      }
    }

    // 把 ResizeObserver 的通知防抖到停止变化 300ms 后处理。
    function updateWrapPosition() {
      if (timerId !== null) {
        window.clearTimeout(timerId)
      }

      timerId = window.setTimeout(() => {
        timerId = null
        measureWrapPosition()
      }, 350)
    }

    syncWrapPosition()

    const resizeObserver = new ResizeObserver(updateWrapPosition)

    resizeObserver.observe(containerEl)

    return () => {
      if (timerId !== null) {
        window.clearTimeout(timerId)
      }

      resizeObserver.disconnect()
    }
  }, [])

  useEffect(() => {
    // 处理窗口触底，通知父组件请求下一页照片。
    function handleWindowScroll() {
      if (touchHoverCloseRef.current) {
        touchHoverCloseRef.current()
        touchHoverCloseRef.current = null
      }

      const bottomDistance = document.documentElement.scrollHeight - window.scrollY - window.innerHeight
      let threshold = (isMobile ? 7000 : 2200)
        - (listStyle === SettingListStyleEnum.GRID ? (isMobile ? 1000 : 300) : 0)

      if (photos.length >= 200) {
        threshold *= 1.5
      }

      if (bottomDistance <= threshold) {
        onReachBottomRef.current()
      }
    }

    window.addEventListener("scroll", handleWindowScroll)

    return () => {
      window.removeEventListener("scroll", handleWindowScroll)
    }
  }, [isMobile, photos.length])

  // 切换照片选择数组中的 photoId。
  function changePhotoSelected(photoId: string, selected: boolean) {
    setSelectedPhotoIds((prev) => {
      if (selected) {
        return prev.includes(photoId) ? prev : [...prev, photoId]
      }

      return prev.filter((id) => id !== photoId)
    })
  }

  // 清空当前照片列表中的选中项。
  function clearSelectedPhotos() {
    setSelectedPhotoIds([])
  }

  // 从列表前面开始补选照片，最多选中 100 张。
  function selectFirstPhotos() {
    setSelectedPhotoIds((prev) => {
      const visibleIds = prev.filter((photoId) => photos.some((photo) => photo.photoId === photoId))
      const allPhotosSelected = photos.length > 0 && photos.every((photo) => visibleIds.includes(photo.photoId))

      if (visibleIds.length >= 100 || allPhotosSelected) {
        return []
      }

      const remainTotal = Math.max(0, 100 - visibleIds.length)

      if (!remainTotal) {
        return visibleIds
      }

      const selectedSet = new Set(visibleIds)
      const idsToAdd = photos
        .map((photo) => photo.photoId)
        .filter((photoId) => !selectedSet.has(photoId))
        .slice(0, remainTotal)

      return [...visibleIds, ...idsToAdd]
    })
  }

  // 清空选中状态后把当前选中的照片 id 传给页面删除。
  function deleteSelectedPhotos() {
    const photoIds = visibleSelectedPhotoIds
    clearSelectedPhotos()
    onPhotoDelete?.(photoIds)
  }

  // 把当前选中的照片 id 传给页面恢复。
  function restoreSelectedPhotos() {
    onPhotoRestore?.(visibleSelectedPhotoIds)
    clearSelectedPhotos()
  }

  // 把当前选中的照片 id 传给页面打开相册选择。
  function openAlbumDialog() {
    onAlbumOpen?.(visibleSelectedPhotoIds)
    clearSelectedPhotos()
  }

  // 清空选中状态后把当前选中的照片 id 传给页面移出相册。
  function removeAlbumPhotos() {
    const photoIds = visibleSelectedPhotoIds
    clearSelectedPhotos()
    onAlbumRemove?.(photoIds)
  }

  return (
    <>
      {!readOnly && (
        <PhotoSelectionDrawer
          open={visibleSelectedPhotoIds.length > 0}
          onClose={clearSelectedPhotos}
          onDelete={deleteSelectedPhotos}
          onSelectAll={selectFirstPhotos}
          onRestore={onPhotoRestore ? restoreSelectedPhotos : undefined}
          onAlbumOpen={onAlbumOpen ? openAlbumDialog : undefined}
          onAlbumRemove={onAlbumRemove ? removeAlbumPhotos : undefined}
        />
      )}
      <div ref={wrapRef} className="w-full overflow-x-hidden">
        <MasonryScroller
          className="outline-transparent"
          items={photos}
          positioner={positioner}
          offset={wrapPosition.offset}
          height={windowHeight}
          itemKey={(item) => item.photoId}
          render={(props) => (
            <PhotoCard
              {...props}
              isMobile={isMobile}
              listStyle={listStyle}
              readOnly={readOnly}
              selected={visibleSelectedPhotoIds.includes(props.data.photoId)}
              selectionActive={visibleSelectedPhotoIds.length > 0}
              onOpen={() => onPhotoOpen?.(props.index)}
              onFavoriteChange={onPhotoFavorite}
              onSelectedChange={changePhotoSelected}
              touchHoverCloseRef={touchHoverCloseRef}
            />
          )}
        />
      </div>
    </>
  )
})

export { PhotoMasonry }
