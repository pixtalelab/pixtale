"use client"

import { useEffect, useLayoutEffect, useRef, useState } from "react"
import { useLocale } from "next-intl"
import { LoaderCircle, Play } from "lucide-react"
import { BufferingIndicator, PlayButton } from "@videojs/react"
import { I18nProvider } from "@videojs/react/i18n"
import "@videojs/react/i18n/locales/zh/register"
import { Video, VideoPlayer, VideoSkin } from "@videojs/react/video"
import { useController, useLightboxState, type ContainerRect, type GenericSlide } from "yet-another-react-lightbox"

export type VideoSlide = GenericSlide & {
  type: "video"
  photoId: string
  src: string
  // poster 先用缩图，列表里通常已经缓存过。
  poster: string
  // preview 是高清封面，加载完成后再盖到缩图上面。
  preview: string
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

// 当前项在切换动画结束后创建播放器，切走时等动画结束再销毁。
export default function PhotoVideo({ slide, rect, active, previewCover }: {
  slide: VideoSlide
  rect: ContainerRect
  active: boolean
  // previewCover 是已经加载完成的高清封面，未完成时只显示缩图。
  previewCover?: string
}) {
  const locale = useLocale()
  // 读取图库动画状态和实际轮播容器，用于判断画面是否已经停止移动。
  const { animation } = useLightboxState()
  const { containerRef } = useController()
  // prepared 为 true 时挂载播放器，切走后仍保持到动画结束。
  const [prepared, setPrepared] = useState(false)
  // videoRef 保存原生视频，切走和关闭详情时停止播放及下载。
  const videoRef = useRef<HTMLVideoElement>(null)
  // 有效导航动画等待结束，回弹动画不触发播放器重建。
  const changing = Boolean(animation?.increment && animation.duration)
  // activeRef / changingRef 给延迟触发的 play 读取当前切页状态。
  const activeRef = useRef(active)
  const changingRef = useRef(changing)
  activeRef.current = active
  changingRef.current = changing
  // poster 优先用高清封面，未加载完时沿用缩图。
  const poster = previewCover || slide.poster
  // 按视频比例铺满查看器的一个维度，不额外添加边距。
  const ratio = slide.width && slide.height ? slide.width / slide.height : 16 / 9
  const width = Math.min(rect.width, rect.height * ratio)
  const height = width / ratio

  // 图库状态计时器可能提前结束，挂载和销毁都等到轮播动画真正结束。
  useEffect(() => {
    let cancelled = false
    let frame = 0
    const wantPlayer = active && !changing
    const animations = containerRef.current?.querySelector(".yarl__carousel")?.getAnimations() ?? []

    // 切换已开始但浏览器动画还没挂上时，先保持当前播放器。
    if (changing && animations.length === 0) {
      return () => {
        cancelled = true
      }
    }

    Promise.allSettled(animations.map(item => item.finished)).then(() => {
      if (cancelled) {
        return
      }

      // 等下一帧再实例化或销毁，避免和动画最后一帧抢主线程。
      frame = requestAnimationFrame(() => {
        if (!cancelled) setPrepared(wantPlayer)
      })
    })

    return () => {
      cancelled = true
      cancelAnimationFrame(frame)
    }
  }, [active, changing, animation, slide.src, containerRef])

  // React 管理播放器挂载，清理时释放原生视频的资源。
  useLayoutEffect(() => {
    const video = videoRef.current
    if (!video) {
      return
    }

    const play = video.play.bind(video)
    // 拖动松手会被播放器当成点击，切页过程中不允许开始播放。
    video.play = () => {
      if (!activeRef.current || changingRef.current) {
        return Promise.resolve()
      }
      return play()
    }

    if (!active || changing) {
      video.pause()
    }

    return () => {
      video.play = play
      video.pause()
      // 提交结束后仅清理已移除的节点，兼容开发模式重复挂载 effect。
      queueMicrotask(() => {
        if (!video.isConnected) {
          video.removeAttribute("src")
          video.load()
        }
      })
    }
  }, [prepared, slide.src, active, changing])

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
          alt=""
          draggable={false}
          className="photo-video-cover pointer-events-none absolute inset-0 z-[1] h-full w-full select-none object-contain"
          aria-hidden
        />
      )}
      {previewCover && previewCover !== slide.poster && (
        <img
          src={previewCover}
          alt={slide.alt}
          draggable={false}
          className="photo-video-cover pointer-events-none absolute inset-0 z-[1] h-full w-full select-none object-contain"
        />
      )}
      <span className="photo-video-cover-play photo-video-start pointer-events-none absolute left-1/2 top-1/2 z-10 flex h-20 w-20 -translate-x-1/2 -translate-y-1/2 items-center justify-center bg-transparent text-white" aria-hidden="true">
        <Play className="ml-1.5 h-10 md:h-12 w-10 md:w-12 drop-shadow-md" fill="currentColor" aria-hidden="true" />
      </span>
      {prepared && (
        <I18nProvider locale={locale === "zh" ? "zh" : "en"}>
          <VideoPlayer poster={poster}>
            <VideoSkin className="absolute inset-0 h-full w-full">
              <Video
                ref={videoRef}
                src={slide.src}
                poster={poster}
                preload="metadata"
                playsInline
                aria-label={slide.alt}
              />
              <PlayButton className="photo-video-start absolute left-1/2 top-1/2 z-10 flex h-20 w-20 -translate-x-1/2 -translate-y-1/2 items-center justify-center bg-transparent text-white focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-white">
                <Play className="ml-1.5 h-10 md:h-12 w-10 md:w-12 drop-shadow-md" fill="currentColor" aria-hidden="true" />
              </PlayButton>
              <BufferingIndicator className="photo-video-buffering pointer-events-none absolute inset-0 z-30 hidden items-center justify-center data-[visible]:flex">
                <LoaderCircle className="h-6 w-6 md:h-8 md:w-8 animate-spin text-white drop-shadow-md" aria-hidden="true" />
              </BufferingIndicator>
            </VideoSkin>
          </VideoPlayer>
        </I18nProvider>
      )}
    </div>
  )
}
