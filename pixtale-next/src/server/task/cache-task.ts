import cron from 'node-cron';
import { cache } from '@/server/infra/cache';

// 这个模块用 node-cron 定时清理过期缓存。

// 每 10 分钟执行一次过期缓存清理。
function clearExpiredCacheTask() {
  cron.schedule('*/10 * * * *', () => {
    void cache.clearExpired().catch((err) => {
      console.error('[task] clearExpiredCache failed', err);
    });
  });
}

export { clearExpiredCacheTask };
