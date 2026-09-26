"use client"

import { useState, type KeyboardEvent } from "react"
import { useTranslations } from "next-intl"

import { Dialog } from "@/components/common/dialog"
import { Input } from "@/components/ui/input"

interface AlbumRenameDialogProps {
  open: boolean
  name: string
  onOpenChange: (open: boolean) => void
  onNameConfirm: (name: string) => void
}

// 渲染修改相册名字弹窗。
export function AlbumRenameDialog({ open, name, onOpenChange, onNameConfirm }: AlbumRenameDialogProps) {
  const t = useTranslations("albums")
  // inputName 保存弹框输入框中的相册名称。
  const [inputName, setInputName] = useState(name)

  // 提交修改后的相册名称。
  function submitName() {
    const value = inputName.trim()

    if (!value) {
      return
    }

    onNameConfirm(value)
  }

  // 处理输入框回车确认。
  function handleInputKeyDown(event: KeyboardEvent<HTMLInputElement>) {
    if (event.key === "Enter") {
      submitName()
    }
  }

  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t("renameTitle")}
      className="w-full"
      showCloseButton={false}
      onConfirm={submitName}
    >
      <Input
        value={inputName}
        placeholder={t("namePlaceholder")}
        onChange={(event) => setInputName(event.target.value)}
        onKeyDown={handleInputKeyDown}
      />
    </Dialog>
  )
}
