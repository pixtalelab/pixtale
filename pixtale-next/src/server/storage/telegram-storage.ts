import { type StorageObject, type StorageStrategy, type StorageUploadObject } from '@/server/storage/storage-types';
import { registerStorageStrategy } from '@/server/storage/storage-registry';
import { type Storage } from '@/server/entity/storage';
import { StorageTypeEnum } from '@/server/enums/storage-enum';
import { formatHttpUrl } from '@/lib/url';

// 这个模块实现 Telegram Bot 存储策略，代理地址暂不参与请求。

interface TelegramApiResponse<T> {
  ok: boolean;
  result?: T;
  description?: string;
}

interface TelegramMessage {
  document?: {
    file_id: string;
  };
}

interface TelegramFile {
  file_path?: string;
}

class TelegramStorageStrategy implements StorageStrategy {

  // 上传多个文件到 Telegram，并把 Telegram 文件信息写回文件 key。
  async put(files: StorageUploadObject[], storage: Storage): Promise<void> {
    const { token, chatId } = this.getConfig(storage);
    const formData = new FormData();

    const media = files.map((file, index) => {
      const fieldName = `file${index}`;
      const filename = this.getFilename(file);
      const document = new Blob([file.body], {
        type: file.type || 'application/octet-stream',
      });

      formData.append(fieldName, document, filename);

      return {
        type: 'document',
        media: `attach://${fieldName}`,
      };
    });

    formData.append('chat_id', chatId);
    formData.append('media', JSON.stringify(media));

    const messages = await this.callApi<TelegramMessage[]>(
      storage,
      token,
      'sendMediaGroup',
      formData,
    );

    messages.forEach((message, index) => {
      const fileId = message.document?.file_id;

      if (!fileId) {
        throw new Error('Telegram upload response is missing file information.');
      }

      files[index].key = fileId;
    });
  }

  // 从 Telegram 下载文件并返回媒体流。
  async get(key: string, storage: Storage): Promise<StorageObject> {
    const { token } = this.getConfig(storage);

    const file = await this.callApi<TelegramFile>(storage, token, 'getFile', new URLSearchParams({
      file_id: key,
    }));

    if (!file.file_path) {
      throw new Error('Telegram file path is empty.');
    }

    const domain = formatHttpUrl(storage.domain) || 'https://api.telegram.org';
    const response = await fetch(`${domain}/file/bot${token}/${file.file_path}`);

    if (!response.ok || !response.body) {
      throw new Error('Failed to read the file from Telegram.');
    }

    return {
      body: response.body,
      size: Number(response.headers.get('content-length') ?? 0),
      type: response.headers.get('content-type') ?? '',
    };
  }

  // Telegram 删除暂不执行，保留远端文件。
  async delete(key: string | string[], storage: Storage): Promise<void> {
    void key;
    void storage;
  }

  // 读取 Telegram 配置并校验必填项。
  private getConfig(storage: Storage): { token: string; chatId: string } {

    const token = storage.tgToken?.trim();
    const chatId = storage.tgChatId?.trim();

    if (!token) {
      throw new Error('Telegram Bot Token is required.');
    }

    if (!chatId) {
      throw new Error('Telegram Chat ID is required.');
    }

    return { token, chatId };
  }

  // 调用 Telegram Bot API 并返回接口结果。
  private async callApi<T>(storage: Storage, token: string, method: string, body?: BodyInit): Promise<T> {

    const domain = formatHttpUrl(storage.domain) || 'https://api.telegram.org';

    const response = await fetch(`${domain}/bot${token}/${method}`, {
      method: body ? 'POST' : 'GET',
      body,
    });

    const result = await response.json() as TelegramApiResponse<T>;

    if (!response.ok || !result.ok || result.result === undefined) {
      throw new Error(result.description || `Telegram API ${method} failed`);
    }

    return result.result;
  }

  // 从元数据读取上传文件名，并把 WebP 扩展名改为 JPEG。
  private getFilename(file: StorageUploadObject): string {
    const disposition = file.metadata?.find(([name]) => name.toLowerCase() === 'content-disposition')?.[1];
    const encodedName = disposition?.match(/filename\*=UTF-8''([^;]+)/i)?.[1];
    const filename = encodedName ? decodeURIComponent(encodedName) : 'file';

    return /\.webp$/i.test(filename)
      ? filename.replace(/\.webp$/i, '.jpeg')
      : filename;
  }
}

registerStorageStrategy(StorageTypeEnum.TELEGRAM, () => new TelegramStorageStrategy());

export { TelegramStorageStrategy };
