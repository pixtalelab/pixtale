"use client"

import { useState } from "react"
import { useTranslations } from "next-intl"

import { Slider } from "@/components/ui/slider"
import { Switch } from "@/components/ui/switch"

interface PhotoUploadSettingsValue {
  concurrency: number
  retryOnFail: boolean
}

const STORAGE_KEY = "photo-upload-settings"

const defaultSettings: PhotoUploadSettingsValue = {
  concurrency: 4,
  retryOnFail: false,
}

// 把并发数限制在 1 到 10 之间。
function clampConcurrency(value: number) {
  return Math.min(10, Math.max(1, Math.round(value)))
}

// 从本地存储读取照片上传设置，读取失败时返回默认值。
export function readPhotoUploadSettings() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)

    if (!raw) {
      return defaultSettings
    }

    const data = JSON.parse(raw) as Partial<PhotoUploadSettingsValue>

    return {
      concurrency: clampConcurrency(data.concurrency ?? defaultSettings.concurrency),
      retryOnFail: data.retryOnFail ?? defaultSettings.retryOnFail,
    }
  } catch {
    return defaultSettings
  }
}

// 把照片上传设置写入本地存储。
function savePhotoUploadSettings(settings: PhotoUploadSettingsValue) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify({
    concurrency: clampConcurrency(settings.concurrency),
    retryOnFail: settings.retryOnFail,
  }))
}

// 渲染照片上传 Popover 内的设置项。
export function PhotoUploadSettings({ onChange }: { onChange?: () => void }) {
  const t = useTranslations("photos.upload")
  const [settings, setSettings] = useState<PhotoUploadSettingsValue>(() => readPhotoUploadSettings()) // 从本地存储读取的当前设置。

  // 合并更新设置并写入本地存储。
  function updateSettings(patch: Partial<PhotoUploadSettingsValue>) {
    setSettings((prev) => {
      const next = { ...prev, ...patch }

      savePhotoUploadSettings(next)
      onChange?.()

      return next
    })
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-col gap-2">
        <div className="flex items-center justify-between text-sm font-medium">
          <span>{t("concurrentUploads")}</span>
          <span className="text-muted-foreground">{settings.concurrency}</span>
        </div>
        <Slider
          min={1}
          max={10}
          step={1}
          value={[settings.concurrency]}
          onValueChange={(value) => updateSettings({ concurrency: value[0] })}
        />
      </div>
      <div className="flex flex-col gap-2">
        <div className="text-sm font-medium">{t("retryFailedUploads")}</div>
        <Switch
          checked={settings.retryOnFail}
          onCheckedChange={(retryOnFail) => updateSettings({ retryOnFail })}
        />
      </div>
    </div>
  )
}
