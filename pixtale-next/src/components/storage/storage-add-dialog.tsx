"use client"

import { useEffect, useRef, useState } from "react"

import { Dialog } from "@/components/common/dialog"
import { Input } from "@/components/ui/input"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { StorageTypeEnum } from "@/server/enums/storage-enum"
import { type StorageInto } from "@/server/entity/storage"
import { type StorageVo } from "@/server/entity/vo/storage"
import { useTranslations } from "next-intl"

type StorageAddForm = Omit<StorageInto, "storageId" | "userId">
type StorageAddFormErrors = Partial<Record<keyof StorageAddForm, string>>

interface StorageAddDialogProps {
  title: string
  open: boolean
  storage?: StorageVo | null
  onOpenChange: (open: boolean) => void
  onStorageConfirm: (storage: StorageInto) => void
}

// 创建存储表单初始值。
function createStorageForm(storage?: StorageVo | null): StorageAddForm {
  if (storage) {
    return {
      name: storage.name,
      type: storage.type,
      domain: storage.domain ?? "",
      bucket: storage.bucket ?? "",
      region: storage.region ?? "",
      endpoint: storage.endpoint ?? "",
      accessKey: storage.accessKey ?? "",
      secretKey: storage.secretKey ?? "",
      status: storage.status,
    }
  }

  return {
    name: "",
    type: StorageTypeEnum.S3,
    domain: "",
    bucket: "",
    region: "",
    endpoint: "",
    accessKey: "",
    secretKey: "",
  }
}

