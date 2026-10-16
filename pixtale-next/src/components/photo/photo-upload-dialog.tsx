"use client"

import { useEffect, useRef, useState, type ChangeEvent, type RefObject } from "react"
import { CheckIcon, CircleAlertIcon, PlusIcon, RedoDot, SettingsIcon } from "lucide-react"
import { toast } from "sonner"
import { sha1 } from "hash-wasm"

import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import {
  Drawer,
  DrawerContent,
  DrawerDescription,
  DrawerFooter,
  DrawerHeader,
  DrawerTitle,
} from "@/components/ui/drawer"
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { ScrollArea } from "@/components/ui/scroll-area"
import { PhotoUploadSettings, readPhotoUploadSettings } from "@/components/photo/photo-upload-settings"
import { COVER_SIZE, createPhotoCover } from "@/lib/upload-cover"
import { useStorageStore } from "@/store/storage-store"
import { usePhotoStore } from "@/store/photo-store"
import { useAlbumStore } from "@/store/album-store"
import { photoExists } from "@/request/photo"
import { type PhotoAddResultVo } from "@/server/entity/vo/photo"
import { type StorageSelectVo } from "@/server/entity/vo/storage"
import { useTranslations } from "next-intl"
import { useIsMobile } from "@/hooks/use-mobile"

type UploadStatus = "new" | "waiting" | "uploading" | "success" | "failed" | "skipped"

interface UploadPreview {
  id: string
  cover: ImageBitmap
  file: File
  albumId: string | null
  progress: number
  status: UploadStatus
}

interface PhotoUploadHeaderProps {
  drawer?: boolean
}

interface PhotoUploadGridProps {
  previews: UploadPreview[]
  onAddPhoto: () => void
}

interface PhotoUploadFooterProps {
  fileInputRef: RefObject<HTMLInputElement | null>
  storages: StorageSelectVo[]
  selectedStorageId: string | null
  uploading: boolean
  onFileChange: (event: ChangeEvent<HTMLInputElement>) => void
  onStorageChange: (storageId: string) => void
  onSettingsChange: () => void
  onReset: () => void
  onUploadAction: () => void
}

// 在浏览器中计算待上传文件的 SHA-1 校验和。
async function getFileChecksum(file: File) {
  const buffer = await file.arrayBuffer()
  return sha1(new Uint8Array(buffer))
}

// 从上传接口响应中提取错误提示，XML 优先读取 Message 标签。
function getUploadErrorText(text: string) {
  const value = text.trim()

  try {
    const data = JSON.parse(value) as { message?: string }
    return data.message || value
  } catch {
    // 非 JSON 错误继续按普通文本或 XML 处理。
  }

  if (!value.startsWith("<") || !value.endsWith(">")) {
    return value || "Upload failed"
  }

  const xml = new DOMParser().parseFromString(value, "text/xml")
  const message = xml.querySelector("Message")?.textContent?.trim()

  return message || value
}

// 使用 XMLHttpRequest 上传照片到 /photo/add。
function uploadPhotoAdd(
  formData: FormData,
  onProgress?: (progress: number) => void,
  registerAbort?: (abort: () => void) => void,
) {
  return new Promise<PhotoAddResultVo>((resolve, reject) => {
    const request = new XMLHttpRequest()

    registerAbort?.(() => request.abort())
    request.open("POST", "/api/photo/add")
    request.withCredentials = true
    request.upload.onprogress = (event) => {
      if (event.lengthComputable) {
        onProgress?.(Math.min(95, Math.round((event.loaded / event.total) * 100)))
      }
    }
    request.onload = () => {
      try {
        const json = JSON.parse(request.responseText) as {
          code: number
          message?: string
          data?: PhotoAddResultVo
        }

        if (request.status >= 200 && request.status < 300 && json.code === 200 && json.data) {
          onProgress?.(100)
          resolve(json.data)
          return
        }

        reject(new Error(json.message || getUploadErrorText(request.responseText)))
      } catch {
        reject(new Error(getUploadErrorText(request.responseText)))
      }
    }
    request.onerror = () => reject(new Error("Upload failed"))
    request.onabort = () => reject(new DOMException("Upload aborted", "AbortError"))
    request.send(formData)
  })
}

