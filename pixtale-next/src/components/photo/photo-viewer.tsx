"use client"

import { type CSSProperties, useEffect, useLayoutEffect, useMemo, useRef, useState } from "react"
import Lightbox from "yet-another-react-lightbox"
import { isImageSlide, type SlideImage, useController, useLightboxState } from "yet-another-react-lightbox"
import Fullscreen from "yet-another-react-lightbox/plugins/fullscreen"
import Thumbnails from "yet-another-react-lightbox/plugins/thumbnails"
import Zoom from "yet-another-react-lightbox/plugins/zoom"
import { ArrowLeftIcon, ChevronLeftIcon, ChevronRightIcon, CircleAlertIcon, CircleIcon, Menu, LoaderCircleIcon, MaximizeIcon, PanelRightClose, PanelRightOpen, RotateCcwSquare } from "lucide-react"

import { PhotoInfoSidebar, PhotoViewerBlurBackground } from "@/components/photo/photo-info-sidebar"
import { useTapAction } from "@/hooks/use-tap-action"
import { Button } from "@/components/ui/button"
import { getThumbHashUrl } from "@/lib/thumb-hash"
import { type PhotoVo } from "@/server/entity/vo/photo"
import { usePhotoStore } from "@/store/photo-store"
import { useTranslations } from "next-intl"

interface PhotoViewerProps {
  // 控制查看器是否显示。
  open: boolean
  // 当前打开的照片索引。
  index: number
  // 父组件传入的照片列表。
  photos: PhotoVo[]
  // 关闭查看器时执行。
  onBack: () => void
  // 浏览器返回关闭查看器时执行。
  onBrowserBack: () => void
}

type PhotoSlide = SlideImage & {
  // 当前照片 id。
  photoId: string
  // 当前照片原图。
  key: string
  // 当前照片原图大小。
  originalSize: number
  // 当前照片预览图。
  preview: string
  // 缩图地址。
  thumbnail: string
  // thumbHash 转换后的模糊色背景。
  thumbHash: string
}

type FullscreenButtonProps = {
  // 当前是否处于全屏状态。
  fullscreen: boolean
  // 进入全屏。
  enter: () => void
}

type OriginalPhoto = {
  // 当前已经加载完成的原图 key。
  key: string
}

type OriginalProgress = {
  // 当前已加载字节数。
  loaded: number
  // 当前原图总字节数。
  total: number
}

type PreviewRequestMap = Map<string, () => void>

type LoadOriginalImageParams = {
  // 当前照片 id。
  photoId: string
  // 原图请求地址。
  src: string
  // 原图文件大小，用于没有返回 total 时兜底显示进度。
  totalSize: number
  // 保存已经加载完成的原图。
  setOriginalPhoto: (photo: OriginalPhoto | null) => void
  // 保存原图加载进度。
  setOriginalProgress: (progress: OriginalProgress | null) => void
  // 控制原图加载进度是否显示。
  setShowOriginalProgress: (show: boolean) => void
  // 保存当前原图加载是否异常。
  setOriginalError: (error: boolean) => void
  // 保存当前原图请求的取消方法。
  abortOriginalRef: { current: (() => void) | null }
  // 原图加载进度延迟隐藏定时器。
  hideTimerRef: { current: ReturnType<typeof setTimeout> | null }
  // 保存已经完成加载的照片缓存。
  setPhotoCache: (photoId: string, src: string) => void
}

const photoViewerPortalStyle: CSSProperties & { "--yarl__portal_zindex": number } = {
  "--yarl__portal_zindex": 40,
}

// 根据操作按钮显示状态生成淡入淡出样式。
function getActionVisibleClass(showActions: boolean) {
  return showActions ? "opacity-100" : "pointer-events-none opacity-0"
}

// 把字节数格式化成 MB。
function formatMB(size: number) {
  return `${(size / 1024 / 1024).toFixed(1)}MB`
}

