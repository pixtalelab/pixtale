"use client"

import type * as React from "react"
import { useTranslations } from "next-intl"

import { Button } from "@/components/ui/button"
import { useIsMobile } from "@/hooks/use-mobile"
import { cn } from "@/lib/utils"
import {
  Dialog as DialogRoot,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"

type CommonDialogProps = React.ComponentProps<typeof DialogRoot> & {
  className?: string
  title?: React.ReactNode
  description?: React.ReactNode
  trigger?: React.ReactNode
  triggerText?: string
  confirmText?: string
  cancelText?: string
  footer?: React.ReactNode
  showFooter?: boolean
  showCloseButton?: boolean
  contentClassName?: string
  // 移动端打开时是否阻止自动聚焦，默认不阻止。
  preventMobileAutoFocus?: boolean
  onConfirm?: () => void
}

// Dialog 封装通用弹窗结构，支持标题、描述、触发按钮和自定义内容区域。
function Dialog({
  className,
  title,
  description,
  trigger,
  triggerText,
  confirmText,
  cancelText,
  footer,
  showFooter = true,
  showCloseButton,
  contentClassName,
  preventMobileAutoFocus = false,
  children,
  onConfirm,
  ...props
}: CommonDialogProps) {
  const t = useTranslations("common")
  const isMobile = useIsMobile() // isMobile 标记当前是否为移动端视口。

  return (
    <DialogRoot {...props}>
      {trigger && <DialogTrigger asChild>{trigger}</DialogTrigger>}
      {!trigger && triggerText && (
        <DialogTrigger asChild>
          <Button type="button">{triggerText}</Button>
        </DialogTrigger>
      )}

      <DialogContent
        className={cn(className, contentClassName)}
        showCloseButton={showCloseButton}
        onOpenAutoFocus={(event) => {
          if (preventMobileAutoFocus && isMobile) {
            event.preventDefault()
          }
        }}
      >
        {(title || description) && (
          <DialogHeader>
            {title && <DialogTitle>{title}</DialogTitle>}
            {description && (
              <DialogDescription>{description}</DialogDescription>
            )}
          </DialogHeader>
        )}

        {children}

        {showFooter && (
          <DialogFooter>
            {footer ?? (
              <>
                <DialogClose asChild>
                  <Button type="button" variant="outline">
                    {cancelText ?? t("cancel")}
                  </Button>
                </DialogClose>
                <Button type="button" onClick={onConfirm}>
                  {confirmText ?? t("confirm")}
                </Button>
              </>
            )}
          </DialogFooter>
        )}
      </DialogContent>
    </DialogRoot>
  )
}

export { Dialog }
