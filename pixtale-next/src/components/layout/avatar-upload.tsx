"use client"

import { useEffect, useState } from "react"
import Cropper, { type Area, type Point } from "react-easy-crop"

import { Dialog } from "@/components/common/dialog"
import { Slider } from "@/components/ui/slider"
import { userSetAvatar } from "@/request/user"
import { useTranslations } from "next-intl"

interface AvatarUploadProps {
  open: boolean
  image: string
  name: string
  onOpenChange: (open: boolean) => void
  onAvatarChange: (avatarKey: string) => void
}

// 加载图片，供 canvas 根据裁剪区域生成头像。
function loadImage(src: string) {
  return new Promise<HTMLImageElement>((resolve, reject) => {
    const image = new Image()

    image.crossOrigin = "anonymous"
    image.onload = () => resolve(image)
    image.onerror = reject
    image.src = src
  })
}

// 根据裁剪区域生成固定尺寸头像。
async function getCroppedAvatar(src: string, crop: Area) {
  const image = await loadImage(src)
  const canvas = document.createElement("canvas")
  const context = canvas.getContext("2d")
  const size = 128

  if (!context || !crop.width || !crop.height) {
    return ""
  }

  canvas.width = size
  canvas.height = size
  context.drawImage(
    image,
    crop.x,
    crop.y,
    crop.width,
    crop.height,
    0,
    0,
    size,
    size
  )

  return canvas.toDataURL("image/webp", 0.9)
}

// 渲染头像上传和裁剪弹框。
export function AvatarUpload({ open, image, onOpenChange, onAvatarChange }: AvatarUploadProps) {
  const t = useTranslations("layout.avatar")

  // cropperImage 延迟绑定给 Cropper，避免弹框布局未稳定时提前测量。
  const [cropperImage, setCropperImage] = useState("")
  // crop 保存图片在裁剪窗口中的拖动位置。
  const [crop, setCrop] = useState<Point>({ x: 0, y: 0 })
  // zoom 保存图片在裁剪窗口中的缩放比例。
  const [zoom, setZoom] = useState(1)
  // croppedAreaPixels 保存当前裁剪窗口对应的原图像素区域。
  const [croppedAreaPixels, setCroppedAreaPixels] = useState<Area | null>(null)

  useEffect(() => {
    const timer = window.setTimeout(() => {
      setCropperImage(image)
    }, 100)

    return () => {
      window.clearTimeout(timer)
    }
  }, [image])

  // 保存当前裁剪区域，供点击保存时生成头像。
  function completeCrop(_: Area, nextAreaPixels: Area) {
    setCroppedAreaPixels(nextAreaPixels)
  }

  // 保存裁剪后的头像，并把结果交给父组件。
  async function saveAvatar() {

    if (!croppedAreaPixels) {
      onOpenChange(false)
      return
    }

    onOpenChange(false)

    setTimeout(async () => {
      const nextAvatar = await getCroppedAvatar(image, croppedAreaPixels)
      const avatarKey = await userSetAvatar({ avatar: nextAvatar })
      onAvatarChange(avatarKey)
    }, 100)

  }

  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t("title")}
      showCloseButton={false}
      contentClassName="sm:max-w-md"
      onConfirm={saveAvatar}
    >
      <div className="flex flex-col gap-4">
        <div className="relative h-[360px] w-full overflow-hidden rounded-lg bg-muted">
          <Cropper
            image={cropperImage}
            crop={crop}
            zoom={zoom}
            aspect={1}
            cropShape="rect"
            showGrid
            objectFit="contain"
            onCropChange={setCrop}
            onZoomChange={setZoom}
            onCropComplete={completeCrop}
            classes={{
              cropAreaClassName: "rounded-lg",
            }}
          />
        </div>
        <Slider
          min={1}
          max={3}
          step={0.01}
          value={[zoom]}
          aria-label="Adjust profile picture zoom"
          onValueChange={(value) => setZoom(value[0] ?? 1)}
        />
      </div>
    </Dialog>
  )
}
