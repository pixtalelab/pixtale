import { http } from "@/request/request";
import { type LoginBo } from "@/server/entity/bo/login";
import { type LoginVo } from "@/server/entity/vo/login";

// 这个模块封装登录相关接口请求。

// 使用用户名和密码登录。
export function login(params: LoginBo) {
  return http.post<LoginVo>('/login', params);
}

// 退出登录并清除服务端 Cookie。
export function logout() {
  return http.post<void>('/logout');
}
