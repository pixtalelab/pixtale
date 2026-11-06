import { getMediaType } from "@/lib/media"

export const COVER_SIZE = 400

const VIDEO_COVER_TIMEOUT = 8_000
const VIDEO_COVER_CONCURRENCY = 4

let videoCoverActive = 0
const videoCoverWaiters = new Set<() => void>()

// 格子离开视口时用这个错误中断封面生成。
function abortError() {
  return new DOMException("The operation was aborted.", "AbortError")
}

// 手机硬解码一次只开一路，电脑同时处理四路。
function videoCoverLimit() {
  return window.innerWidth < 768 ? 1 : VIDEO_COVER_CONCURRENCY
}

// 有空位就启动下一路封面任务。
function pumpVideoCoverQueue() {
  const limit = videoCoverLimit()

  for (const start of videoCoverWaiters) {
    if (videoCoverActive >= limit) {
      break
    }
    videoCoverWaiters.delete(start)
    start()
  }
}

// 把视频封面任务排进队列。已经离开视口的任务直接跳过。
function enqueueVideoCover<T>(task: () => Promise<T>, signal?: AbortSignal): Promise<T> {
  return new Promise((resolve, reject) => {
    if (signal?.aborted) {
      reject(abortError())
      return
    }

    signal?.addEventListener("abort", cancel, { once: true })
    videoCoverWaiters.add(start)
    pumpVideoCoverQueue()

    // 离屏时立即移除排队任务，释放它引用的文件，不必等到轮到它。
    function cancel() {
      videoCoverWaiters.delete(start)
      reject(abortError())
    }

    // 轮到自己时如果已经取消，就不要再占解码器。
    async function start() {
      signal?.removeEventListener("abort", cancel)
      if (signal?.aborted) {
        reject(abortError())
        return
      }

      videoCoverActive += 1
      try {
        resolve(await task())
      } catch (error) {
        reject(error)
      } finally {
        videoCoverActive -= 1
        pumpVideoCoverQueue()
      }
    }
  })
}

// 等待媒体事件，超时或取消后继续，避免手机不派发事件时卡住。
function waitFor(target: EventTarget, type: string, timeoutMs: number, signal?: AbortSignal) {
  return new Promise<void>((resolve) => {
    if (signal?.aborted) {
      resolve()
      return
    }

    const timer = window.setTimeout(done, timeoutMs)

    // 无论事件、超时还是取消先到，都清理本次等待。
    function done() {
      window.clearTimeout(timer)
      target.removeEventListener(type, done)
      signal?.removeEventListener("abort", done)
      resolve()
    }

    target.addEventListener(type, done)
    signal?.addEventListener("abort", done, { once: true })
  })
}

// 等到浏览器画出一帧。seeked 之后手机上往往还没有可读取的像素。
function waitForFrame(video: HTMLVideoElement, signal?: AbortSignal) {
  if (typeof video.requestVideoFrameCallback !== "function") {
    return waitFor(video, "timeupdate", 1_000, signal)
  }

  return new Promise<void>((resolve) => {
    if (signal?.aborted) {
      resolve()
      return
    }

    const timer = window.setTimeout(done, 1_000)
    const frame = video.requestVideoFrameCallback(done)

    // 主动撤销尚未触发的帧回调，避免超时或离屏后仍保留它。
    function done() {
      window.clearTimeout(timer)
      video.cancelVideoFrameCallback(frame)
      signal?.removeEventListener("abort", done)
      resolve()
    }

    signal?.addEventListener("abort", done, { once: true })
  })
}

// 把图像裁成居中方图。手机不能直接读取 video 时，改由画布取出这一帧。
async function cropSquareCover(source: CanvasImageSource, width: number, height: number) {
  const size = Math.min(width, height)
  const sx = Math.floor((width - size) / 2)
  const sy = Math.floor((height - size) / 2)
  const options = { resizeWidth: COVER_SIZE, resizeHeight: COVER_SIZE, resizeQuality: "low" as const }

  try {
    return await createImageBitmap(source, sx, sy, size, size, options)
  } catch {
    const canvas = document.createElement("canvas")
    canvas.width = COVER_SIZE
    canvas.height = COVER_SIZE
    const context = canvas.getContext("2d")
    if (!context) {
      throw new Error("canvas")
    }
    context.drawImage(source, sx, sy, size, size, 0, 0, COVER_SIZE, COVER_SIZE)
    return createImageBitmap(canvas)
  }
}

