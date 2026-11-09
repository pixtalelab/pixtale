"use client"

import { useTranslations } from "next-intl"
import { useEffect, useRef, useState } from "react"

const BIN_COUNT = 128
const CHANNELS = ["luminance", "red", "green", "blue"] as const
type Channel = typeof CHANNELS[number]
type Histogram = Record<Channel, number[]>
type HistogramResult = { url: string; bins: Histogram | null }

const CHANNEL_COLORS: Record<Channel, string> = {
  luminance: "255, 255, 255",
  red: "255, 105, 97",
  green: "52, 199, 89",
  blue: "64, 156, 255",
}

// 按 128 个色阶统计 RGB 与 BT.709 亮度通道，透明像素不参与计算。
function calculateHistogram(data: Uint8ClampedArray): Histogram {
  const bins: Histogram = {
    luminance: new Array(BIN_COUNT).fill(0),
    red: new Array(BIN_COUNT).fill(0),
    green: new Array(BIN_COUNT).fill(0),
    blue: new Array(BIN_COUNT).fill(0),
  }

  for (let index = 0; index < data.length; index += 4) {
    if (data[index + 3] === 0) continue
    const red = data[index]
    const green = data[index + 1]
    const blue = data[index + 2]
    bins.red[red >> 1]++
    bins.green[green >> 1]++
    bins.blue[blue >> 1]++
    bins.luminance[Math.round(red * 0.2126 + green * 0.7152 + blue * 0.0722) >> 1]++
  }

  return bins
}

// 按容器尺寸创建高清画布和渐变色条，供动画帧重复绘制。
function createRenderer(canvas: HTMLCanvasElement) {
  const { width, height } = canvas.getBoundingClientRect()
  const context = canvas.getContext("2d")
  if (!context || !width || !height) return null

  const dpr = window.devicePixelRatio || 1
  canvas.width = Math.round(width * dpr)
  canvas.height = Math.round(height * dpr)
  context.scale(dpr, dpr)

  const strips = {} as Record<Channel, HTMLCanvasElement>
  for (const channel of CHANNELS) {
    const strip = document.createElement("canvas")
    strip.width = 1
    strip.height = Math.max(1, Math.round(height * dpr))
    const stripContext = strip.getContext("2d")!
    const alpha = channel === "luminance" ? 0.3 : 0.7
    const gradient = stripContext.createLinearGradient(0, 0, 0, strip.height)
    gradient.addColorStop(0, `rgba(${CHANNEL_COLORS[channel]}, ${alpha})`)
    gradient.addColorStop(1, `rgba(${CHANNEL_COLORS[channel]}, ${alpha * 0.1})`)
    stripContext.fillStyle = gradient
    stripContext.fillRect(0, 0, 1, strip.height)
    strips[channel] = strip
  }

  // 先画亮度，再以滤色方式叠加 RGB，保留通道重叠形成的颜色。
  return function draw(bins: Histogram) {
    context.clearRect(0, 0, width, height)
    context.fillStyle = "rgba(28, 28, 30, 0.95)"
    context.fillRect(0, 0, width, height)
    context.strokeStyle = "rgba(255, 255, 255, 0.04)"
    context.lineWidth = 0.5
    for (let line = 1; line <= 3; line++) {
      const y = height * line / 4
      context.beginPath()
      context.moveTo(0, y)
      context.lineTo(width, y)
      context.stroke()
    }

    const max = Math.max(...bins.luminance, ...bins.red, ...bins.green, ...bins.blue)
    const barWidth = width / BIN_COUNT
    if (max > 0) {
      for (const channel of CHANNELS) {
        context.globalCompositeOperation = channel === "luminance" ? "source-over" : "screen"
        for (let index = 0; index < BIN_COUNT; index++) {
          const barHeight = bins[channel][index] / max * height
          if (barHeight > 0) {
            context.drawImage(strips[channel], index * barWidth, height - barHeight, barWidth * 0.8, barHeight)
          }
        }
      }
    }
    context.globalCompositeOperation = "source-over"
    context.strokeStyle = "rgba(255, 255, 255, 0.04)"
    context.lineWidth = 1
    context.strokeRect(-0.5, -0.5, width + 1, height + 1)
    const highlight = context.createLinearGradient(0, 0, 0, height * 0.2)
    highlight.addColorStop(0, "rgba(255, 255, 255, 0.03)")
    highlight.addColorStop(1, "rgba(255, 255, 255, 0)")
    context.fillStyle = highlight
    context.fillRect(0, 0, width, height * 0.2)
  }
}

