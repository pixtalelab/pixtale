// 这个模块定义相册业务入参对象。

interface AlbumAddBo {
  name: string;
}

interface AlbumAddPhotoBo {
  albumIds: string[];
  photoIds: string[];
}

interface AlbumRemovePhotoBo {
  albumId: string;
  photoIds: string[];
}

interface AlbumDeleteBo {
  albumId: string;
}

interface AlbumRecycleBo {
  albumId: string;
}

interface AlbumSetNameBo {
  albumId: string;
  name: string;
}

interface AlbumSetTopBo {
  albumId: string;
}

interface AlbumSetPublicBo {
  albumId: string;
  public: number;
}

export type { AlbumAddBo, AlbumAddPhotoBo, AlbumDeleteBo, AlbumRecycleBo, AlbumRemovePhotoBo, AlbumSetNameBo, AlbumSetPublicBo, AlbumSetTopBo };
