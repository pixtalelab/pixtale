import cron from 'node-cron';
import { photoService } from '@/server/service/photo-service';

// 这个模块用 node-cron 定时清理过期回收站照片。

// 每 5 分钟执行一次过期回收站清理。
function clearExpiredPhotoTask() {
  cron.schedule('*/5 * * * *', () => {
    void photoService.clearExpired().catch((err) => {
      console.error('[task] clearExpired 失败', err);
    });
  });
}

export { clearExpiredPhotoTask };
