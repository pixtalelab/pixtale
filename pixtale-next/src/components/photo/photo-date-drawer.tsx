"use client"

import { useEffect, useMemo, useRef, useState } from "react"
import { Clock4, XIcon } from "lucide-react"

import { Button } from "@/components/ui/button"
import {
  Drawer,
  DrawerClose,
  DrawerContent,
  DrawerTrigger,
} from "@/components/ui/drawer"
import { Slider } from "@/components/ui/slider"
import { getLocalTzOffsetMin } from "@/lib/date"
import { photoTakenDateList } from "@/request/photo"
import { type PhotoTakenDateVo } from "@/server/entity/vo/photo"
import { useTranslations } from "next-intl"

interface PhotoDateDrawerProps {
  // albumId 传入时按相册筛选时间范围。
  albumId?: string | null
  // favorite 传入时按收藏状态筛选时间范围。
  favorite?: number | null
  // onRangeChange 在时间范围确认变更后传给页面。
  onRangeChange?: (range: { startDate: Date, endDate: Date }) => void
}

// 把接口返回的日期字符串解析为本地日期。
function parseDate(date: string) {
  return new Date(`${date}T00:00:00`)
}

// 把日期归一到当天最后一毫秒，用于结束时间筛选。
function toDayEnd(date: Date) {
  const end = new Date(date)
  end.setHours(23, 59, 59, 999)
  return end
}

// 把日期格式化成页面展示文案，固定显示年月日。
function formatDate(date: Date) {
  return `${date.getFullYear()}/${date.getMonth() + 1}/${date.getDate()}`
}

// 渲染照片页按天选择时间范围的右侧抽屉。
function PhotoDateDrawer({ albumId, favorite, onRangeChange }: PhotoDateDrawerProps) {
  const t = useTranslations("photos")
  const [dateList, setDateList] = useState<PhotoTakenDateVo[]>([]) // dateList 保存存在照片的日期及照片数量。
  const [open, setOpen] = useState(false) // open 控制时间选择抽屉是否打开。
  const [savedDateRange, setSavedDateRange] = useState([0, 0]) // savedDateRange 保存上次确认的日期索引范围。
  const [dateRange, setDateRange] = useState([0, 0]) // dateRange 保存当前选中的开始和结束日期索引。
  const saveCloseRef = useRef(false) // saveCloseRef 记录本次关闭是否由点击遮罩保存触发。

  // 根据相册和收藏条件查询存在照片的日期，并初始化滑块区间。
  useEffect(() => {
    photoTakenDateList({
      albumId,
      favorite,
      tzOffset: getLocalTzOffsetMin(),
    }).then((data) => {
      const fullRange = [0, Math.max(0, data.length - 1)]

      setDateList(data)
      setDateRange(fullRange)
      setSavedDateRange(fullRange)
    })
  }, [albumId, favorite])

  // 切换抽屉打开状态，非保存关闭时恢复到上次确认的时间范围。
  function changeOpen(nextOpen: boolean) {
    setOpen(nextOpen)

    if (nextOpen) {
      setDateRange(savedDateRange)
    } else if (!saveCloseRef.current) {
      setTimeout(() => {
        setDateRange(savedDateRange)
      }, 300)
    }

    saveCloseRef.current = false
  }

  // 点击遮罩关闭时，仅在时间范围发生变化时回调给页面。
  function saveRange() {
    saveCloseRef.current = true

    if (!dateList.length ||
      (dateRange[0] === savedDateRange[0] && dateRange[1] === savedDateRange[1])) {
      return
    }

    setSavedDateRange(dateRange)
    onRangeChange?.({
      startDate: parseDate(dateList[dateRange[0]].date),
      endDate: toDayEnd(parseDate(dateList[dateRange[1]].date)),
    })
  }

  const maxDateIndex = Math.max(0, dateList.length - 1)
  const startPosition = maxDateIndex ? dateRange[0] / maxDateIndex * 100 : 0
  const endPosition = maxDateIndex ? dateRange[1] / maxDateIndex * 100 : 0
  const yearMarks = useMemo(() => {
    const marks: { year: string, position: number }[] = []

    // 日期已经按升序排列，每个年份第一次出现的位置就是该年的起始刻度。
    for (const [index, item] of dateList.entries()) {
      const year = item.date.slice(0, 4)

      if (marks.at(-1)?.year !== year) {
        marks.push({
          year,
          position: maxDateIndex ? index / maxDateIndex * 100 : 0,
        })
      }
    }

    return marks.filter((mark) => mark.position > 0 && mark.position < 100)
  }, [dateList, maxDateIndex])

  return (
    <Drawer direction="right" handleOnly open={open} onOpenChange={changeOpen}>
      <DrawerTrigger asChild>
        <Button
          type="button"
          size="icon"
          variant="ghost"
        >
          <Clock4 />
        </Button>
      </DrawerTrigger>
      <DrawerContent
        className="h-dvh !w-38 md:!w-35 !rounded-none pr-9 md:pr-6 pb-8 pt-15 sm:max-w-none"
        onPointerDownOutside={saveRange}
      >
        <div className="absolute top-4 left-4">{t("selectDateRange")}</div>
        <DrawerClose asChild>
          <Button
            type="button"
            variant="ghost"
            size="icon-sm"
            className="absolute top-3 right-6 md:right-3"
          >
            <XIcon />
            <span className="sr-only">Close</span>
          </Button>
        </DrawerClose>
        <div className="relative h-full min-h-0 w-full">
          {yearMarks.map((mark) => (
            <div
              key={mark.year}
              className="pointer-events-none absolute right-0 flex translate-y-1/2 items-center gap-1 text-xs text-muted-foreground"
              style={{ bottom: `${mark.position}%` }}
            >
              <span className="pr-2">{mark.year}</span>
              <span className="h-px w-3 bg-border" />
            </div>
          ))}
          <span
            className="absolute right-6 z-10 translate-y-1/2 whitespace-nowrap rounded-md bg-muted px-2 py-1 text-xs text-muted-foreground"
            style={{ bottom: `${endPosition}%` }}
          >
            {dateList.length ? formatDate(parseDate(dateList[dateRange[1]].date)) : "-"}
          </span>
          <Slider
            className="absolute right-0 h-full"
            orientation="vertical"
            disabled={!dateList.length}
            min={0}
            max={maxDateIndex}
            step={1}
            value={dateRange}
            onValueChange={(value) => setDateRange([value[0] ?? 0, value[1] ?? maxDateIndex])}
          />
          <span
            className="absolute right-6 z-9 translate-y-1/2 whitespace-nowrap rounded-md bg-muted px-2 py-1 text-xs text-muted-foreground"
            style={{ bottom: `${startPosition}%` }}
          >
            {dateList.length ? formatDate(parseDate(dateList[dateRange[0]].date)) : "-"}
          </span>
        </div>
      </DrawerContent>
    </Drawer>
  )
}

export { PhotoDateDrawer }