// 从缩略图计算并展示照片直方图，切换照片时平滑过渡各通道。
export function PhotoHistogram({ thumbnailUrl }: { thumbnailUrl: string }) {
  const t = useTranslations("photos.info")
  // 显示直方图的画布。
  const canvasRef = useRef<HTMLCanvasElement>(null)
  // 保留最近一帧的通道数据，供切图动画和尺寸变化时重绘。
  const previousRef = useRef<Histogram | null>(null)
  // 计算结果绑定图片地址，旧请求完成时不会被当成当前照片的结果。
  const [result, setResult] = useState<HistogramResult | null>(null)
  // 记录等待超过 3 秒的图片地址，仅对当前未完成的图片显示加载提示。
  const [loadingUrl, setLoadingUrl] = useState<string | null>(null)
  // 地址变化后立即进入加载状态，避免展示上一张照片的成功或失败状态。
  const loading = result?.url !== thumbnailUrl
  const failed = !loading && !result?.bins
  // 加载超过 3 秒后，同步显示遮罩、变暗效果和加载提示。
  const showLoading = loading && loadingUrl === thumbnailUrl

  useEffect(() => {
    if (!loading) return

    const timer = window.setTimeout(() => setLoadingUrl(thumbnailUrl), 3000)
    return () => {
      window.clearTimeout(timer)
      setLoadingUrl(null)
    }
  }, [loading, thumbnailUrl])

  useEffect(() => {
    const image = new Image()
    image.crossOrigin = "anonymous"

    // 将图片缩放到最长边 300 像素，控制像素读取的开销。
    function handleLoad() {
      try {
        const canvas = document.createElement("canvas")
        const context = canvas.getContext("2d", { willReadFrequently: true })
        if (!context) throw new Error("Canvas unavailable")
        const scale = Math.min(1, 300 / image.naturalWidth, 300 / image.naturalHeight)
        canvas.width = Math.max(1, Math.floor(image.naturalWidth * scale))
        canvas.height = Math.max(1, Math.floor(image.naturalHeight * scale))
        context.drawImage(image, 0, 0, canvas.width, canvas.height)
        const { data } = context.getImageData(0, 0, canvas.width, canvas.height)
        setResult({ url: thumbnailUrl, bins: calculateHistogram(data) })
      } catch {
        handleError()
      }
    }

    // 图片加载或跨域像素读取失败时显示提示。
    function handleError() {
      setResult({ url: thumbnailUrl, bins: null })
    }

    image.onload = handleLoad
    image.onerror = handleError
    image.src = thumbnailUrl
    return () => {
      image.onload = null
      image.onerror = null
    }
  }, [thumbnailUrl])

  useEffect(() => {
    const canvas = canvasRef.current
    const bins = result?.bins
    if (!canvas || !bins || result.url !== thumbnailUrl) return

    let draw = createRenderer(canvas)
    let animation: number | null = null
    const previous = previousRef.current
    const start = performance.now()
    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches

    // 使用阻尼曲线插值，快速切图时从当前画面继续过渡。
    function frame(now: number) {
      const elapsed = (now - start) / 1000
      const progress = previous && !reduceMotion
        ? Math.max(0, Math.min(1, 1 - Math.exp(-7 * elapsed) * (Math.cos(8 * elapsed) + 7 / 8 * Math.sin(8 * elapsed))))
        : 1
      const current = {} as Histogram
      for (const channel of CHANNELS) {
        current[channel] = bins![channel].map((value, index) => {
          const from = previous?.[channel][index] ?? value
          return from + (value - from) * progress
        })
      }
      previousRef.current = current
      draw?.(current)
      if (1 - progress > 0.001 && elapsed < 1.2) {
        animation = requestAnimationFrame(frame)
      } else {
        previousRef.current = bins!
        draw?.(bins!)
        animation = null
      }
    }

    // 侧栏和屏幕尺寸变化后重建画布，避免移动端出现拉伸或空白。
    const observer = new ResizeObserver(() => {
      draw = createRenderer(canvas)
      draw?.(previousRef.current ?? bins)
    })
    observer.observe(canvas)
    animation = requestAnimationFrame(frame)
    return () => {
      observer.disconnect()
      if (animation !== null) cancelAnimationFrame(animation)
    }
  }, [result, thumbnailUrl])

  return (
    <div className="group relative h-32 w-full" aria-busy={loading}>
      <canvas
        ref={canvasRef}
        role="img"
        aria-label={t("histogramDescription")}
        aria-hidden={loading || failed}
        className={`h-full w-full rounded-sm bg-[rgba(28,28,30,0.95)] ring-1 ring-white/[0.04] backdrop-blur-xl transition-opacity duration-200 group-hover:ring-white/[0.08] ${showLoading || failed ? "opacity-30" : ""}`}
      />
      {showLoading && (
        <div role="status" className="absolute inset-0 flex items-center justify-center rounded-sm bg-white/5 backdrop-blur-xl">
          <svg className="size-5 animate-spin" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
            <path d="M20 12a8 8 0 1 0-16 0a8 8 0 0 0 16 0m2 0c0 5.523-4.477 10-10 10S2 17.523 2 12S6.477 2 12 2s10 4.477 10 10" opacity=".1" />
            <path d="M12 2a1 1 0 1 1 0 2a7.96 7.96 0 0 0-5.534 2.222a1 1 0 1 1-1.382-1.444q.631-.605 1.36-1.093A9.96 9.96 0 0 1 12 2" />
          </svg>
          <span className="sr-only">{t("histogramLoading")}</span>
        </div>
      )}
      {failed && (
        <div role="status" className="absolute inset-0 flex items-center justify-center rounded-sm bg-white/5 text-xs text-white/60 backdrop-blur-xl">
          {t("histogramFailed")}
        </div>
      )}
    </div>
  )
}