// 关闭所有预览图请求，并清空当前请求 Map。
function closePreviewRequests(requests: PreviewRequestMap) {
  const aborts = Array.from(requests.values())

  requests.clear()
  aborts.forEach((abort) => {
    abort()
  })
}

// 加载原图并直接更新查看器原图相关状态。
function loadOriginalImage({
  photoId,
  src,
  totalSize,
  setOriginalPhoto,
  setOriginalProgress,
  setShowOriginalProgress,
  setOriginalError,
  abortOriginalRef,
  hideTimerRef,
  setPhotoCache,
}: LoadOriginalImageParams) {

  const xhr = new XMLHttpRequest()
  const abortOriginal = () => {
    xhr.abort()
  }

  // 请求结束后清理当前请求引用，避免后续切换误取消已完成请求。
  function clearCurrentRequest() {
    if (abortOriginalRef.current === abortOriginal) {
      abortOriginalRef.current = null
    }
  }

  if (hideTimerRef.current) {
    clearTimeout(hideTimerRef.current)
    hideTimerRef.current = null
  }
  setShowOriginalProgress(true)
  setOriginalError(false)
  setOriginalProgress({
    loaded: 0,
    total: totalSize,
  })

  xhr.open("GET", src)
  xhr.responseType = "arraybuffer"
  xhr.onprogress = (event) => {
    setOriginalProgress({
      loaded: event.loaded,
      total: event.lengthComputable ? event.total : totalSize,
    })
  }
  xhr.onload = () => {
    if (xhr.status >= 200 && xhr.status < 300) {
      setOriginalProgress({
        loaded: xhr.response.byteLength,
        total: xhr.response.byteLength,
      })
      setPhotoCache(photoId, src)
      setOriginalPhoto({
        key: src,
      })

      hideTimerRef.current = setTimeout(() => {
        hideTimerRef.current = null
        setShowOriginalProgress(false)
      }, 800)
    } else {
      setOriginalError(true)
      setShowOriginalProgress(true)
    }
    clearCurrentRequest()
  }
  xhr.onerror = () => {
    setOriginalError(true)
    setShowOriginalProgress(true)
    clearCurrentRequest()
  }
  xhr.onabort = () => {
    clearCurrentRequest()
  }
  xhr.send()

  return abortOriginal
}

// 静默加载预览图，请求完成后替换当前显示图。
function loadPreviewImage(
  src: string,
  photoId: string,
  currentPhotoIdRef: { current: string | null },
  setOriginalPhoto: (photo: OriginalPhoto | null) => void,
  previewRequestsRef: { current: PreviewRequestMap },
  getPhotoCache: (photoId: string) => string | undefined,
  setPhotoCache: (photoId: string, src: string) => void,
  onLoaded?: () => void
) {
  const cachedSrc = getPhotoCache(photoId)

  if (cachedSrc) {
    requestAnimationFrame(() => {
      if (currentPhotoIdRef.current === photoId) {
        setOriginalPhoto({
          key: cachedSrc,
        })
        onLoaded?.()
      }
    })
    return
  }

  const xhr = new XMLHttpRequest()
  const abortPreview = () => {
    xhr.abort()
  }

  previewRequestsRef.current.set(photoId, abortPreview)

  // 请求结束后只清理自己的记录，避免旧请求删掉新请求。
  function clearCurrentRequest() {
    if (previewRequestsRef.current.get(photoId) === abortPreview) {
      previewRequestsRef.current.delete(photoId)
    }
  }

  xhr.open("GET", src)
  xhr.responseType = "arraybuffer"
  xhr.onload = () => {
    if (xhr.status >= 200 && xhr.status < 300) {
      setPhotoCache(photoId, src)

      if (currentPhotoIdRef.current === photoId) {
        setOriginalPhoto({
          key: src,
        })
        onLoaded?.()
      }
    }
    clearCurrentRequest()
  }
  xhr.onerror = () => {
    clearCurrentRequest()
  }
  xhr.onabort = () => {
    clearCurrentRequest()
  }
  xhr.send()
}

