import { thumbHashToDataURL } from "thumbhash"
import { usePhotoStore } from "@/store/photo-store"

// 这个模块提供 thumbHash 解码与背景图地址转换方法。

// 把 thumbHash hex 字符串还原成 Uint8Array。
function decodeThumbHash(thumbHash: string) {
  return Uint8Array.from(thumbHash.match(/.{1,2}/g)?.map((byte) => Number.parseInt(byte, 16)) ?? [])
}

// 优先读取缓存，未命中时把 thumbHash 转成背景图地址并缓存。
function getThumbHashUrl(thumbHash?: string | null) {
  if (!thumbHash) {
    return undefined
  }

  const cache = usePhotoStore.getState().thumbHashCache
  const cached = cache.get(thumbHash)
  if (cached !== undefined) {
    return cached
  }

  const url = thumbHashToDataURL(decodeThumbHash(thumbHash))
  cache.set(thumbHash, url)
  return url
}

export { decodeThumbHash, getThumbHashUrl }
