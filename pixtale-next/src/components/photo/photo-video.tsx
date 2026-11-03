"use client"

import { useEffect, useLayoutEffect, useRef, useState } from "react"
import { useLocale } from "next-intl"
import { Play } from "lucide-react"
import { PlayButton } from "@videojs/react"
import { I18nProvider } from "@videojs/react/i18n"
import "@videojs/react/i18n/locales/zh/register"
import { Video, VideoPlayer, VideoSkin } from "@videojs/react/video"
import { useController, useLightboxState, type ContainerRect, type GenericSlide } from "yet-another-react-lightbox"

// 占位播放按钮和播放器内的播放按钮保持一致。
const startButtonClassName = "photo-video-start absolute left-1/2 top-1/2 z-10 flex h-16 w-16 -translate-x-1/2 -translate-y-1/2 items-center justify-center rounded-full bg-black/40 text-white backdrop-blur-sm hover:bg-black/55 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-white"

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

// 当前项在切换动画结束后创建播放器，相邻项保留封面以衔接图库滑动。
export default function PhotoVideo({ slide, rect, active }: {
  slide: VideoSlide
  rect: ContainerRect
  active: boolean
}) {
  const locale = useLocale()
  // 读取图库动画状态和实际轮播容器，用于判断画面是否已经停止移动。
  const { animation } = useLightboxState()
  const { containerRef } = useController()
  // prepared 表示当前视频是否已完成动画等待，可以初始化播放器。
  const [prepared, setPrepared] = useState(false)
  // videoRef 保存原生视频，切走和关闭详情时停止播放及下载。
  const videoRef = useRef<HTMLVideoElement>(null)
  // 有效导航动画等待结束，回弹动画不触发播放器重建。
  const changing = Boolean(animation?.increment && animation.duration)
  const ready = active && !changing && prepared
  // 按视频比例铺满查看器的一个维度，不额外添加边距。
  const ratio = slide.width && slide.height ? slide.width / slide.height : 16 / 9
  const width = Math.min(rect.width, rect.height * ratio)
  const height = width / ratio

  // 图库状态计时器可能提前结束，等待浏览器实际动画结束再挂载。
  useEffect(() => {
    let cancelled = false
    const canPrepare = active && !changing
    const animations = canPrepare
      ? containerRef.current?.querySelector(".yarl__carousel")?.getAnimations() ?? []
      : []

    Promise.allSettled(animations.map(item => item.finished)).then(() => {
      if (!cancelled) setPrepared(canPrepare)
    })

    return () => {
      cancelled = true
    }
  }, [active, changing, animation, slide.src, containerRef])

  // React 管理播放器挂载，清理时释放原生视频的资源。
  useLayoutEffect(() => {
    const video = videoRef.current

    return () => {
      if (video) {
        video.pause()
        // 提交结束后仅清理已移除的节点，兼容开发模式重复挂载 effect。
        queueMicrotask(() => {
          if (!video.isConnected) {
            video.removeAttribute("src")
            video.load()
          }
        })
      }
    }
  }, [ready, slide.src])

  // 画面允许图库拖动；控件和播放器全屏时的操作交给 Video.js。
  function handlePointerDown(event: React.PointerEvent<HTMLDivElement>) {
    const target = event.target as Element
    const control = target.closest("[data-interactive], button, input, [role='slider'], [role='menu'], [role='dialog']")
    if (
      (document.fullscreenElement && event.currentTarget.contains(document.fullscreenElement)) ||
      (control && event.currentTarget.contains(control))
    ) {
      event.stopPropagation()
    }
  }

  // 播放器内的按键交给控件处理，Esc 在非全屏时仍可关闭详情。
  function handleKeyDown(event: React.KeyboardEvent<HTMLDivElement>) {
    if (
      event.key !== "Escape" ||
      (document.fullscreenElement && event.currentTarget.contains(document.fullscreenElement))
    ) {
      event.stopPropagation()
    }
  }

  return (
    <div
      className="photo-video relative shrink-0 overflow-hidden"
      style={{ width, height }}
      onPointerDown={handlePointerDown}
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
      {!ready && (
        <span className={`${startButtonClassName} pointer-events-none`} aria-hidden="true">
          <Play className="ml-1 h-8 w-8" fill="currentColor" aria-hidden="true" />
        </span>
      )}
      {ready && (
        <I18nProvider locale={locale === "zh" ? "zh" : "en"}>
          <VideoPlayer poster={slide.poster}>
            <VideoSkin className="absolute inset-0 h-full w-full">
              <Video
                ref={videoRef}
                src={slide.src}
                poster={slide.poster}
                preload="metadata"
                playsInline
                aria-label={slide.alt}
              />
              <PlayButton
                className={startButtonClassName}
              >
                <Play className="ml-1 h-8 w-8" fill="currentColor" aria-hidden="true" />
              </PlayButton>
            </VideoSkin>
          </VideoPlayer>
        </I18nProvider>
      )}
    </div>
  )
}
