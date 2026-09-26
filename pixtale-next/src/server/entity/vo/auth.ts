// 这个模块定义登录鉴权缓存对象。

interface AuthInfo {
  userId: string
  username: string
  avatar: string
  type: number
  // 当前未过期的登录会话 uuid 列表。
  uuidList: string[]
}

export type { AuthInfo }