// 渲染原图加载进度。
function OriginalProgressButton({ progress, error }: { progress: OriginalProgress | null, error: boolean }) {
  const t = useTranslations("photos.viewer")
  if (!progress) {
    return null
  }

  const percent = Math.round((progress.loaded / progress.total) * 100)

  return (
    <Button
      type="button"
      variant="secondary"
      className={[
        "absolute right-3 md:right-4 bottom-3 md:bottom-4  z-[450] h-auto gap-3 rounded-xl bg-black/80 px-3 py-2 text-white transition-opacity duration-200 hover:bg-black/80"
      ].join(" ")}
    >
      {error ? (
        <CircleAlertIcon className="size-4 text-red-500" />
      ) : (
        <LoaderCircleIcon className="size-4 animate-spin text-white" />
      )}
      <span className="flex flex-col items-start leading-none">
        <span className={["text-xs font-medium", error ? "text-red-500" : "text-white"].join(" ")}>
          <span className="text-xs mr-[1px]"> {error ? t("loadFailed") : t("loading")} </span>
          {!error && <span className="text-white/70"> {percent}%</span>}
        </span>
        <span className="text-xs text-white/70">
          {formatMB(progress.loaded)} / {formatMB(progress.total)}
        </span>
      </span>
    </Button>
  )
}

// 渲染上一张按钮。
function PrevButton({ showActions }: { showActions: boolean }) {
  const { prev } = useController()

  return (
    <Button
      type="button"
      size="icon"
      variant="secondary"
      className={[
        "absolute top-1/2 left-3 z-40 hidden rounded-full bg-black/40 text-white transition-opacity duration-200 hover:bg-black/50 md:inline-flex",
        getActionVisibleClass(showActions),
      ].join(" ")}
      style={{ transform: "translateY(-50%)" }}
      onClick={() => prev()}
    >
      <ChevronLeftIcon />
      <span className="sr-only">Previous photo</span>
    </Button>
  )
}

// 渲染下一张按钮。
function NextButton({ showActions }: { showActions: boolean }) {
  const { next } = useController()

  return (
    <Button
      type="button"
      size="icon"
      variant="secondary"
      className={[
        "absolute top-1/2 right-3 z-40 hidden rounded-full bg-black/40 text-white transition-opacity duration-200 hover:bg-black/50 md:inline-flex",
        getActionVisibleClass(showActions),
      ].join(" ")}
      style={{ transform: "translateY(-50%)" }}
      onClick={() => next()}
    >
      <ChevronRightIcon />
      <span className="sr-only">Next photo</span>
    </Button>
  )
}

// 渲染全屏按钮。
function FullscreenButton({
  fullscreen,
  enter,
  showActions,
  onHideActions,
}: FullscreenButtonProps & {
  showActions: boolean
  onHideActions: () => void
}) {
  if (fullscreen) {
    return null
  }

  // 进入全屏状态后隐藏查看器操作按钮。
  function openFullscreen() {
    enter()
    onHideActions()
  }

  const tap = useTapAction(openFullscreen)

  return (
    <Button
      type="button"
      size="icon"
      variant="secondary"
      className={[
        "absolute top-2 right-2 md:top-3 md:right-3 z-40 rounded-full bg-black/40 text-white transition-opacity duration-200 hover:bg-black/50",
        getActionVisibleClass(showActions),
      ].join(" ")}
      {...tap}
    >
      <MaximizeIcon />
      <span className="sr-only">Enter fullscreen</span>
    </Button>
  )
}

