// 这个模块定义照片业务入参对象。

interface PhotoTakenDateListBo {
  favorite?: number | null;
  albumId?: string | null;
  // tzOffset 为相对 UTC 的偏移分钟数，东八区为 480。
  tzOffset: number;

}

interface PhotoListBo {
  size: number;
  cursorPhotoId?: string | null;
  cursorTime?: string | null;
  keyword?: string | null;
  searchType?: "photo" | "storage" | null;
  startTakenTime?: string | null;
  endTakenTime?: string | null;
  favorite?: number | null;
  status?: number | null;
  albumId?: string | null;

}

interface PhotoExistsBo {
  checksum: string;
  name: string;
}

interface PhotoRecycleBo {
  photoIds: string[];
}

interface PhotoFavoriteBo {
  photoIds: string[];
  favorite: number;
}

interface PhotoRestoreBo {
  photoIds: string[];

}

interface PhotoDeleteBo {
  photoIds: string[];
}



export type { PhotoDeleteBo, PhotoExistsBo, PhotoFavoriteBo, PhotoListBo, PhotoRecycleBo, PhotoRestoreBo, PhotoTakenDateListBo };

