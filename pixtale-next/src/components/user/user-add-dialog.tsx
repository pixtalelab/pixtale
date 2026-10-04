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
import { type UserAddBo, type UserSetBo } from "@/server/entity/bo/user"
import { type UserVo } from "@/server/entity/vo/user"
import { UserTypeEnum, UserTypeOptions } from "@/server/enums/user-enum"
import { useTranslations } from "next-intl"

type UserForm = UserAddBo
type UserFormErrors = Partial<Record<keyof UserForm, string>>

interface UserAddDialogProps {
  title: string
  open: boolean
  user?: UserVo | null
  onOpenChange: (open: boolean) => void
  onUserConfirm: (user: UserAddBo | UserSetBo) => void
}

// 创建用户表单初始值。
function createUserForm(user?: UserVo | null): UserForm {
  if (user) {
    return {
      username: user.username,
      password: "",
      type: user.type,
    }
  }

  return {
    username: "",
    password: "",
    type: UserTypeEnum.NORMAL,
  }
}

// 渲染新增或编辑用户弹窗，并在确认后把用户信息交给父组件保存。
export function UserAddDialog({ title, open, user, onOpenChange, onUserConfirm }: UserAddDialogProps) {
  const t = useTranslations("users")
  // 仅在新增用户且环境变量开启时显示演示用户类型。
  const showDemoUser = process.env.NEXT_PUBLIC_DEMO_MODE === "true"
  // userTypeLabels 保存用户类型对应的本地化显示文案。
  const userTypeLabels: Record<number, string> = {
    [UserTypeEnum.ADMIN]: t("admin"),
    [UserTypeEnum.NORMAL]: t("user"),
    [UserTypeEnum.DEMO]: t("demo"),
  }
  // userTypeOptions 根据当前模式筛选并生成用户类型选项。
  const userTypeOptions = UserTypeOptions
    .filter(({ value }) => user || value !== UserTypeEnum.DEMO || showDemoUser)
    .map((option) => ({ ...option, label: userTypeLabels[option.value] }))
  // resetTimerRef 保存关闭动画结束后重置表单的定时器。
  const resetTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  // form 保存当前弹框内的用户表单数据。
  const [form, setForm] = useState<UserForm>(() => createUserForm(user))
  // errors 保存当前表单字段校验错误。
  const [errors, setErrors] = useState<UserFormErrors>({})

  useEffect(() => {
    return () => {
      if (resetTimerRef.current) {
        clearTimeout(resetTimerRef.current)
      }
    }
  }, [])

  useEffect(() => {
    if (open) {
      setForm(createUserForm(user))
      setErrors({})
    }
  }, [open, user])

  // 更新文本输入字段。
  function updateField(field: "username" | "password", value: string) {
    setForm((prev) => ({
      ...prev,
      [field]: value,
    }))
    setErrors((prev) => ({
      ...prev,
      [field]: undefined,
    }))
  }

  // 更新用户类型。
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

  // 重置用户表单。
  function resetForm() {
    setForm(createUserForm())
    setErrors({})
  }

  // 延迟重置表单，避免关闭动画期间内容先变回默认值。
  function resetFormAfterClose() {
    if (resetTimerRef.current) {
      clearTimeout(resetTimerRef.current)
    }

    resetTimerRef.current = setTimeout(() => {
      resetForm()
      resetTimerRef.current = null
    }, 300)
  }

  // 校验用户表单必填项。
  function validateForm() {
    const nextErrors: UserFormErrors = {}

    if (!form.username.trim()) {
      nextErrors.username = t("usernameRequired")
    }

    if (!form.password.trim() && !user) {
      nextErrors.password = t("passwordRequired")
    }

    if (!form.type) {
      nextErrors.type = t("typeRequired")
    }

    setErrors(nextErrors)

    return Object.keys(nextErrors).length === 0
  }

  // 提交用户信息给父组件。
  function submitUser() {
    if (!validateForm()) {
      return
    }

    const payload = {
      username: form.username.trim(),
      password: form.password.trim(),
      type: form.type,
    }

    if (user) {
      onUserConfirm({
        userId: user.userId,
        username: payload.username,
        type: payload.type,
        ...(payload.password ? { password: payload.password } : {}),
      })
    } else {
      onUserConfirm(payload)
    }

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
      contentClassName="max-md:top-20 max-md:translate-y-0"
      open={open}
      onOpenChange={handleOpenChange}
      onConfirm={submitUser}
      preventMobileAutoFocus
    >
      <div className="grid gap-4">
        <div className="grid gap-2">
          <label className="text-sm font-medium">{t("username")}</label>
          <Input
            value={form.username}
            placeholder={t("usernamePlaceholder")}
            autoComplete="off"
            name="username"
            aria-invalid={Boolean(errors.username)}
            onChange={(event) => updateField("username", event.target.value)}
          />
          {errors.username && <p className="text-sm text-destructive">{errors.username}</p>}
        </div>

        <div className="grid gap-2">
          <label className="text-sm font-medium">{t("password")}</label>
          <Input
            value={form.password}
            placeholder={user ? t("newPassword") : t("passwordPlaceholder")}
            type="password"
            autoComplete="new-password"
            name="new-password"
            aria-invalid={Boolean(errors.password)}
            onChange={(event) => updateField("password", event.target.value)}
          />
          {errors.password && <p className="text-sm text-destructive">{errors.password}</p>}
        </div>

        <div className="grid gap-2">
          <label className="text-sm font-medium">{t("type")}</label>
          <Select value={String(form.type)} onValueChange={updateType}>
            <SelectTrigger className="w-full" aria-invalid={Boolean(errors.type)}>
              <SelectValue placeholder={t("typePlaceholder")} />
            </SelectTrigger>
            <SelectContent>
              {userTypeOptions.map((option) => (
                <SelectItem key={option.value} value={String(option.value)}>
                  {option.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          {errors.type && <p className="text-sm text-destructive">{errors.type}</p>}
        </div>
      </div>
    </Dialog>
  )
}
