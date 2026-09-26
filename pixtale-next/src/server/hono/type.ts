// 这个模块定义 Hono 请求上下文中共享变量的类型。

interface HonoEnv {
  Variables: {
    locale: string;
    userId: string;
  };
}

export type { HonoEnv };