// 渲染照片信息按钮，点击切换右侧信息侧栏。
function InfoButton({
  showActions,
  open,
  onToggle,
}: {
  showActions: boolean
  open: boolean
  onToggle: () => void
}) {
  const tap = useTapAction(onToggle)

  return (
    <Button
      type="button"
      size="icon"
      variant="secondary"
      className={[
        "absolute top-2 right-2 md:top-3 md:right-3 z-40 rounded-full text-white transition-opacity duration-200",
        open ? "bg-black/50 hover:bg-black/50" : "bg-black/40 hover:bg-black/50",
        getActionVisibleClass(showActions),
      ].join(" ")}
      {...tap}
    >
      <Menu className="md:hidden" />
      {open
        ? <PanelRightClose className="hidden md:block" />
        : <PanelRightOpen className="hidden md:block" />}
      <span className="sr-only">Photo information</span>
    </Button>
  )
}

// 渲染旋转按钮。
function RotateButton({ showActions, onRotate }: { showActions: boolean, onRotate: (photoId: string) => void }) {
  const { currentSlide } = useLightboxState()
  const photoSlide = currentSlide && isImageSlide(currentSlide) ? currentSlide as PhotoSlide : null

  // 把当前照片 id 交给父组件更新旋转角度。
  function rotatePhoto() {
    if (!photoSlide) {
      return
    }

    onRotate(photoSlide.photoId)
  }

  const tap = useTapAction(rotatePhoto)

  return (
    <Button
      type="button"
      size="icon"
      variant="secondary"
      className={[
        "absolute top-2 right-11.5 md:right-13 md:top-3 z-40 rounded-full bg-black/40 text-white transition-opacity duration-200 hover:bg-black/50",
        getActionVisibleClass(showActions),
      ].join(" ")}
      {...tap}
    >
      <RotateCcwSquare />
      <span className="sr-only">Rotate photo</span>
    </Button>
  )
}

// 渲染原图加载按钮。
function LoadOriginalButton({
  showActions,
  originalPhoto,
  getPhotoCache,
  onLoadOriginal,
}: {
  showActions: boolean
  originalPhoto: OriginalPhoto | null
  getPhotoCache: (photoId: string) => string | undefined
  onLoadOriginal: (slide: PhotoSlide) => void
}) {
  const { currentSlide } = useLightboxState()
  const photoSlide = currentSlide && isImageSlide(currentSlide) ? currentSlide as PhotoSlide : null
  const cacheSrc = photoSlide ? getPhotoCache(photoSlide.photoId) : undefined
  const originalLoaded = Boolean(photoSlide && (originalPhoto?.key === photoSlide.key || cacheSrc?.includes("photo/")))

  // 把当前 slide 交给父组件加载原图。
  function loadOriginal() {

    //图片不存在，或已经加载完成就终止
    if (!photoSlide || originalLoaded) {
      return
    }

    onLoadOriginal(photoSlide)
  }

  const tap = useTapAction(loadOriginal)

  return (
    <Button
      type="button"
      size="icon"
      variant="secondary"
      className={[
        "absolute top-2 right-21 md:right-23.25 md:top-3 z-40 rounded-full bg-black/40 text-white transition-opacity duration-200 hover:bg-black/50",
        getActionVisibleClass(showActions),
      ].join(" ")}
      {...tap}
    >
      {originalLoaded ? <CircleIcon /> : <LoaderCircleIcon />}
      <span className="sr-only">Load original photo</span>
    </Button>
  )
}

// 渲染关闭按钮。
function CloseButton({ showActions }: { showActions: boolean }) {
  const { close } = useController()
  const tap = useTapAction(() => close())

  return (
    <Button
      type="button"
      size="icon"
      variant="secondary"
      className={[
        "absolute top-2 left-2 md:top-3 md:left-3 z-40 rounded-full bg-black/40 text-white transition-opacity duration-200 hover:bg-black/50",
        getActionVisibleClass(showActions),
      ].join(" ")}
      {...tap}
    >
      <ArrowLeftIcon />
      <span className="sr-only">Back</span>
    </Button>
  )
}

