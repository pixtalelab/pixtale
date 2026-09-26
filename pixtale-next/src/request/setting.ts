import { http } from "@/request/request";
import { type Setting } from "@/server/entity/setting";

// 这个模块封装系统设置相关接口请求。

// 覆盖写入整份系统设置。
export function settingSet(params: Setting) {
  return http.post<void>('/setting/set', params);
}
