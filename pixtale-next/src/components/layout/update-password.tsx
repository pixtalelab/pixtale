"use client"

import { useState } from "react"

import { Dialog } from "@/components/common/dialog"
import { Input } from "@/components/ui/input"
import { userSetUserPassword } from "@/request/user"
import { useTranslations } from "next-intl"

interface UpdatePasswordProps {
  open: boolean
  onOpenChange: (open: boolean) => void
}

// 渲染当前用户修改密码弹窗。
export function UpdatePassword({ open, onOpenChange }: UpdatePasswordProps) {
  const t = useTranslations("layout.password")
  // password 保存当前输入的新密码。
  const [password, setPassword] = useState("")
  // confirmPassword 保存当前输入的确认密码。
  const [confirmPassword, setConfirmPassword] = useState("")
  // error 保存密码输入框校验错误。
  const [error, setError] = useState("")

  // 重置修改密码表单。
  function resetForm() {
    setPassword("")
    setConfirmPassword("")
    setError("")
  }

  // 更新密码输入框内容。
  function updatePassword(value: string) {
    setPassword(value)
    setError("")
  }

  // 更新确认密码输入框内容。
  function updateConfirmPassword(value: string) {
    setConfirmPassword(value)
    setError("")
  }

  // 处理弹窗打开状态变化。
  function handleOpenChange(nextOpen: boolean) {
    onOpenChange(nextOpen)

    if (!nextOpen) {
      resetForm()
    }
  }

  // 提交当前用户新密码。
  function submitPassword() {
    const nextPassword = password.trim()
    const nextConfirmPassword = confirmPassword.trim()

    if (!nextPassword) {
      setError(t("passwordRequired"))
      return
    }

    if (!nextConfirmPassword) {
      setError(t("confirmationRequired"))
      return
    }

    if (nextPassword !== nextConfirmPassword) {
      setError(t("passwordMismatch"))
      return
    }

    onOpenChange(false)

    userSetUserPassword({ password: nextPassword }).then(() => {
      resetForm()
    })
  }

  return (
    <Dialog
      title={t("title")}
      className="w-full sm:max-w-sm"
      open={open}
      showCloseButton={false}
      onOpenChange={handleOpenChange}
      onConfirm={submitPassword}
    >
      <div className="grid gap-2">
        <Input
          name="new-password"
          autoComplete="new-password"
          value={password}
          placeholder={t("newPassword")}
          type="password"
          aria-invalid={Boolean(error)}
          className="mb-1"
          onChange={(event) => updatePassword(event.target.value)}
        />
        <Input
          name="new-password"
          autoComplete="new-password"
          value={confirmPassword}
          placeholder={t("confirmPassword")}
          type="password"
          aria-invalid={Boolean(error)}
          onChange={(event) => updateConfirmPassword(event.target.value)}
        />
        {error && <p className="text-sm text-destructive">{error}</p>}
      </div>
    </Dialog>
  )
}
