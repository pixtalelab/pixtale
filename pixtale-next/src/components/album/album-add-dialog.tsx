"use client"

import { useState, type KeyboardEvent } from "react"
import { Plus } from "lucide-react"
import { useTranslations } from "next-intl"

import { Dialog } from "@/components/common/dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"

interface AlbumAddDialogProps {
  title: string
  onNameConfirm: (name: string) => void
}

// 渲染新增相册弹窗，并在确认后把相册名交给父组件。
export function AlbumAddDialog({ title, onNameConfirm }: AlbumAddDialogProps) {
  const t = useTranslations("albums")
  // open 控制新增相册弹窗的显示状态。
  const [open, setOpen] = useState(false)
  // name 保存输入值，关闭动画结束后再清空。
  const [name, setName] = useState("")

  // 提交输入的相册名称。
  function submitName() {
    const value = name.trim()

    if (!value) {
      return
    }

    onNameConfirm(value)
    setOpen(false)
    setTimeout(() => setName(""), 300)
  }

  // 处理输入框回车确认。
  function handleInputKeyDown(event: KeyboardEvent<HTMLInputElement>) {
    if (event.key === "Enter") {
      submitName()
    }
  }

  // 处理弹窗打开状态变化。
  function handleOpenChange(nextOpen: boolean) {
    setOpen(nextOpen)
  }

  return (
    <Dialog
      title={title}
      className="w-full"
      preventMobileAutoFocus
      open={open}
      onOpenChange={handleOpenChange}
      onConfirm={submitName}
      trigger={
        <Button
          type="button"
          size="icon"
          variant="ghost"
        >
          <Plus />
        </Button>
      }
    >
      <Input
        value={name}
        placeholder={t("namePlaceholder")}
        onChange={(event) => setName(event.target.value)}
        onKeyDown={handleInputKeyDown}
      />
    </Dialog>
  )
}