// 渲染照片上传弹窗。
export function PhotoUploadDialog() {
  const t = useTranslations("photos.upload")
  // isMobile 控制上传面板在移动端使用 Dialog、桌面端使用右侧 Drawer。
  const isMobile = useIsMobile()
  const fileInputRef = useRef<HTMLInputElement>(null) // 文件选择 input，用于触发系统文件选择器。
  const previewsRef = useRef<UploadPreview[]>([]) // 保存照片预览和上传状态列表。
  const previewGenerationRef = useRef(0) // Invalidate pending previews after clearing or unmounting.
  const uploadQueueRef = useRef<UploadPreview[]>([]) // 保存待上传照片队列，支持上传中继续追加照片。
  const uploadingRef = useRef(false) // 标记当前是否有上传任务正在运行。
  const activeCountRef = useRef(0) // 记录当前正在上传的照片数量，用于限制并发数。
  const abortMapRef = useRef<Map<string, () => void>>(new Map()) // 保存每张照片对应的停止上传方法。
  const pausedRef = useRef(false) // 标记是否已暂停，防止 abort 收尾时重新启动上传。
  const uploadStorageIdRef = useRef<string | null>(null) // 开始后锁定的存储配置 id。
  const [uploading, setUploading] = useState(false) // 标记当前是否正在上传，用于切换开始/暂停按钮。
  const [, setPreviewTick] = useState(0) // 预览列表变更时递增，用于触发界面刷新。
  const storages = useStorageStore((state) => state.storages) // 全局可选存储配置列表。
  const savedStorageId = useStorageStore((state) => state.selectedStorageId) // 持久化的上传存储配置 id。
  const setSelectedStorageId = useStorageStore((state) => state.setSelectedStorageId) // 更新持久化的上传存储配置 id。
  const open = usePhotoStore((state) => state.uploadOpen) // 上传弹窗是否打开。
  const uploadAlbumId = usePhotoStore((state) => state.uploadAlbumId) // 当前上传目标相册 id。
  const closeUpload = usePhotoStore((state) => state.closeUpload) // 关闭上传弹窗的方法。
  const addUploadedPhoto = usePhotoStore((state) => state.addUploadedPhoto) // 上传成功后写入照片列表的方法。
  const selectedStorageId = storages.some((storage) => storage.storageId === savedStorageId)
    ? savedStorageId
    : storages[0]?.storageId ?? null

  useEffect(() => {
    return () => {
      previewGenerationRef.current += 1
      previewsRef.current.forEach((preview) => preview.cover.close())
    }
  }, [])

  // 更新预览列表并触发界面刷新。
  function setPreviews(next: UploadPreview[]) {
    previewsRef.current = next
    setPreviewTick((tick) => tick + 1)
  }

  // 打开系统文件选择器。
  function openFilePicker() {
    fileInputRef.current?.click()
  }

  // 清空弹窗内已生成的预览。
  function resetUpload() {
    previewGenerationRef.current += 1
    previewsRef.current.forEach((preview) => preview.cover.close())
    uploadQueueRef.current = []
    uploadingRef.current = false
    setUploading(false)
    setPreviews([])
  }

  // 处理弹窗打开状态变化。
  function handleOpenChange(nextOpen: boolean) {
    if (!nextOpen) {
      closeUpload()
    }
  }

  // 生成封面后再加入预览列表。
  async function addPhoto(file: File, generation: number) {
    const cover = await createPhotoCover(file)
    if (generation !== previewGenerationRef.current) {
      cover.close()
      return
    }

    const item: UploadPreview = {
      id: `${Math.random()}`,
      cover,
      file,
      albumId: uploadAlbumId,
      progress: 100,
      status: "new",
    }

    setPreviews([...previewsRef.current, item])
  }

  // 暂停上传，仅中断 xhr，并重置排队/正在上传的照片。
  function pauseUpload() {
    pausedRef.current = true
    const abortingIds = new Set(abortMapRef.current.keys())
    abortMapRef.current.forEach((abort) => abort())
    abortMapRef.current.clear()
    uploadQueueRef.current = []

    const nextPreviews = previewsRef.current.map((preview) => {
      if (preview.status === "waiting") {
        return { ...preview, progress: 100, status: "new" as UploadStatus }
      }
      if (preview.status === "uploading" && abortingIds.has(preview.id)) {
        return { ...preview, progress: 100, status: "new" as UploadStatus }
      }
      return preview
    })

    setPreviews(nextPreviews)
    uploadingRef.current = false
    setUploading(false)
  }

  // 处理选择照片后的每张新增照片。
  async function handleFileChange(event: ChangeEvent<HTMLInputElement>) {
    const files = Array.from(event.target.files ?? [])
    event.target.value = ""

    if (!files.length) {
      return
    }

    let index = 0
    const generation = previewGenerationRef.current

    // Generate previews with bounded concurrency until the batch is invalidated.
    async function runAddPhoto() {
      while (index < files.length && generation === previewGenerationRef.current) {
        const file = files[index]
        index += 1

        try {
          await addPhoto(file, generation)
        } catch {
          if (generation !== previewGenerationRef.current) {
            return
          }
          toast.error(t("previewFailed", { name: file.name }), {
            position: isMobile ? "top-center" : "bottom-center",
          })
        }
      }
    }

    await Promise.all(
      Array.from({ length: Math.min(6, files.length) }, runAddPhoto),
    )
  }

  // 把当前符合条件的照片加入上传队列。
  function enqueueUploadItems() {
    const uploadList = previewsRef.current.filter((preview) => (
      preview.status === "new" || preview.status === "failed"
    ))

    if (!uploadList.length) {
      return 0
    }

    const uploadIds = new Set(uploadList.map((preview) => preview.id))

    uploadQueueRef.current.push(...uploadList)

    const nextPreviews: UploadPreview[] = previewsRef.current.map((preview) => (
      uploadIds.has(preview.id)
        ? { ...preview, progress: 0, status: "waiting" }
        : preview
    ))

    setPreviews(nextPreviews)

    return uploadList.length
  }

  // 上传单张照片，并按结果刷新当前照片状态。
  async function uploadPhoto(preview: UploadPreview) {
    const currentStorageId = uploadStorageIdRef.current!

    setPreviews(previewsRef.current.map((p) => (
      p.id === preview.id ? { ...p, progress: 0, status: "uploading" } : p
    )))

    const item = previewsRef.current.find((p) => p.id === preview.id) ?? preview

    try {
      const checksum = await getFileChecksum(item.file)
      const existsResult = await photoExists({ checksum, name: item.file.name })

      if (existsResult.duplicate) {
        setPreviews(previewsRef.current.map((p) => (
          p.id === item.id ? { ...p, progress: 100, status: "skipped" } : p
        )))
        return
      }

      if (pausedRef.current) {
        setPreviews(previewsRef.current.map((p) => (
          p.id === item.id ? { ...p, progress: 100, status: "new" } : p
        )))
        return
      }

      const formData = new FormData()
      formData.set("lock", item.id)
      formData.set("storageId", currentStorageId)
      formData.set("file", item.file)
      formData.set("lastModified", String(item.file.lastModified))
      if (item.albumId) {
        formData.set("albumId", item.albumId)
      }

      const result = await uploadPhotoAdd(formData, (progress) => {
        setPreviews(previewsRef.current.map((p) => (
          p.id === item.id ? { ...p, progress } : p
        )))
      }, (abort) => abortMapRef.current.set(preview.id, abort))

      if (result.duplicate) {
        setPreviews(previewsRef.current.map((p) => (
          p.id === item.id ? { ...p, progress: 100, status: "skipped" } : p
        )))
        return
      }

      if (result.photo) {
        useAlbumStore.getState().increaseRefreshKey()
        addUploadedPhoto(result.photo, item.albumId)
      }

      setPreviews(previewsRef.current.map((p) => (
        p.id === item.id ? { ...p, progress: 100, status: "success" } : p
      )))

    } catch (error) {

      if (error instanceof DOMException && error.name === "AbortError") {
        return
      }

      if (error instanceof Error) {
        toast.error(error.message, {
          position: isMobile ? "top-center" : "bottom-center",
        })
        console.error(error.message)
      }

      if (readPhotoUploadSettings().retryOnFail) {
        uploadQueueRef.current.push(item)
        setPreviews(previewsRef.current.map((p) => (
          p.id === item.id ? { ...p, progress: 0, status: "waiting" } : p
        )))
        return
      }

      setPreviews(previewsRef.current.map((p) => (
        p.id === item.id ? { ...p, progress: 100, status: "failed" } : p
      )))
    } finally {
      abortMapRef.current.delete(preview.id)
    }
  }

  // 每次请求结束后马上补下一个，并发数由上传设置决定。
  function runNext() {
    if (pausedRef.current) {
      return
    }

    if (!uploadQueueRef.current.length && activeCountRef.current === 0) {
      uploadingRef.current = false
      setUploading(false)
      return
    }

    uploadingRef.current = true
    setUploading(true)
    const concurrency = readPhotoUploadSettings().concurrency

    while (activeCountRef.current < concurrency && uploadQueueRef.current.length) {
      const preview = uploadQueueRef.current.shift()

      if (!preview) {
        continue
      }

      activeCountRef.current += 1
      uploadPhoto(preview).finally(() => {
        activeCountRef.current -= 1
        runNext()
      })
    }
  }

  // 上传弹窗内待处理的照片，成功后通知父页面。
  function startUpload() {
    if (process.env.NEXT_PUBLIC_DEMO_USERNAME && previewsRef.current.length > 0) {
      toast.error("The application is running in read-only mode.", {
        position: isMobile ? "top-center" : "bottom-center",
      })
      return
    }

    if (!selectedStorageId && previewsRef.current.length > 0) {
      toast.error(t("invalidStorage"), {
        position: isMobile ? "top-center" : "bottom-center",
      })
      return
    }

    pausedRef.current = false
    uploadStorageIdRef.current = selectedStorageId
    const count = enqueueUploadItems()

    if (!count && uploadingRef.current) {
      return
    }

    runNext()
  }

  // 切换开始或暂停上传。
  function handleUploadAction() {
    if (uploading) {
      pauseUpload()
      return
    }

    startUpload()
  }

  if (isMobile) {
    return (
      <Dialog open={open} onOpenChange={handleOpenChange}>
        <DialogContent className="grid h-[80vh] max-h-[720px] min-h-0 grid-rows-[auto_minmax(0,1fr)_auto] sm:max-w-2xl">
          <PhotoUploadHeader />
          <div className="min-h-0 flex-1 overflow-y-auto px-0 md:px-4 [scrollbar-width:thin]">
            <PhotoUploadGrid previews={previewsRef.current} onAddPhoto={openFilePicker} />
          </div>
          <DialogFooter className="flex-row items-center justify-between gap-3 sm:justify-between">
            <PhotoUploadFooter
              fileInputRef={fileInputRef}
              storages={storages}
              selectedStorageId={selectedStorageId}
              uploading={uploading}
              onFileChange={handleFileChange}
              onStorageChange={setSelectedStorageId}
              onSettingsChange={runNext}
              onReset={resetUpload}
              onUploadAction={handleUploadAction}
            />
          </DialogFooter>
        </DialogContent>
      </Dialog>
    )
  }

  return (
    <Drawer direction="right" open={open} onOpenChange={handleOpenChange}>
      <DrawerContent className="h-dvh w-full min-w-0 !max-w-xl rounded-none border-l !sm:max-w-xl">
        <PhotoUploadHeader drawer />
        <ScrollArea className="min-h-0 flex-1 px-4" viewportClassName="[scrollbar-width:thin]">
          <PhotoUploadGrid previews={previewsRef.current} onAddPhoto={openFilePicker} />
        </ScrollArea>
        <DrawerFooter className="flex-row items-center justify-between gap-3">
          <PhotoUploadFooter
            fileInputRef={fileInputRef}
            storages={storages}
            selectedStorageId={selectedStorageId}
            uploading={uploading}
            onFileChange={handleFileChange}
            onStorageChange={setSelectedStorageId}
            onSettingsChange={runNext}
            onReset={resetUpload}
            onUploadAction={handleUploadAction}
          />
        </DrawerFooter>
      </DrawerContent>
    </Drawer>
  )
}

