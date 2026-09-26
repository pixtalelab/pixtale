"use client"

import { Column, ColumnDef } from "@tanstack/react-table"
import { IconCircleCheckFilled, IconCircleXFilled } from "@tabler/icons-react"
import { ArrowUpDown, MoreHorizontal } from "lucide-react"

import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { UserStatusEnum, UserTypeEnum } from "@/server/enums/user-enum"
import { type UserVo } from "@/server/entity/vo/user"
import { useTranslations } from "next-intl"
import { formatCapacity } from "@/lib/file"

interface SortableHeaderProps {
  label: string
  column: Column<UserVo, unknown>
}

interface UserColumnsOptions {
  onEdit: (user: UserVo) => void
  onToggleStatus: (userId: string) => void
  onDelete: (user: UserVo) => void
}

// 渲染带固定排序图标的表头按钮。
function SortableHeader({ label, column }: SortableHeaderProps) {
  return (
    <Button
      type="button"
      variant="ghost"
      className="-ml-2 h-8 px-2"
      onClick={() => column.toggleSorting(column.getIsSorted() === "asc")}
    >
      {label}
      <ArrowUpDown />
    </Button>
  )
}

// 渲染用户状态徽标。
function UserStatusBadge({ status }: { status: number }) {
  const t = useTranslations("users")
  const disabled = status === UserStatusEnum.DISABLE
  const Icon = disabled ? IconCircleXFilled : IconCircleCheckFilled
  const text = disabled ? t("disabled") : t("active")

  return (
    <Badge variant="outline" className="px-1.5 text-muted-foreground">
      <Icon className={disabled ? "fill-red-500" : "fill-green-500 dark:fill-green-400"} />
      {text}
    </Badge>
  )
}

// 创建带国际化文案的用户列表列配置。
export function useUserColumns({ onEdit, onToggleStatus, onDelete }: UserColumnsOptions): ColumnDef<UserVo>[] {
  const t = useTranslations("users")

  return [
    {
      id: "index",
      header: t("columns.index"),
      enableHiding: false,
      cell: ({ row }) => row.index + 1,
    },
    {
      accessorKey: "username",
      header: t("columns.username"),
      meta: {
        className: "w-1/3",
      },
    },
    {
      accessorKey: "type",
      header: t("columns.type"),
      cell: ({ row }) => {
        if (row.original.type === UserTypeEnum.ADMIN) {
          return t("admin")
        }

        if (row.original.type === UserTypeEnum.DEMO) {
          return t("demo")
        }

        return t("user")
      }
    },
    {
      accessorKey: "usedCapacity",
      meta: {
        label: t("columns.usedCapacity"),
      },
      header: ({ column }) => <SortableHeader label={t("columns.usedCapacity")} column={column} />,
      cell: ({ row }) => formatCapacity(row.original.usedCapacity),
    },
    {
      accessorKey: "photoTotal",
      meta: {
        label: t("columns.photoCount"),
      },
      header: ({ column }) => <SortableHeader label={t("columns.photoCount")} column={column} />,
    },
    {
      accessorKey: "status",
      header: t("columns.status"),
      cell: ({ row }) => <UserStatusBadge status={row.original.status} />,
    },
    {
      id: "actions",
      header: t("columns.actions"),
      enableHiding: false,
      meta: {
        className: "text-right",
      },
      cell: ({ row }) => (
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon-sm" aria-label="Open actions menu">
              <MoreHorizontal />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent>
            <DropdownMenuItem onClick={() => onEdit(row.original)}>{t("edit")}</DropdownMenuItem>
            <DropdownMenuItem onClick={() => onToggleStatus(row.original.userId)}>
              {row.original.status === UserStatusEnum.DISABLE ? t("enable") : t("disable")}
            </DropdownMenuItem>
            <DropdownMenuItem onClick={() => onDelete(row.original)}>{t("delete")}</DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      ),
    },
  ]
}
