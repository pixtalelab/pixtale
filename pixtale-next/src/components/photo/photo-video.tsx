"use client"

import Artplayer from "artplayer"
import { useLocale, useTranslations } from "next-intl"
import { useLayoutEffect, useRef } from "react"
import type { ContainerRect, GenericSlide } from "yet-another-react-lightbox"

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

// 进入视频详情时展示播放器和封面，并在切换和关闭时释放播放资源。
export default function PhotoVideo({ slide, rect, active }: {
  slide: VideoSlide
  rect: ContainerRect
  active: boolean
}) {
  const locale = useLocale()
  const t = useTranslations("photos.viewer")
  // containerRef 是 ArtPlayer 管理的 DOM 容器。
  const containerRef = useRef<HTMLDivElement>(null)
  // playerRef 保存当前播放器实例，用于判断全屏状态。
  const playerRef = useRef<Artplayer | null>(null)
  // 根据视频比例和查看器可用空间固定播放器尺寸，避免加载时布局跳动。
  const ratio = slide.width && slide.height ? slide.width / slide.height : 16 / 9
  const width = Math.min(rect.width, rect.height * ratio)
  const height = width / ratio

  // 在浏览器绘制前创建播放器，避免首次进入时先显示空的黑色容器。
  useLayoutEffect(() => {
    if (!active || !containerRef.current) {
      return
    }
    const player = new Artplayer({
      container: containerRef.current,
      url: slide.src,
      poster: slide.poster,
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

    // 为播放器自带的中央播放按钮补充键盘操作。
    function handlePlayKey(event: Event) {
      const keyEvent = event as KeyboardEvent
      if (keyEvent.key === "Enter" || keyEvent.key === " ") {
        keyEvent.preventDefault()
        void player.play().catch((error: DOMException) => {
          if (!player.isDestroy && error.name !== "AbortError") {
            player.notice.show = t("playFailed")
          }
        })
      }
    }

    player.on("video:loadstart", showIdleControls)
    player.on("video:play", keepPoster)
    player.on("video:playing", hidePoster)
    player.template.$state.setAttribute("role", "button")
    player.template.$state.setAttribute("aria-label", t("play"))
    player.template.$state.tabIndex = 0
    player.proxy(player.template.$state, "keydown", handlePlayKey)
    showIdleControls()

    // 切换或关闭时销毁播放器，停止声音和视频下载。
    return () => {
      playerRef.current = null
      player.destroy()
    }
  }, [active, slide.src, slide.poster, locale, t])

  // 播放器内的拖动和点击由播放器处理，避免进度条触发图库切换。
  function handlePointerDown(event: React.PointerEvent<HTMLDivElement>) {
    event.stopPropagation()
  }

  // 保留 Esc 关闭查看器，播放器全屏时则先交给浏览器退出全屏。
  function handleKeyDown(event: React.KeyboardEvent<HTMLDivElement>) {
    if (event.key !== "Escape" || playerRef.current?.fullscreen) {
      event.stopPropagation()
    }
  }

  return (
    <div
      className="photo-video relative shrink-0 overflow-hidden bg-black"
      style={{ width, height }}
      onPointerDown={handlePointerDown}
      onKeyDown={handleKeyDown}
    >
      <div ref={containerRef} className="absolute inset-0" />
    </div>
  )
}