// 渲染上传面板标题，并根据容器类型使用对应的无障碍标题组件。
function PhotoUploadHeader({ drawer = false }: PhotoUploadHeaderProps) {
  const t = useTranslations("photos.upload")

  if (drawer) {
    return (
      <DrawerHeader className="text-left">
        <DrawerTitle>{t("title")}</DrawerTitle>
        <DrawerDescription className="sr-only">
          Select photos to upload to the current photo list.
        </DrawerDescription>
      </DrawerHeader>
    )
  }

  return (
    <DialogHeader>
      <DialogTitle>{t("title")}</DialogTitle>
      <DialogDescription className="sr-only">
        Select photos to upload to the current photo list.
      </DialogDescription>
    </DialogHeader>
  )
}

// Draw the decoded preview directly without encoding and decoding an image URL.
function PhotoUploadCover({ cover, name }: { cover: ImageBitmap; name: string }) {
  const canvasRef = useRef<HTMLCanvasElement>(null) // Canvas displaying the preview bitmap.

  useEffect(() => {
    canvasRef.current?.getContext("2d")?.drawImage(cover, 0, 0)
  }, [cover])

  return (
    <canvas
      ref={canvasRef}
      width={COVER_SIZE}
      height={COVER_SIZE}
      role="img"
      aria-label={name}
      className="h-full w-full"
    />
  )
}

