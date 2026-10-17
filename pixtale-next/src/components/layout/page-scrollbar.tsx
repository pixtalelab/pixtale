"use client"

import { useEffect } from "react"
import { OverlayScrollbars } from "overlayscrollbars"
import { useIsMobile } from "@/hooks/use-mobile"

// 桌面端替换页面滚动条，移动端保留原生滚动。
export function PageScrollbar() {
  const isMobile = useIsMobile()

  useEffect(() => {
    // 首次使用实时视口宽度，避免移动端初始状态尚未同步时短暂创建桌面滚动条。
    const shouldUseNativeScrollbar = isMobile || window.innerWidth < 768
    // 桌面端创建实例，移动端销毁实例并恢复原生滚动。
    let instance: ReturnType<typeof OverlayScrollbars> | undefined
    // 监听菜单、弹窗和照片查看器引起的页面滚动锁定变化。
    let scrollLockObserver: MutationObserver | undefined

    if (!shouldUseNativeScrollbar) {
      // 复用 body 作为视口，避免生成包裹层并保留 window 滚动。
      instance = OverlayScrollbars(
        {
          target: document.body,
          elements: {
            viewport: document.body,
          },
        },
        {
          scrollbars: {
            theme: "os-theme-page",
            autoHide: "leave",
            autoHideDelay: 800,
          },
        }
      )

      // 锁定状态会通过 html 的 :has 样式改变 overflow，需强制重新计算滚动条可见性。
      scrollLockObserver = new MutationObserver(() => {
        instance?.update(true)
      })
      scrollLockObserver.observe(document.body, {
        attributes: true,
        attributeFilter: ["data-scroll-locked", "class"],
      })
    }

    return () => {
      scrollLockObserver?.disconnect()
      instance?.destroy()
    }
  }, [isMobile])

  return null
}
