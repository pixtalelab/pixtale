// 这个模块提供照片存储路径生成方法。

// 把拍摄时间格式化成 YYYY-MM-DD 目录名。
function formatPhotoDate(takenTime: string): string {
  return takenTime.slice(0, 10);
}

// 生成原图存储路径：photos/userId/文件名。
function buildPhotoKey(userId: string, fileName: string): string {
  return `photos/${userId}/${fileName}`;
}

// 按 userId 归档，再用 photoId 前四位分两级目录。
function buildDerivedImageKey(prefix: 'previews' | 'thumbnails', userId: string, photoId: string, ext: string): string {
  return `${prefix}/${userId}/${photoId.slice(0, 2)}/${photoId.slice(2, 4)}/${photoId}${ext}`;
}

// 生成高清图存储路径。
function buildPreviewKey(userId: string, photoId: string): string {
  return buildDerivedImageKey('previews', userId, photoId, '.jpg');
}

// 生成缩略图存储路径。
function buildThumbnailKey(userId: string, photoId: string): string {
  return buildDerivedImageKey('thumbnails', userId, photoId, '.webp');
}

export { buildPhotoKey, buildPreviewKey, buildThumbnailKey, formatPhotoDate };
