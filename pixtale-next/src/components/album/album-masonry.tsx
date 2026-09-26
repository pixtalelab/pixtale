"use client"

import { useEffect, useLayoutEffect, useRef, useState } from "react"
import { flushSync } from "react-dom"
import {
  MasonryScroller,
  type Positioner,
  usePositioner,
} from "masonic"

import { AlbumCard } from "@/components/album/album-card"
import { type AlbumVo } from "@/server/entity/vo/album"

interface AlbumMasonryProps {
  albums: AlbumVo[]
  resetKey?: number
  sidebarOpen?: boolean
  albumHref?: (album: AlbumVo) => string
  showPublicLabel?: boolean
  onAlbumRename?: (album: AlbumVo) => void
  onAlbumTop?: (album: AlbumVo) => void
  onAlbumPublic?: (album: AlbumVo) => void
  onAlbumRecycle?: (album: AlbumVo) => void
  onAlbumDelete?: (album: AlbumVo) => void
}

// 把 rem 单位转换为当前根字号下的 px。
function remToPx(rem: number) {
  const rootFontSize = parseFloat(
    getComputedStyle(document.documentElement).fontSize
  )

  return rem * rootFontSize
}

// 根据侧边栏状态计算相册列表初始化宽度。
function getInitialWrapWidth(sidebarOpen: boolean) {
  const width = window.innerWidth

  if (width < 768) {
    return width
  }

  return width - remToPx(sidebarOpen ? 16.25 : 5.25)
}

// 计算相册卡片在当前列宽下的固定高度。
function getAlbumHeight(columnWidth: number) {
  return Math.max(1, Math.round(columnWidth) + 52)
}

// 同步每个相册卡片高度到 masonic positioner。
function syncAlbumPositioner(items: AlbumVo[], columnWidth: number, positioner: Positioner) {
  const height = getAlbumHeight(columnWidth)
  const updates: number[] = []

  items.forEach((_, index) => {
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

// 渲染相册虚拟滚动列表。
export function AlbumMasonry({ albums, resetKey = 0, sidebarOpen = false, albumHref, showPublicLabel = true, onAlbumRename, onAlbumTop, onAlbumPublic, onAlbumRecycle, onAlbumDelete }: AlbumMasonryProps) {
  // wrapRef 用于监听相册列表外层真实可视宽度。
  const wrapRef = useRef<HTMLDivElement | null>(null)
  // windowHeight 用于告诉 masonic 当前虚拟滚动可视高度。
  const [windowHeight, setWindowHeight] = useState(() => window.innerHeight)
  // wrapPosition 记录相册列表外层容器的页面位置和布局宽度。
  const [wrapPosition, setWrapPosition] = useState({ offset: 0, width: getInitialWrapWidth(sidebarOpen) })

  const width = wrapPosition.width
  const columnWidth = innerWidth < 768 ? (width - 20) / 2 : 200
  const positioner = usePositioner(
    {
      width,
      columnWidth,
      columnGutter: innerWidth < 768 ? 16 : 20,
      rowGutter: innerWidth < 768 ? 16 : 20,
    },
    [resetKey]
  )

  syncAlbumPositioner(albums, positioner.columnWidth, positioner)

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
    // 监听相册列表外层可视容器宽度变化。
    const container = wrapRef.current

    if (!container) {
      return
    }

    const containerEl = container
    let timerId: number | null = null

    // 计算相册列表外层距离页面顶部的位置。
    function getOffset() {
      let offset = 0
      let el: HTMLElement | null = containerEl

      while (el) {
        offset += el.offsetTop
        el = el.offsetParent as HTMLElement | null
      }

      return offset
    }

    // 获取相册列表外层当前的位置和宽度。
    function getWrapPosition() {
      return {
        offset: getOffset(),
        width: containerEl.offsetWidth,
      }
    }

    // 强制同步相册列表外层的位置和宽度。
    function syncWrapPosition() {
      console.log(wrapPosition.width)
      setWrapPosition(getWrapPosition())
    }

    // 测量相册列表外层的位置和宽度，首次同步完成后再强制读取一次。
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

  return (
    <div ref={wrapRef} className="w-full overflow-x-hidden">
      <MasonryScroller
        items={albums}
        positioner={positioner}
        offset={wrapPosition.offset}
        height={windowHeight}
        itemKey={(item) => item.albumId}
        render={(props) => (
          <AlbumCard
            {...props}
            href={albumHref?.(props.data)}
            showPublicLabel={showPublicLabel}
            onRename={onAlbumRename}
            onTop={onAlbumTop}
            onPublic={onAlbumPublic}
            onRecycle={onAlbumRecycle}
            onDelete={onAlbumDelete}
          />
        )}
      />
    </div>
  )
}
