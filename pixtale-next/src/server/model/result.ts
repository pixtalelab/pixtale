interface Response<T = unknown> {
  code: number;
  message: string;
  data?: T | null;
}

const result = {
  ok<T>(data?: T): Response<T> {
    return { code: 200, message: 'success', data: data ?? null };
  },
  fail(message: string, code: number = 500): Response {
    return { code, message };
  }
};

export default result;
