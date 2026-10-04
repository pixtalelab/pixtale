"use client"

import { useRef, useState, type FormEvent } from "react"
import { DatabaseIcon, Image, SearchIcon } from "lucide-react"
import { useTranslations } from "next-intl"

import { Button } from "@/components/ui/button"
import { Dialog } from "@/components/common/dialog"
import {
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
} from "@/components/ui/input-group"
import { Toggle } from "@/components/ui/toggle"

type PhotoSearchProps = {
  onSearch?: (value: string, type: "photo" | "storage") => void
}

// 渲染照片搜索按钮和搜索弹窗。
export function PhotoSearch({ onSearch }: PhotoSearchProps) {
  const t = useTranslations("photos")
  // open 控制搜索弹窗的打开状态。
  const [open, setOpen] = useState(false)
  // value 保存当前输入的照片搜索内容。
  const [value, setValue] = useState("")
  // searchType 保存当前搜索范围。
  const [searchType, setSearchType] = useState<"photo" | "storage">("photo")
  // lastSearchValue 保存最近一次已提交的搜索值，避免重复请求。
  const lastSearchValue = useRef("")
  // lastSearchType 保存最近一次已提交的搜索类型，避免类型变化时跳过请求。
  const lastSearchType = useRef<"photo" | "storage">("photo")

  // 打开照片搜索弹窗。
  function openSearch() {
    setOpen(true)
  }

  // 提交搜索内容，相同值不重复请求。
  function triggerSearch(searchValue: string) {
    if (searchValue === lastSearchValue.current && searchType === lastSearchType.current) {
      return
    }

    lastSearchValue.current = searchValue
    lastSearchType.current = searchType
    onSearch?.(searchValue, searchType)
  }

  // 提交照片搜索内容并关闭搜索弹窗。
  function submitSearch(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    triggerSearch(value.trim())
    setOpen(false)
  }

  // 清空当前搜索内容并关闭搜索弹窗。
  function clearSearch() {
    setValue("")
    triggerSearch("")
    setOpen(false)
  }

  // 关闭弹窗时提交当前搜索内容。
  function handleOpenChange(nextOpen: boolean) {
    if (!nextOpen) {
      triggerSearch(value.trim())
    }

    setOpen(nextOpen)
  }

  return (
    <>
      <Button
        type="button"
        size="icon"
        variant="ghost"
        onClick={openSearch}
      >
        <SearchIcon />
        <span className="sr-only">{t("search")}</span>
      </Button>
      <Dialog
        open={open}
        onOpenChange={handleOpenChange}
        preventMobileAutoFocus
        showFooter={false}
        showCloseButton={false}
        contentClassName="top-20 translate-y-0 p-4 lg:max-w-lg"
      >
          <form onSubmit={submitSearch}>
            <InputGroup className="h-10">
              <InputGroupAddon>
                <SearchIcon />
              </InputGroupAddon>
              <InputGroupInput
                value={value}
                onChange={(event) => setValue(event.target.value)}
                placeholder={t(searchType === "photo" ? "searchPhotoPlaceholder" : "searchStoragePlaceholder")}
              />
            </InputGroup>
            <div className="mt-3 flex gap-2" aria-label={t("searchType")}>
              <Toggle
                type="button"
                variant="outline"
                pressed={searchType === "photo"}
                onPressedChange={(pressed) => {
                  if (pressed) {
                    setSearchType("photo")
                  }
                }}
                aria-label={t("searchPhoto")}
              >
                <Image />
                {t("searchPhoto")}
              </Toggle>
              <Toggle
                type="button"
                variant="outline"
                pressed={searchType === "storage"}
                onPressedChange={(pressed) => {
                  if (pressed) {
                    setSearchType("storage")
                  }
                }}
                aria-label={t("searchStorage")}
              >
                <DatabaseIcon />
                {t("searchStorage")}
              </Toggle>
            </div>
            <div className="mt-3 flex justify-end gap-2">
              <Button
                type="button"
                variant="outline"
                onClick={clearSearch}
              >
                {t("clearSearch")}
              </Button>
              <Button
                type="submit"
                variant="default"
              >
                {t("search")}
              </Button>
            </div>
          </form>
      </Dialog>
    </>
  )
}
