// 这个模块提供前端文件和存储容量相关工具方法。

// 格式化存储容量为易读文本。
function formatCapacity(size: number) {
  if (!size) {
    return "0 B"
  }

  const units = ["B", "KB", "MB", "GB", "TB"]
  const index = Math.min(Math.floor(Math.log(size) / Math.log(1024)), units.length - 1)
  const value = size / 1024 ** index

  return `${value.toFixed(index === 0 ? 0 : 1)} ${units[index]}`
}

export { formatCapacity }
