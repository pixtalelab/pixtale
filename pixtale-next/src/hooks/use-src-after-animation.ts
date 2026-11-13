import { useState } from "react"
import { useLightboxState } from "yet-another-react-lightbox"

// 滑动动画进行中保持当前图片地址，动画结束后再换成新地址。
function useSrcAfterAnimation<T>(src: T) {
  const { animation } = useLightboxState()
  // changing 表示轮播正在播放切换动画。
  const changing = Boolean(animation?.increment && animation.duration)
  // displaySrc 是当前写到图片上的地址。
  const [displaySrc, setDisplaySrc] = useState(src)

  if (!changing && displaySrc !== src) {
    setDisplaySrc(src)
  }

  return displaySrc
}

export { useSrcAfterAnimation }
