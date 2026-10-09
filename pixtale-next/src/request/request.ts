import { toast } from "sonner";

// 这个模块封装前端 HTTP 请求。

interface ApiResponse<T = unknown> {
  code: number;
  message: string;
  data?: T | null;
}

type RequestParams = object | FormData | null;

// 请求的可选配置，透传到 fetch 的 RequestInit 上。
interface RequestConfig extends RequestInit {
  priority?: "high" | "low";
  // 由调用方管理加载和失败提示时，关闭统一错误提示。
  showErrorToast?: boolean;
}

const MOCK_REQUEST_DELAY = 0;

// 等待指定毫秒数，用于模拟线上接口耗时。
function sleep(ms: number) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

// 拼接接口基础地址。
function buildUrl(url: string) {
  return url.startsWith('/api') ? url : `/api${url.startsWith('/') ? url : `/${url}`}`;
}

// 处理身份失效并跳转登录页。
function handleUnauthorized() {
  if (window.location.pathname !== '/auth') {
    window.location.replace('/auth');
  }
}

// 发送 POST 请求并返回接口 data。
async function post<T = unknown>(url: string, params: RequestParams = null, config?: RequestConfig) {
  const { showErrorToast = true, ...requestConfig } = config ?? {};
  const headers = new Headers();
  let body: BodyInit | null = null;

  if (params instanceof FormData) {
    body = params;
  } else if (params) {
    headers.set('Content-Type', 'application/json');
    body = JSON.stringify(params);
  }

  await sleep(MOCK_REQUEST_DELAY);

  // priority 属于当前 DOM 类型定义尚未覆盖的字段，与 config 一起合并进 RequestInit。
  const options: RequestInit & { priority?: "high" | "low" } = {
    method: 'POST',
    headers,
    body,
    credentials: 'include',
    ...requestConfig
  };
  try {
    const res = await fetch(buildUrl(url), options);
    // 网关可能返回 HTML 或空响应，不让 JSON 解析异常掩盖 HTTP 状态。
    const json = await res.json().catch(() => null) as ApiResponse<T> | null;

    if (res.status === 401 || json?.code === 401) {
      handleUnauthorized();
    }

    if (!res.ok || json?.code !== 200) {
      const message = json?.message || `Server error (HTTP ${res.status}${res.statusText ? ` ${res.statusText}` : ''})`;
      throw new Error(message);
    }

    return json.data as T;
  } catch (error) {
    const failure = error instanceof Error ? error : new Error('Request failed');
    if (showErrorToast) {
      toast.error(failure.message);
    }
    throw failure;
  }
}

const http = {
  // 发送 POST 请求。
  post<T = unknown>(url: string, params: RequestParams = null, config?: RequestConfig) {
    return post<T>(url, params, config);
  }
};

export { http };
export type { ApiResponse, RequestParams, RequestConfig };
