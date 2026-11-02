"use client"

import Artplayer from "artplayer"
import { useLocale } from "next-intl"
import { useLayoutEffect, useRef } from "react"
import type { ContainerRect, GenericSlide } from "yet-another-react-lightbox"

import { getThumbHashUrl } from "@/lib/thumb-hash"

export type VideoSlide = GenericSlide & {
  type: "video"
  photoId: string
  src: string
  poster: string
  thumbnail: string
  thumbHash: string
  alt: string
  width?: number
  height?: number
}

declare module "yet-another-react-lightbox" {
  interface SlideTypes {
    video: VideoSlide
  }
}

// 当前视频进入时创建播放器，切走时销毁，预渲染封面保持滑动衔接。
export default function PhotoVideo({ slide, rect, active }: {
  slide: VideoSlide
  rect: ContainerRect
  active: boolean
}) {
  const locale = useLocale()
  // containerRef 是 ArtPlayer 管理的 DOM 容器。
  const containerRef = useRef<HTMLDivElement>(null)
  // playerRef 保存当前播放器实例，用于判断全屏状态。
  const playerRef = useRef<Artplayer | null>(null)
  // pointerRef 记录画面按下位置和拖动状态，避免拖动结束后误触播放。
  const pointerRef = useRef<{ x: number; y: number; dragged: boolean } | null>(null)
  // 根据视频比例和查看器可用空间固定播放器尺寸，避免加载时布局跳动。
  const ratio = slide.width && slide.height ? slide.width / slide.height : 16 / 9
  const width = Math.min(rect.width, rect.height * ratio)
  const height = width / ratio
  // 所有预渲染 item 都提前显示封面，当前播放器挂载前和切走后也有画面衔接。
  const coverBackground = getThumbHashUrl(slide.thumbHash)

  // 在浏览器绘制前创建播放器，避免首次进入时先显示空的黑色容器。
  useLayoutEffect(() => {
    if (!active || !containerRef.current) {
      return
    }
    const player = new Artplayer({
      container: containerRef.current,
      url: slide.src,
      poster: slide.poster,
      theme: "#ffffff",
      lang: locale === "zh" ? "zh-cn" : "en",
      autoplay: false,
      playsInline: true,
      fullscreen: true,
      pip: true,
      setting: true,
      playbackRate: true,
      hotkey: false,
      moreVideoAttr: {
        controls: false,
        preload: "metadata",
      },
    })

    playerRef.current = player

    // 读取元数据时保持封面和控件可见，不显示尚未播放时的加载动画。
    function showIdleControls() {
      if (player.video.paused) {
        player.loading.show = false
        player.controls.show = true
        player.mask.show = true
      }
    }

    // 首帧尚未就绪时继续显示封面，避免点击播放后短暂露出黑色画面。
    function keepPoster() {
      if (player.video.readyState < HTMLMediaElement.HAVE_CURRENT_DATA) {
        player.template.$poster.style.display = ""
      }
    }

    // 视频实际开始播放后再移除封面。
    function hidePoster() {
      player.template.$poster.style.display = "none"
    }

    // 清除播放和暂停时在左上角显示的状态提示。
    function hidePlaybackNotice() {
      player.notice.show = ""
    }

    player.on("video:loadstart", showIdleControls)
    player.on("video:play", keepPoster)
    player.on("video:playing", hidePoster)
    player.on("play", hidePlaybackNotice)
    player.on("pause", hidePlaybackNotice)
    // 隐藏中央播放按钮，播放操作保留在底部控制栏。
    player.template.$state.style.display = "none"
    showIdleControls()

    // 切换或关闭时销毁播放器，停止声音和视频下载。
    return () => {
      playerRef.current = null
      player.destroy()
    }
  }, [active, slide.src, slide.poster, locale])

  // 视频画面允许拖动切换，播放器控件和全屏操作仍由播放器处理。
  function handlePointerDown(event: React.PointerEvent<HTMLDivElement>) {
    const target = event.target as Element
    pointerRef.current = null
    if (playerRef.current?.fullscreen || (target.closest(".art-video-player") && !target.closest(".art-video"))) {
      event.stopPropagation()
      return
    }

    pointerRef.current = { x: event.clientX, y: event.clientY, dragged: false }
  }

  // 区分单击与拖动，不影响图库自身的滑动跟手逻辑。
  function handlePointerMove(event: React.PointerEvent<HTMLDivElement>) {
    const pointer = pointerRef.current
    if (pointer && (Math.abs(event.clientX - pointer.x) > 10 || Math.abs(event.clientY - pointer.y) > 10)) {
      pointer.dragged = true
    }
  }

  // 在播放器收到点击前拦截拖动产生的点击，防止误播放或暂停。
  function handleClickCapture(event: React.MouseEvent<HTMLDivElement>) {
    if (pointerRef.current?.dragged) {
      event.preventDefault()
      event.stopPropagation()
    }
    pointerRef.current = null
  }

  // 保留 Esc 关闭查看器，播放器全屏时则先交给浏览器退出全屏。
  function handleKeyDown(event: React.KeyboardEvent<HTMLDivElement>) {
    if (event.key !== "Escape" || playerRef.current?.fullscreen) {
      event.stopPropagation()
    }
  }

  return (
    <div
      className="photo-video relative shrink-0 overflow-hidden bg-black bg-contain bg-center bg-no-repeat"
      style={{ width, height, backgroundImage: coverBackground ? `url("${coverBackground}")` : undefined }}
      onPointerDown={handlePointerDown}
      onPointerMove={handlePointerMove}
      onClickCapture={handleClickCapture}
      onKeyDown={handleKeyDown}
    >
      {slide.poster && (
        <img
          src={slide.poster}
          alt={slide.alt}
          draggable={false}
          className="pointer-events-none absolute inset-0 h-full w-full select-none object-contain"
        />
      )}
      <div ref={containerRef} className="absolute inset-0" />
    </div>
  )
}
