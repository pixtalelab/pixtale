// 这个模块定义通用接口返回对象。

interface PageVo<T> {
  list: T[];
  total: number;
}

export type { PageVo };