// 从视频约 0.1 秒截取一帧。先播放再跳转，让手机真正解码；无法解码时返回空。
function createVideoCover(file: File, signal?: AbortSignal): Promise<ImageBitmap | null> {
  // 排队阶段也要接收取消信号，避免离屏任务重新占用手机唯一的解码名额。
  return enqueueVideoCover(() => new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file)
    const video = document.createElement("video")
    const controller = new AbortController() // 任务结束时一并取消媒体事件和帧等待。
    let settled = false
    const timer = window.setTimeout(() => finish(null), VIDEO_COVER_TIMEOUT)

    // 结束截帧并释放视频元素。离开视口时中断，不把空封面当成失败。
    function finish(cover: ImageBitmap | null) {
      if (settled) {
        cover?.close()
        return
      }
      settled = true
      window.clearTimeout(timer)
      signal?.removeEventListener("abort", onAbort)
      controller.abort()
      video.onerror = null
      video.removeEventListener("loadedmetadata", readFrame)
      video.pause()
      video.removeAttribute("src")
      video.load()
      video.remove()
      URL.revokeObjectURL(url)
      if (signal?.aborted) {
        cover?.close()
        reject(abortError())
        return
      }
      resolve(cover)
    }

    // 外部取消与超时共用收尾逻辑，成功后会移除此监听。
    function onAbort() {
      finish(null)
    }

    signal?.addEventListener("abort", onAbort, { once: true })

    // 播放后跳到目标时间，再读取已经画出来的那一帧。
    async function readFrame() {
      try {
        if (settled) {
          return
        }
        await video.play().catch(() => undefined)
        if (settled) {
          return
        }
        const duration = video.duration
        const target = Number.isFinite(duration) && duration > 0 ? Math.min(0.1, duration / 2) : 0

        const seekableDeadline = performance.now() + 2_000
        while (target > 0 && video.seekable.length === 0 && performance.now() < seekableDeadline) {
          await waitFor(video, "progress", 200, controller.signal)
          if (settled) {
            return
          }
        }
        if (target > 0 && video.seekable.length > 0) {
          const end = video.seekable.end(video.seekable.length - 1)
          const seeked = waitFor(video, "seeked", 2_000, controller.signal)
          video.currentTime = Math.min(target, Math.max(0, end - 0.05))
          await seeked
        }
        if (settled) {
          return
        }

        await waitForFrame(video, controller.signal)
        if (settled) {
          return
        }
        const { videoWidth, videoHeight } = video
        finish(videoWidth && videoHeight
          ? await cropSquareCover(video, videoWidth, videoHeight)
          : null)
      } catch {
        finish(null)
      }
    }

    video.muted = true
    video.playsInline = true
    video.preload = "auto"
    video.setAttribute("muted", "")
    video.setAttribute("playsinline", "")
    video.style.cssText = "position:fixed;bottom:0;left:0;width:8px;height:8px;opacity:0.01;pointer-events:none"
    document.body.appendChild(video)
    video.onerror = () => finish(null)
    video.addEventListener("loadedmetadata", readFrame, { once: true })
    video.src = url
    void video.play().catch(() => undefined)
  }), signal)
}

// 生成上传面板使用的预览位图。图片直接解码，视频截取一帧。信号取消时不再占用队列。
export async function createPhotoCover(file: File, signal?: AbortSignal): Promise<ImageBitmap | null> {
  if (signal?.aborted) {
    throw abortError()
  }
  if (getMediaType(file).startsWith("video/")) {
    return createVideoCover(file, signal)
  }

  const bitmap = await createImageBitmap(file)

  try {
    return await cropSquareCover(bitmap, bitmap.width, bitmap.height)
  } finally {
    bitmap.close()
  }
}
