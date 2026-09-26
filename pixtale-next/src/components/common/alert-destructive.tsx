"use client"

import type * as React from "react"
import { Trash2Icon } from "lucide-react"
import { useTranslations } from "next-intl"

import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogMedia,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog"

type AlertDialogDestructiveProps = React.ComponentProps<typeof AlertDialog> & {
  title: React.ReactNode
  description: React.ReactNode
  trigger?: React.ReactNode
  confirmText?: string
  cancelText?: string
  onConfirm?: () => void
}

// AlertDialogDestructive 渲染通用危险操作确认弹窗。
export function AlertDialogDestructive({
  title,
  description,
  trigger,
  confirmText,
  cancelText,
  onConfirm,
  ...props
}: AlertDialogDestructiveProps) {
  const t = useTranslations("common")

  return (
    <AlertDialog {...props}>
      {trigger && <AlertDialogTrigger asChild>{trigger}</AlertDialogTrigger>}
      <AlertDialogContent size="sm">
        <AlertDialogHeader>
          <AlertDialogMedia className="bg-destructive/10 text-destructive dark:bg-destructive/20 dark:text-destructive">
            <Trash2Icon />
          </AlertDialogMedia>
          <AlertDialogTitle>{title}</AlertDialogTitle>
          <AlertDialogDescription>{description}</AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel variant="outline">{cancelText ?? t("cancel")}</AlertDialogCancel>
          <AlertDialogAction variant="destructive" onClick={onConfirm}>
            {confirmText ?? t("delete")}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  )
}
