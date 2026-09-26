import { useEffect, useRef } from "react"

const MOBILE_TAP_DELAY_MS = 50

// 为 Lightbox 内操作按钮生成事件：移动端 pointerup 延迟触发，PC / 键盘用 click。
export function useTapAction(action: () => void) {
  // touchHandledRef 标记触摸已在 pointerup 处理，避免合成 click 重复触发。
  const touchHandledRef = useRef(false)
  // touchTimerRef 保存移动端延迟触发的定时器，便于重复触摸时取消上一次。
  const touchTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  useEffect(() => {
    return () => {
      if (touchTimerRef.current) {
        clearTimeout(touchTimerRef.current)
      }
    }
  }, [])

  // 移动端抬起后延迟执行，错开 ghost click，避免误触刚出现的 UI。
  function onPointerUp(event: React.PointerEvent<HTMLButtonElement>) {
    if (event.pointerType !== "touch") {
      return
    }
    event.preventDefault()
    touchHandledRef.current = true
    if (touchTimerRef.current) {
      clearTimeout(touchTimerRef.current)
    }
    touchTimerRef.current = setTimeout(() => {
      touchTimerRef.current = null
      action()
    }, MOBILE_TAP_DELAY_MS)
  }

  // PC 鼠标与键盘走 click；触摸已在 pointerup 处理则跳过。
  function onClick(event: React.MouseEvent<HTMLButtonElement>) {
    if (touchHandledRef.current) {
      touchHandledRef.current = false
      return
    }
    action()
  }

  return { onPointerUp, onClick }
}
