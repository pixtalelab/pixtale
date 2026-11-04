import { createWriteStream } from 'node:fs';
import { mkdtemp, rm, stat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import type { ReadableStream as NodeWebReadableStream } from 'node:stream/web';
import Busboy from 'busboy';
import { getMediaType } from '@/lib/media';
import BizError from '@/server/error/biz-error';

// 这个模块把 multipart 上传流式写入临时文件。

interface PhotoUpload {
  directory: string;
  path: string;
  name: string;
  size: number;
  type: string;
  lock: string;
  storageId: string;
  albumId: string;
  lastModified: number;
}

// 从文件名取出安全扩展名，临时文件不使用用户提供的路径。
function safeExtension(filename: string) {
  return filename.match(/(\.[a-z0-9]{1,8})$/i)?.[1]?.toLowerCase() ?? '';
}

// 解析上传请求，文件内容按块写入临时目录，文本字段单独收集。
async function readPhotoUploadRequest(request: Request): Promise<PhotoUpload> {
  const contentType = request.headers.get('content-type');
  const body = request.body;

  if (!contentType?.toLowerCase().includes('multipart/form-data') || !body) {
    throw new BizError('photo.selectRequired');
  }

  const directory = await mkdtemp(join(tmpdir(), 'pixtale-upload-'));
  const fields = new Map<string, string>();
  let saved: { path: string; name: string; type: string } | undefined;

  try {
    await new Promise<void>((resolve, reject) => {
      const busboy = Busboy({
        headers: { 'content-type': contentType },
        defParamCharset: 'utf8',
      });
      const source = Readable.fromWeb(body as NodeWebReadableStream<Uint8Array>);
      let pendingWrites = 0;
      let ended = false;
      let failed = false;

      const fail = (error: unknown) => {
        if (failed) {
          return;
        }

        failed = true;
        source.destroy();
        busboy.destroy();
        reject(error);
      };

      const finish = () => {
        if (!failed && ended && pendingWrites === 0) {
          resolve();
        }
      };

      busboy.on('field', (name, value) => {
        if (!fields.has(name)) {
          fields.set(name, value);
        }
      });

      busboy.on('file', (name, stream, info) => {
        if (name !== 'file' || saved) {
          stream.resume();
          return;
        }

        const filename = info.filename?.trim() || 'file';
        const path = join(directory, `file${safeExtension(filename)}`);
        saved = {
          path,
          name: filename,
          type: getMediaType({
            name: filename,
            type: info.mimeType || 'application/octet-stream',
          }),
        };
        pendingWrites += 1;

        pipeline(stream, createWriteStream(path)).then(() => {
          pendingWrites -= 1;
          finish();
        }, fail);
      });

      busboy.on('error', fail);
      busboy.on('close', () => {
        ended = true;
        finish();
      });
      source.on('error', fail);
      source.pipe(busboy);
    });

    if (!saved) {
      throw new BizError('photo.selectRequired');
    }

    const lastModified = Number(fields.get('lastModified') ?? 0);
    const { size } = await stat(saved.path);

    return {
      directory,
      path: saved.path,
      name: saved.name,
      size,
      type: saved.type,
      lock: (fields.get('lock') ?? '').trim(),
      storageId: (fields.get('storageId') ?? '').trim(),
      albumId: (fields.get('albumId') ?? '').trim(),
      lastModified: Number.isFinite(lastModified) ? lastModified : 0,
    };
  } catch (error) {
    await rm(directory, { recursive: true, force: true });
    throw error;
  }
}

export type { PhotoUpload };
export { readPhotoUploadRequest };