// 渲染待上传照片预览网格和添加照片按钮。
function PhotoUploadGrid({ previews, onAddPhoto }: PhotoUploadGridProps) {
  return (
    <div className="grid grid-cols-3 content-start gap-1 md:grid-cols-4">
        {previews.map((preview) => (
          <div key={preview.id} className="relative aspect-square w-full overflow-hidden bg-muted [contain-intrinsic-size:160px_160px] [content-visibility:auto]">
            <PhotoUploadCover cover={preview.cover} name={preview.file.name} />
            {preview.progress < 100 && (
              <div
                className="pointer-events-none absolute inset-x-0 bottom-0 bg-black/60 transition-[height] duration-200"
                style={{ height: `${100 - preview.progress}%` }}
              />
            )}
            {preview.status === "success" && (
              <div className="absolute right-1 bottom-1 flex size-5 items-center justify-center rounded-full bg-black/60 text-white">
                <CheckIcon className="size-3.5" />
              </div>
            )}
            {preview.status === "failed" && (
              <div className="absolute right-1 bottom-1 flex size-5 items-center justify-center rounded-full bg-black/60 text-white">
                <CircleAlertIcon className="size-3.5" />
              </div>
            )}
            {preview.status === "skipped" && (
              <div className="absolute right-1 bottom-1 flex size-5 items-center justify-center rounded-full bg-black/60 text-white">
                <RedoDot className="size-3.5" />
              </div>
            )}
          </div>
        ))}
        <button
          type="button"
          className="flex aspect-square w-full items-center justify-center bg-muted text-muted-foreground hover:bg-muted/80"
          onClick={onAddPhoto}
        >
          <PlusIcon />
          <span className="sr-only">Add photos</span>
        </button>
    </div>
  )
}