// 渲染单张照片，通过原图 key ref 判断显示封面还是原图。
function PhotoSlideImage({
  slide,
  originalPhoto,
  rotate,
  fullscreenOpen,
}: {
  // 当前照片 slide。
  slide: PhotoSlide
  // 当前已加载完成的原图。
  originalPhoto: OriginalPhoto | null
  // 当前照片 CSS 旋转角度。
  rotate: number
  // 当前是否处于全屏状态。
  fullscreenOpen: boolean
}) {
  const normalizedRotate = rotate % 360
  const sideways = normalizedRotate === 90 || normalizedRotate === 270
  const thumbnailHeight = innerWidth < 768 ? 46 : 75
  const rotateWidthOffset = fullscreenOpen ? 0 : thumbnailHeight

  return (
    <img
      src={originalPhoto?.key === slide.preview || originalPhoto?.key === slide.key ? originalPhoto.key : slide.src}
      alt={slide.alt}
      draggable={false}
      crossOrigin="anonymous"
      className="select-none max-w-none object-contain transition-transform duration-200"
      onError={(event) => {
        event.currentTarget.style.display = "none"
      }}
      style={{
        width: sideways ? `calc(100cqh - ${rotateWidthOffset}px)` : "100%",
        height: sideways ? "100vw" : "100%",
        transform: `rotate(${rotate}deg)`,
      }}
    />
  )
}

