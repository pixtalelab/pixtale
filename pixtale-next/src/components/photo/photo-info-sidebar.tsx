"use client"

import { XIcon } from "lucide-react"
import { OverlayScrollbars } from "overlayscrollbars"
import { useEffect, useRef, useState } from "react"

import { PhotoHistogram } from "@/components/photo/photo-histogram"
import { Button } from "@/components/ui/button"
import { useTapAction } from "@/hooks/use-tap-action"
import { formatPhotoTakenDateTime } from "@/lib/date"
import { getThumbHashUrl } from "@/lib/thumb-hash"
import { formatPhotoLocation, getPhotoCaptureParams, getPhotoColorSpace, getPhotoDeviceParams, getPhotoShootingParams, getPhotoSoftware, getPhotoTechnicalParams, getPhotoTimezone } from "@/lib/viewer-field"
import { type PhotoVo } from "@/server/entity/vo/photo"
import { useLocale, useTranslations } from "next-intl"

type PhotoInfoSidebarProps = {
  // 当前查看的照片。
  photo: PhotoVo | null
  // 侧栏是否打开。
  open: boolean
  // 关闭侧栏。
  onClose?: () => void
}

type PhotoViewerBlurBackgroundProps = {
  // 当前照片的 thumbHash。
  thumbHash?: string | null
}

// 格式化照片名称，去掉文件后缀。
function formatPhotoName(name: string) {
  const index = name.lastIndexOf(".")

  return index > 0 ? name.slice(0, index) : name
}

// 把字节数格式化成 MB。
function formatFileSize(size: number) {
  return `${(size / 1024 / 1024).toFixed(1)}MB`
}

// 格式化照片分辨率。
function formatResolution(width: number | null, height: number | null) {
  if (!width || !height) {
    return null
  }

  return `${width} × ${height}`
}

// 格式化照片像素（百万像素）。
function formatMegapixels(width: number | null, height: number | null) {
  if (!width || !height) {
    return null
  }

  return `${(width * height / 1_000_000).toFixed(1)} MP`
}

// 渲染单行照片信息，label 在左，value 在右；无值时不显示。
function PhotoInfoRow({
  label,
  value,
  wrap = false,
  twoLines = false,
}: {
  label: string
  value: string | null | undefined
  wrap?: boolean
  twoLines?: boolean
}) {
  if (!value) {
    return null
  }

  return (
    <div className={`flex min-w-0 justify-between gap-8 text-left text-sm ${wrap || twoLines ? "items-start" : "items-center"}`}>
      <span className="shrink-0 text-white/60">{label}</span>
      <span
        className={`min-w-0 flex-1 text-right text-white ${twoLines ? "line-clamp-2 break-all" : wrap ? "break-words whitespace-normal" : "truncate"}`}
        title={wrap ? undefined : value}
      >
        {value}
      </span>
    </div>
  )
}

// 渲染全屏模糊背景，叠在详情与信息侧栏之下。
export function PhotoViewerBlurBackground({ thumbHash }: PhotoViewerBlurBackgroundProps) {
  const thumbHashUrl = getThumbHashUrl(thumbHash)
  if (!thumbHashUrl) {
    return null
  }

  return (
    <div className="fixed inset-0 z-[-10] h-full w-full overflow-hidden">
      <img
        src={thumbHashUrl}
        alt=""
        className="h-full w-full scale-110 blur-sm object-cover"
        aria-hidden
      />
      <div className="absolute inset-0 bg-black/50" />
    </div>
  )
}

// 渲染侧栏关闭按钮（移动端 md 以下显示）。
function SidebarCloseButton({ onClose }: { onClose: () => void }) {
  const tap = useTapAction(onClose)

  return (
    <Button
      type="button"
      size="icon"
      variant="secondary"
      className="absolute top-2 right-2 z-10 rounded-full bg-black/40 text-white hover:bg-black/50 md:hidden"
      {...tap}
    >
      <XIcon />
      <span className="sr-only">Close</span>
    </Button>
  )
}