// 渲染存储弹窗，并在确认后把存储配置交给父组件保存。
export function StorageAddDialog({ title, open, storage, onOpenChange, onStorageConfirm }: StorageAddDialogProps) {
  const t = useTranslations("storage")
  const storageTypeOptions = [
    { label: t("local"), value: StorageTypeEnum.LOCAL, disabled: true },
    { label: t("objectStorage"), value: StorageTypeEnum.S3, disabled: false },
  ]
  // resetTimerRef 保存关闭动画结束后重置表单的定时器。
  const resetTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  // form 保存当前弹框内的存储表单数据。
  const [form, setForm] = useState<StorageAddForm>(() => createStorageForm(storage))
  // errors 保存当前表单字段校验错误。
  const [errors, setErrors] = useState<StorageAddFormErrors>({})

  const isS3 = form.type === StorageTypeEnum.S3
  // 编辑本地存储时不允许修改类型。
  const typeLocked = Boolean(storage && storage.type === StorageTypeEnum.LOCAL)

  useEffect(() => {
    return () => {
      if (resetTimerRef.current) {
        clearTimeout(resetTimerRef.current)
      }
    }
  }, [])

  // 更新文本输入字段。
  function updateField(field: keyof StorageAddForm, value: string) {
    setForm((prev) => ({
      ...prev,
      [field]: value,
    }))
    setErrors((prev) => ({
      ...prev,
      [field]: undefined,
    }))
  }

  // 更新存储类型。
  function updateType(value: string) {
    setForm((prev) => ({
      ...prev,
      type: Number(value),
    }))
    setErrors((prev) => ({
      ...prev,
      type: undefined,
    }))
  }

  // 重置新增存储表单。
  function resetForm() {
    setForm(createStorageForm())
    setErrors({})
  }

  // 延迟重置表单，避免关闭动画期间内容先变回默认类型。
  function resetFormAfterClose() {
    if (resetTimerRef.current) {
      clearTimeout(resetTimerRef.current)
    }

    resetTimerRef.current = setTimeout(() => {
      resetForm()
      resetTimerRef.current = null
    }, 300)
  }

  // 校验新增存储表单必填项。
  function validateForm() {
    const nextErrors: StorageAddFormErrors = {}

    if (!form.name.trim()) {
      nextErrors.name = t("nameRequired")
    }

    if (!form.type) {
      nextErrors.type = t("typeRequired")
    }

    if (isS3) {
      if (!form.bucket?.trim()) {
        nextErrors.bucket = t("bucketRequired")
      }

      if (!form.endpoint?.trim()) {
        nextErrors.endpoint = t("endpointRequired")
      }

      if (!form.accessKey?.trim()) {
        nextErrors.accessKey = t("accessKeyRequired")
      }

      if (!form.secretKey?.trim()) {
        nextErrors.secretKey = t("secretKeyRequired")
      }
    }

    setErrors(nextErrors)

    return Object.keys(nextErrors).length === 0
  }

  // 提交存储配置给父组件。
  function submitStorage() {
    const name = form.name.trim()

    if (!validateForm()) {
      return
    }

    onStorageConfirm({
      ...form,
      storageId: storage?.storageId ?? "",
      name,
      domain: isS3 ? form.domain?.trim() || null : null,
      bucket: isS3 ? form.bucket?.trim() || null : null,
      region: isS3 ? form.region?.trim() || null : null,
      endpoint: isS3 ? form.endpoint?.trim() || null : null,
      accessKey: isS3 ? form.accessKey?.trim() || null : null,
      secretKey: isS3 ? form.secretKey?.trim() || null : null,
    })
    handleOpenChange(false)
  }

  // 处理弹窗打开状态变化。
  function handleOpenChange(nextOpen: boolean) {
    if (nextOpen && resetTimerRef.current) {
      clearTimeout(resetTimerRef.current)
      resetTimerRef.current = null
    }

    onOpenChange(nextOpen)

    if (!nextOpen) {
      resetFormAfterClose()
    }
  }

  return (
    <Dialog
      title={title}
      className="w-full sm:max-w-sm"
      open={open}
      onOpenChange={handleOpenChange}
      onConfirm={submitStorage}
      preventMobileAutoFocus
    >
      <div className="grid gap-4">
        <div className="grid gap-2">
          <label className="text-sm font-medium">{t("name")}</label>
          <Input
            value={form.name}
            placeholder={t("namePlaceholder")}
            aria-invalid={Boolean(errors.name)}
            onChange={(event) => updateField("name", event.target.value)}
          />
          {errors.name && <p className="text-sm text-destructive">{errors.name}</p>}
        </div>

        <div className="grid gap-2">
          <label className="text-sm font-medium">{t("type")}</label>
          <Select value={String(form.type)} onValueChange={updateType} disabled={typeLocked}>
            <SelectTrigger className="w-full" aria-invalid={Boolean(errors.type)} disabled={typeLocked}>
              <SelectValue placeholder={t("typePlaceholder")} />
            </SelectTrigger>
            <SelectContent>
              {storageTypeOptions.map((option) => (
                <SelectItem
                  key={option.value}
                  value={String(option.value)}
                  disabled={option.disabled}
                  className={option.disabled ? "text-muted-foreground" : ""}
                >
                  {option.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          {errors.type && <p className="text-sm text-destructive">{errors.type}</p>}
        </div>

        {isS3 && (
          <div className="grid gap-3">
            <div className="grid gap-2">
              <Input
                value={form.domain ?? ""}
                placeholder={t("domainPlaceholder")}
                aria-invalid={Boolean(errors.domain)}
                onChange={(event) => updateField("domain", event.target.value)}
              />
              {errors.domain && <p className="text-sm text-destructive">{errors.domain}</p>}
            </div>
            <div className="grid gap-2">
              <Input
                value={form.bucket ?? ""}
                placeholder={t("bucket")}
                aria-invalid={Boolean(errors.bucket)}
                onChange={(event) => updateField("bucket", event.target.value)}
              />
              {errors.bucket && <p className="text-sm text-destructive">{errors.bucket}</p>}
            </div>
            <div className="grid gap-2">
              <Input
                value={form.region ?? ""}
                placeholder={t("region")}
                onChange={(event) => updateField("region", event.target.value)}
              />
            </div>
            <div className="grid gap-2">
              <Input
                value={form.endpoint ?? ""}
                placeholder={t("endpoint")}
                aria-invalid={Boolean(errors.endpoint)}
                onChange={(event) => updateField("endpoint", event.target.value)}
              />
              {errors.endpoint && <p className="text-sm text-destructive">{errors.endpoint}</p>}
            </div>
            <div className="grid gap-2">
              <Input
                value={form.accessKey ?? ""}
                placeholder="Access Key"
                aria-invalid={Boolean(errors.accessKey)}
                onChange={(event) => updateField("accessKey", event.target.value)}
              />
              {errors.accessKey && <p className="text-sm text-destructive">{errors.accessKey}</p>}
            </div>
            <div className="grid gap-2">
              <Input
                value={form.secretKey ?? ""}
                placeholder="Secret Key"
                type="text"
                aria-invalid={Boolean(errors.secretKey)}
                onChange={(event) => updateField("secretKey", event.target.value)}
              />
              {errors.secretKey && <p className="text-sm text-destructive">{errors.secretKey}</p>}
            </div>
          </div>
        )}
      </div>
    </Dialog>
  )
}

export { StorageTypeEnum }
