"use client"

import { useState, type ChangeEvent } from "react"
import { useRouter } from "next/navigation"
import { toast } from "sonner"
import { AppSidebar } from "@/components/layout/app-sidebar"
import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbList,
  BreadcrumbPage,
} from "@/components/ui/breadcrumb"
import { Separator } from "@/components/ui/separator"
import { Button } from "@/components/ui/button"
import {
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
  InputGroupText,
} from "@/components/ui/input-group"
import {
  SidebarProvider,
  SidebarInset,
  SidebarTrigger,
} from "@/components/ui/sidebar"

import { Switch } from "@/components/ui/switch"
import { useApp } from "@/app/(main)/provider"
import { useSettingContext } from "./provider"
import { SettingItem } from "@/components/setting/setting-item"
import { settingSet } from "@/request/setting"
import { type Setting } from "@/server/entity/setting"
import {
  SettingPhotoDedupEnum,
  SettingPublicAlbumEnum,
  SettingListStyleEnum,
  SettingSyncDeleteEnum,
} from "@/server/enums/setting-enum"
import { useTranslations } from "next-intl"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"

export default function Page() {
  const t = useTranslations("settings")
  // router 用于保存设置后刷新服务端注入的网站名称。
  const router = useRouter()
  const { sidebarOpen, setSidebarOpen } = useApp()
  const { initialSetting } = useSettingContext()
  // setting 保存当前页面正在编辑的系统设置。
  const [setting, setSetting] = useState<Setting>(initialSetting)

  // 修改同步删除开关值。
  function changeSyncDelete(checked: boolean) {
    setSetting((prev) => ({
      ...prev,
      syncDelete: checked ? SettingSyncDeleteEnum.ENABLE : SettingSyncDeleteEnum.DISABLE,
    }))
  }

  // 修改公开相册开关值。
  function changePublicAlbum(checked: boolean) {
    setSetting((prev) => ({
      ...prev,
      publicAlbum: checked ? SettingPublicAlbumEnum.ENABLE : SettingPublicAlbumEnum.DISABLE,
    }))
  }

  // 修改照片去重开关值。
  function changePhotoDedup(checked: boolean) {
    setSetting((prev) => ({
      ...prev,
      photoDedup: checked ? SettingPhotoDedupEnum.ENABLE : SettingPhotoDedupEnum.DISABLE,
    }))
  }

  // 修改照片列表样式。
  function changeListStyle(value: string) {
    setSetting((prev) => ({
      ...prev,
      listStyle: Number(value),
    }))
  }

  // 修改回收站自动清理天数。
  function changeClearLast(event: ChangeEvent<HTMLInputElement>) {
    setSetting((prev) => ({
      ...prev,
      clearLast: Number(event.target.value || 0),
    }))
  }

  // 修改网站名称。
  function changeTitle(title: string) {
    setSetting((prev) => ({
      ...prev,
      title,
    }))
  }

  // 保存当前系统设置。
  function saveSetting() {
    settingSet(setting).then(() => {
      toast.success(t("saved"))
      router.refresh()
    })
  }

  return (
    <SidebarProvider open={sidebarOpen} onOpenChange={setSidebarOpen}>
      <AppSidebar />
      <SidebarInset>
        <header
          className="flex h-13 shrink-0 items-center justify-between gap-2 bg-background">
          <div className="flex min-w-0 items-center gap-2 px-4">
            <SidebarTrigger className="-ml-1" />
            <Separator
              orientation="vertical"
              className="mr-2 data-vertical:h-4 data-vertical:self-auto"
            />
            <Breadcrumb>
              <BreadcrumbList>
                <BreadcrumbItem>
                  <BreadcrumbPage>{t("title")}</BreadcrumbPage>
                </BreadcrumbItem>
              </BreadcrumbList>
            </Breadcrumb>
          </div>
        </header>
        <div className="mx-auto flex w-full max-w-5xl flex-col px-5 py-3 md:py-4">
          <h1 className="text-xl font-semibold pb-3 md:pb-4">{t("basicFeatures")}</h1>
          <Separator className="my-4" />
          <div className="flex flex-col">
            <SettingItem title={t("siteName")} description={t("siteNameDescription")}>
              <InputGroup className="w-40">
                <InputGroupInput
                  id="site-name"
                  type="text"
                  value={setting.title}
                  placeholder={t("siteNamePlaceholder")}
                  autoComplete="off"
                  onChange={(event) => changeTitle(event.target.value)}
                />
              </InputGroup>
            </SettingItem>
            <SettingItem title={t("scheduledCleanup")} description={t("scheduledCleanupDescription")}>
              <InputGroup className="w-40">
                <InputGroupInput
                  id="clear-last"
                  type="number"
                  min="0"
                  max="30"
                  className="[appearance:textfield] [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none"
                  value={setting.clearLast || ""}
                  onChange={changeClearLast}
                />
                <InputGroupAddon align="inline-end">
                  <InputGroupText>{t("days")}</InputGroupText>
                </InputGroupAddon>
              </InputGroup>
            </SettingItem>
            <SettingItem title={t("syncDelete")} description={t("syncDeleteDescription")}>
              <Switch
                checked={setting.syncDelete === SettingSyncDeleteEnum.ENABLE}
                onCheckedChange={changeSyncDelete}
              />
            </SettingItem>
            <SettingItem title={t("photoDeduplication")} description={t("photoDeduplicationDescription")}>
              <Switch
                checked={setting.photoDedup === SettingPhotoDedupEnum.ENABLE}
                onCheckedChange={changePhotoDedup}
              />
            </SettingItem>
            <SettingItem title={t("listStyle")} description={t("listStyleDescription")}>
              <Select value={String(setting.listStyle)} onValueChange={changeListStyle}>
                <SelectTrigger className="w-40" aria-label={t("listStyle")}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value={String(SettingListStyleEnum.MASONRY)}>
                    {t("masonry")}
                  </SelectItem>
                  <SelectItem value={String(SettingListStyleEnum.GRID)}>
                    {t("grid")}
                  </SelectItem>
                </SelectContent>
              </Select>
            </SettingItem>
            <SettingItem title={t("publicAlbum")} description={t("publicAlbumDescription")}>
              <Switch
                checked={setting.publicAlbum === SettingPublicAlbumEnum.ENABLE}
                onCheckedChange={changePublicAlbum}
              />
            </SettingItem>
          </div>
          <div className="mt-8 flex justify-end">
            <Button type="button" onClick={saveSetting}>
              {t("save")}
            </Button>
          </div>
        </div>
      </SidebarInset>
    </SidebarProvider>
  )
}
