// 这个模块定义携带消息和业务状态码的业务异常。

class BizError extends Error {
  code: number;

  // 创建等待全局错误处理器处理的业务异常。
  constructor(message: string, code: number = 501) {
    super(message);
    this.code = code;
    this.name = 'BizError';
  }
}

export default BizError;