// 渲染文件选择、存储配置和上传操作按钮。
function PhotoUploadFooter({
  fileInputRef,
  storages,
  selectedStorageId,
  uploading,
  onFileChange,
  onStorageChange,
  onSettingsChange,
  onReset,
  onUploadAction,
}: PhotoUploadFooterProps) {
  const t = useTranslations("photos.upload")

  return (
    <>
      <input
        ref={fileInputRef}
        type="file"
        accept="image/*"
        multiple
        className="hidden"
        onChange={onFileChange}
      />
      <div className="flex items-center gap-2">
        <Select
          value={selectedStorageId ?? undefined}
          onValueChange={onStorageChange}
          disabled={uploading}
        >
          <SelectTrigger className="w-40">
            <SelectValue placeholder={t("selectStorage")} />
          </SelectTrigger>
          <SelectContent>
            {storages.map((storage) => (
              <SelectItem key={storage.storageId} value={storage.storageId}>
                {storage.name}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <Popover>
          <PopoverTrigger asChild>
            <Button type="button" variant="ghost" size="icon" aria-label="Upload settings">
              <SettingsIcon className="size-4" />
            </Button>
          </PopoverTrigger>
          <PopoverContent side="top" align="start" className="w-64">
            <PhotoUploadSettings onChange={onSettingsChange} />
          </PopoverContent>
        </Popover>
      </div>
      <div className="flex items-center gap-2">
        {!uploading && (
          <Button type="button" variant="secondary" onClick={onReset}>
            {t("clear")}
          </Button>
        )}
        <Button type="button" onClick={onUploadAction}>
          {uploading ? t("pause") : t("start")}
        </Button>
      </div>
    </>
  )
}