// 渲染照片详情查看器，父组件负责传入当前照片和列表数据。
export function PhotoViewer({ open, index, photos, onBack, onBrowserBack }: PhotoViewerProps) {
  // 当前 lightbox 查看的照片索引。
  const [viewIndex, setViewIndex] = useState(index)
  // infoOpen 控制右侧照片信息侧栏是否展开。
  const infoOpen = usePhotoStore((state) => state.infoOpen)
  // setInfoOpen 更新信息侧栏展开状态。
  const setInfoOpen = usePhotoStore((state) => state.setInfoOpen)
  // toggleInfoOpen 切换信息侧栏展开状态。
  const toggleInfoOpen = usePhotoStore((state) => state.toggleInfoOpen)
  // 当前已经加载完成的原图。
  const [originalPhoto, setOriginalPhoto] = useState<OriginalPhoto | null>(null)
  // 当前原图加载进度。
  const [originalProgress, setOriginalProgress] = useState<OriginalProgress | null>(null)
  // showOriginalProgress 控制原图加载进度是否显示。
  const [showOriginalProgress, setShowOriginalProgress] = useState(false)
  // originalError 记录当前原图加载是否异常。
  const [originalError, setOriginalError] = useState(false)
  // 当前是否显示查看器操作按钮，单击图片区域可切换，放大时仍强制隐藏。
  const [showActions, setShowActions] = useState(true)
  // 当前照片缩放倍数。
  const [zoomLevel, setZoomLevel] = useState(1)
  // 当前是否处于全屏状态。
  const [fullscreenOpen, setFullscreenOpen] = useState(false)
  // 每张照片当前的旋转角度。
  const [photoRotates, setPhotoRotates] = useState<Record<string, number>>({})
  // getPhotoCache 从全局照片缓存中读取已加载的照片。
  const getPhotoCache = usePhotoStore((state) => state.getPhotoCache)
  // setPhotoCache 把已经加载完成的照片写入全局照片缓存。
  const setPhotoCache = usePhotoStore((state) => state.setPhotoCache)
  // 当前原图请求的取消方法。
  const abortOriginalRef = useRef<(() => void) | null>(null)
  // previewRequestsRef 保存正在请求的预览图 id 和取消方法。
  const previewRequestsRef = useRef<PreviewRequestMap>(new Map())
  // currentPhotoIdRef 保存当前查看的照片 id，用于静默预览图请求防乱序。
  const currentPhotoIdRef = useRef<string | null>(photos[index]?.photoId ?? null)
  // openScrollYRef 保存打开查看器前的页面滚动位置，关闭后还原照片列表。
  const openScrollYRef = useRef(typeof window === "undefined" ? 0 : window.scrollY)
  // historyPushedRef 记录查看器是否已经写入浏览器历史。
  const historyPushedRef = useRef(false)
  // onBrowserBackRef 保存最新的浏览器返回回调。
  const onBrowserBackRef = useRef(onBrowserBack)
  // originalProgressHideTimerRef 保存延迟隐藏原图加载进度的定时器。
  const originalProgressHideTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  // slidePointerStartRef 记录 slide 上 pointerdown 坐标，用于区分点击与拖动切换。
  const slidePointerStartRef = useRef<{ x: number; y: number } | null>(null)

  // lightbox 需要的图片列表。
  const slides = useMemo<PhotoSlide[]>(() => (
    photos.map((photo) => ({
      photoId: photo.photoId,
      key: photo.key,
      originalSize: photo.size,
      preview: photo.preview || "",
      src: photo.thumbnail || photo.preview || "",
      thumbnail: photo.thumbnail || photo.preview || "",
      thumbHash: photo.thumbHash ?? "",
      width: photo.width ?? undefined,
      height: photo.height ?? undefined,
      alt: photo.name,
    }))
  ), [photos])
  const actionsVisible = showActions && zoomLevel <= 1

  useEffect(() => {
    // 保持浏览器返回回调为父组件传入的最新方法。
    onBrowserBackRef.current = onBrowserBack
  }, [onBrowserBack])

  useLayoutEffect(() => {
    if (!open) {
      return
    }

    openScrollYRef.current = window.scrollY

    // 打开查看器时压入一条历史，浏览器返回时先关闭查看器而不是离开页面。
    function handlePopState() {

      if (innerWidth < 768) {
        setInfoOpen(false)
      }

      if (!historyPushedRef.current) {
        return
      }

      historyPushedRef.current = false
      onBrowserBackRef.current()
    }

    window.history.pushState(
      {
        ...window.history.state,
        photoViewerOpen: true,
      },
      "",
      window.location.href,
    )
    historyPushedRef.current = true
    window.addEventListener("popstate", handlePopState)

    return () => {
      window.removeEventListener("popstate", handlePopState)
    }
  }, [open, setInfoOpen])

  useEffect(() => {
    if (!open) {
      return
    }

    // 关闭查看器时中断未完成的原图请求，并把列表滚动位置还原到打开前。
    return () => {
      if (originalProgressHideTimerRef.current) {
        clearTimeout(originalProgressHideTimerRef.current)
      }
      abortOriginalRef.current?.()
      closePreviewRequests(previewRequestsRef.current)
      requestAnimationFrame(restoreListScroll)
    }
  }, [open])

  // 处理照片切换后的原图加载。
  function handleView(nextIndex: number) {
    setViewIndex(nextIndex)

    const photo = photos[nextIndex]
    const preview = photo.preview
    currentPhotoIdRef.current = photo.photoId

    if (originalProgressHideTimerRef.current) {
      clearTimeout(originalProgressHideTimerRef.current)
      originalProgressHideTimerRef.current = null
    }
    abortOriginalRef.current?.()
    closePreviewRequests(previewRequestsRef.current)
    setOriginalProgress(null)
    setOriginalError(false)
    setShowOriginalProgress(false)

    if (!preview) {
      return
    }

    // 当前照片加载完成后，再静默预热前后两张。
    loadPreviewImage(preview, photo.photoId, currentPhotoIdRef, setOriginalPhoto, previewRequestsRef, getPhotoCache, setPhotoCache, () => {
      if (photos.length < 2) {
        return
      }

      const prevIndex = nextIndex > 0 ? nextIndex - 1 : photos.length - 1
      const nextPhotoIndex = nextIndex < photos.length - 1 ? nextIndex + 1 : 0
      const targets = new Map<string, PhotoVo>()

      if (photos[prevIndex]?.preview) {
        targets.set(photos[prevIndex].photoId, photos[prevIndex])
      }
      if (photos[nextPhotoIndex]?.preview) {
        targets.set(photos[nextPhotoIndex].photoId, photos[nextPhotoIndex])
      }

      targets.forEach((target) => {
        loadPreviewImage(target.preview!, target.photoId, currentPhotoIdRef, setOriginalPhoto, previewRequestsRef, getPhotoCache, setPhotoCache)
      })
    })
  }

  // 手动加载当前照片原图。
  function loadOriginalPhoto(slide: PhotoSlide) {
    if (!slide.key) {
      return
    }

    abortOriginalRef.current?.()
    abortOriginalRef.current = loadOriginalImage({
      photoId: slide.photoId,
      src: slide.key,
      totalSize: slide.originalSize,
      setOriginalPhoto,
      setOriginalProgress,
      setShowOriginalProgress,
      setOriginalError,
      abortOriginalRef,
      hideTimerRef: originalProgressHideTimerRef,
      setPhotoCache,
    })
  }

  // 隐藏查看器操作按钮。
  function hideActions() {
    setShowActions(false)
  }

  // 显示查看器操作按钮。
  function showActionButtons() {
    setShowActions(true)
  }

  // 记录 slide 上按下时的坐标。
  function handleSlidePointerDown(event: React.PointerEvent<HTMLDivElement>) {
    slidePointerStartRef.current = { x: event.clientX, y: event.clientY }
  }

  // 抬起时若位移很小则视为点击，切换操作按钮；拖动切换照片时不处理。
  function handleSlidePointerUp(event: React.PointerEvent<HTMLDivElement>) {
    if (zoomLevel > 1) {
      slidePointerStartRef.current = null
      return
    }

    const start = slidePointerStartRef.current
    slidePointerStartRef.current = null
    if (!start) {
      return
    }

    const dx = Math.abs(event.clientX - start.x)
    const dy = Math.abs(event.clientY - start.y)
    if (dx > 10 || dy > 10) {
      return
    }

    setShowActions((prev) => !prev)
  }

  // 取消 pointer 时清掉起始坐标。
  function handleSlidePointerCancel() {
    slidePointerStartRef.current = null
  }

  // 根据照片 id 把对应照片顺时针旋转 90 度。
  function rotatePhoto(photoId: string) {
    setPhotoRotates((prev) => ({
      ...prev,
      [photoId]: (prev[photoId] ?? 0) + 90,
    }))
  }

  // 把页面滚动位置恢复到打开查看器前，抵消 lightbox 关闭时的焦点滚动。
  function restoreListScroll() {
    window.scrollTo(0, openScrollYRef.current)
  }

  // 关闭查看器并同步清理查看器写入的浏览器历史。
  function closeViewer() {

    if (historyPushedRef.current) {
      window.history.back()
      return
    }

    onBack()
  }

  // 侧栏展开时收窄 lightbox 宽度，为右侧信息面板留出空间。
  const lightboxClassName = infoOpen && !fullscreenOpen ? "w-0 md:w-[calc(100%-(0.25rem*80))]" : "w-full"

  // 渲染 yet-another-react-lightbox 最简预览。
  return (
    <Lightbox
      className={lightboxClassName}
      open={open}
      close={() => {
        closeViewer()
        // 关闭时重置缩放
        setZoomLevel(1)
      }}
      index={index}
      slides={slides}
      portal={{
        container: {
          style: photoViewerPortalStyle,
        },
      }}
      plugins={fullscreenOpen ? [Fullscreen, Zoom] : [Thumbnails, Fullscreen, Zoom]}
      zoom={{
        scrollToZoom: true,
        wheelZoomDistanceFactor: 100,
        maxZoomPixelRatio: 1.2,
        doubleClickMaxStops: 2,
      }}
      toolbar={{
        buttons: [],
      }}
      carousel={{
        spacing: 0,
        preload: innerWidth < 768 ? 10 : 22,
      }}
      animation={{
        fade: 250,
        easing: {
          fade: "ease-out",
          navigation: "cubic-bezier(0.22, 1, 0.36, 1)",
        },
      }}
      thumbnails={{
        width: innerWidth < 768 ? 50 : 75,
        height: innerWidth < 768 ? 50 : 75,
        gap: 0,
        padding: 0,
        border: 0,
        borderRadius: 0,
        imageFit: "cover",
        vignette: false,
      }}
      on={{
        exiting: () => {
          restoreListScroll()
        },
        view: ({ index }) => {
          handleView(index)
        },
        zoom: ({ zoom }) => {
          setZoomLevel(zoom)
        },
        enterFullscreen: () => {
          setFullscreenOpen(true)
          hideActions()
        },
        exitFullscreen: () => {
          setFullscreenOpen(false)
          showActionButtons()
        },
      }}
      render={{
        buttonPrev: () => <PrevButton key="prev" showActions={actionsVisible} />,
        buttonNext: () => <NextButton key="next" showActions={actionsVisible} />,
        controls: () => (
          <>
            {infoOpen && !fullscreenOpen && (
              <PhotoViewerBlurBackground thumbHash={photos[viewIndex]?.thumbHash} />
            )}
            {infoOpen && !fullscreenOpen && (
              <PhotoInfoSidebar photo={photos[viewIndex] ?? null} onClose={() => setInfoOpen(false)} />
            )}
            <CloseButton showActions={actionsVisible} />
            <InfoButton
              showActions={actionsVisible}
              open={infoOpen}
              onToggle={toggleInfoOpen}
            />
            <RotateButton showActions={actionsVisible} onRotate={rotatePhoto} />
            <LoadOriginalButton
              showActions={actionsVisible}
              originalPhoto={originalPhoto}
              getPhotoCache={getPhotoCache}
              onLoadOriginal={loadOriginalPhoto}
            />
            {showOriginalProgress && (
              <OriginalProgressButton progress={originalProgress} error={originalError} />
            )}
          </>
        ),
        buttonFullscreen: () => null,
        buttonZoom: () => null,
        slide: ({ slide }) => {
          if (!isImageSlide(slide)) {
            return null
          }

          const photoSlide = slide as PhotoSlide

          return (
            <div
              className="relative flex h-full w-full items-center justify-center overflow-hidden"
              onPointerDown={handleSlidePointerDown}
              onPointerUp={handleSlidePointerUp}
              onPointerCancel={handleSlidePointerCancel}
            >
              <img
                src={getThumbHashUrl(photoSlide.thumbHash)}
                alt=""
                className="absolute inset-0 h-full w-full scale-110 blur-sm"
                aria-hidden
              />
              <PhotoSlideImage
                slide={photoSlide}
                originalPhoto={originalPhoto}
                rotate={photoRotates[photoSlide.photoId] ?? 0}
                fullscreenOpen={fullscreenOpen}
              />
            </div>
          )
        },
        thumbnail: ({ slide, rect }) => {
          if (!isImageSlide(slide)) {
            return null
          }

          const photoSlide = slide as PhotoSlide

          return (
            <div
              className="relative overflow-hidden thumbnail-bg"
              style={{
                width: rect.width,
                height: rect.height,
              }}
            >
              <img
                src={getThumbHashUrl(photoSlide.thumbHash)}
                alt=""
                className="absolute inset-0 h-full w-full scale-110 blur-sm object-cover"
                aria-hidden
              />
              <img
                src={photoSlide.thumbnail}
                alt={photoSlide.alt}
                width={photoSlide.width}
                height={photoSlide.height}
                draggable={false}
                className="h-full w-full select-none object-cover"
                crossOrigin="anonymous"
                onError={(event) => {
                  event.currentTarget.style.display = "none"
                }}
              />
            </div>
          )
        }
      }}
    />
  )
}