// 渲染照片信息侧栏，保持挂载以播放移动端的 CSS 淡入淡出。
export function PhotoInfoSidebar({ photo, open, onClose }: PhotoInfoSidebarProps) {
  const t = useTranslations("photos.info")
  const locale = useLocale()
  // 淡出期间保留内容，避免直方图在侧栏动画开始时就被卸载。
  const [keepContent, setKeepContent] = useState(open)
  // 打开时同步保留内容，确保紧接着关闭也能完整播放淡出。
  if (open && !keepContent) setKeepContent(true)
  const deviceParams = photo ? getPhotoDeviceParams(photo.exif) : []
  const shootingParams = photo ? getPhotoShootingParams(photo.exif) : []
  // 拍摄模式只显示原图包含的字段，未知描述保持原文。
  const captureParams = photo ? getPhotoCaptureParams(photo.exif, (key) => t.has(key) ? t(key) : null) : []
  // 技术参数置于信息栏末尾，只展示原图包含的元数据。
  const technicalParams = photo ? getPhotoTechnicalParams(photo.exif, (key) => t.has(key) ? t(key) : null) : []
  // 滚动条宿主与实际滚动视口分离，让关闭按钮固定在侧栏顶部。
  const scrollHostRef = useRef<HTMLDivElement>(null)
  // 信息内容的滚动视口，照片切换时由 OverlayScrollbars 自动更新尺寸。
  const scrollViewportRef = useRef<HTMLDivElement>(null)

  // 移动端等 200ms 淡出结束再清理内容，重新打开时取消待执行的清理。
  useEffect(() => {
    if (open) return

    const delay = window.matchMedia("(width < 48rem)").matches ? 200 : 0
    const timer = window.setTimeout(() => setKeepContent(false), delay)
    return () => window.clearTimeout(timer)
  }, [open])

  useEffect(() => {
    const host = scrollHostRef.current
    const viewport = scrollViewportRef.current
    if (!host || !viewport) return

    // 底部还有内容时淡出最后 30px，接近末尾时逐渐解除遮挡。
    function updateBottomFade() {
      const remaining = Math.max(0, viewport!.scrollHeight - viewport!.clientHeight - viewport!.scrollTop)
      viewport!.style.setProperty("--photo-info-fade", `${Math.min(30, remaining * 0.6)}px`)
    }

    const scrollbar = OverlayScrollbars({
      target: host,
      elements: { viewport },
    }, {
      overflow: { x: "hidden", y: "scroll" },
      scrollbars: {
        theme: "os-theme-page",
        autoHide: "leave",
        autoHideDelay: 800,
      },
    }, {
      initialized: updateBottomFade,
      updated: updateBottomFade,
      scroll: updateBottomFade,
    })

    // 在原生事件冒泡到查看器之前阻止传播，保留视口默认滚动行为。
    function handleWheel(event: WheelEvent) {
      event.stopPropagation()
    }

    host.addEventListener("wheel", handleWheel, { passive: true })
    return () => {
      host.removeEventListener("wheel", handleWheel)
      scrollbar.destroy()
    }
  }, [])

  return (
    <aside className={`fixed top-0 right-0 z-[41] flex h-full w-full flex-col overflow-hidden bg-transparent backdrop-blur-xl text-white shadow-photo-sidebar transition-opacity duration-200 md:transition-none md:w-80 md:shrink-0 ${open ? "opacity-100" : "pointer-events-none opacity-0 md:hidden"}`} aria-hidden={!open} inert={!open} onPointerDown={(event) => event.stopPropagation()}>
      {onClose && <SidebarCloseButton onClose={onClose} />}
      <div ref={scrollHostRef} className="min-h-0 flex-1">
        <div
          ref={scrollViewportRef}
          className="h-full w-full overflow-y-auto"
          style={{ maskImage: "linear-gradient(to bottom, black calc(100% - var(--photo-info-fade, 0px)), transparent 100%)" }}
        >
          {photo && (open || keepContent) && (
            <div className="text-left">
              <div className="px-4 pt-6.5 md:pt-4.5 text-sm font-medium">{t("basicInformation")}</div>
              <div className="space-y-1.5 px-4 py-2">
                <PhotoInfoRow label={t("fileName")} value={formatPhotoName(photo.name)} />
                <PhotoInfoRow label={t("format")} value={photo.typeDesc.toUpperCase()} />
                <PhotoInfoRow label={t("fileSize")} value={formatFileSize(photo.size)} />
                <PhotoInfoRow label={t("resolution")} value={formatResolution(photo.width, photo.height)} />
                <PhotoInfoRow label={t("megapixels")} value={formatMegapixels(photo.width, photo.height)} />
                <PhotoInfoRow label={t("colorSpace")} value={getPhotoColorSpace(photo.exif, t("uncalibrated"))} />
                <PhotoInfoRow label={t("dateTime")} value={formatPhotoTakenDateTime(photo.takenTime, locale)} />
                <PhotoInfoRow label={t("timeZone")} value={getPhotoTimezone(photo.exif)} />
                <PhotoInfoRow label={t("location")} value={formatPhotoLocation(photo.latitude, photo.longitude, photo.altitude)} wrap/>
                <PhotoInfoRow label={t("software")} value={getPhotoSoftware(photo.exif)} wrap />
                <PhotoInfoRow label={t("storage")} value={photo.storageName} />
              </div>
              {shootingParams.length > 0 && (
                <>
                  <div className="px-4 pt-3 text-sm font-medium">{t("cameraSettings")}</div>
                  <div className="space-y-1.5 px-4 py-2">
                    {shootingParams.map((item) => (
                      <PhotoInfoRow key={item.key} label={t(item.key)} value={item.value} />
                    ))}
                  </div>
                </>
              )}
              {photo.thumbnail && (
                <section className="px-4 pt-3 pb-4" aria-label={t("histogram")}>
                  <h4 className="mb-2 text-sm font-medium">{t("histogram")}</h4>
                  <PhotoHistogram thumbnailUrl={photo.thumbnail} />
                </section>
              )}
              {deviceParams.length > 0 && (
                <>
                  <div className="px-4 pt-3 text-sm font-medium">{t("device")}</div>
                  <div className="space-y-1.5 px-4 py-2">
                    {deviceParams.map((item) => (
                      <PhotoInfoRow key={item.key} label={t(item.key)} value={item.value} wrap={item.wrap} />
                    ))}
                  </div>
                </>
              )}
              {captureParams.length > 0 && (
                <section className="last:pb-4" aria-label={t("captureMode")}>
                  <h4 className="px-4 pt-3 text-sm font-medium">{t("captureMode")}</h4>
                  <div className="space-y-1.5 px-4 py-2">
                    {captureParams.map((item) => (
                      <PhotoInfoRow key={item.key} label={t(item.key)} value={item.value} wrap />
                    ))}
                  </div>
                </section>
              )}
              {technicalParams.length > 0 && (
                <section className="pb-4" aria-label={t("technicalParameters")}>
                  <h4 className="px-4 pt-3 text-sm font-medium">{t("technicalParameters")}</h4>
                  <div className="space-y-1.5 px-4 py-2">
                    {technicalParams.map((item) => (
                      <PhotoInfoRow key={item.key} label={t(item.key)} value={item.value} wrap={item.wrap} />
                    ))}
                  </div>
                </section>
              )}
            </div>
          )}
        </div>
      </div>
    </aside>
  )
}
