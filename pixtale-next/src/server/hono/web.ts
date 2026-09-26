import './hono';

import '../api/album-api'
import '../api/photo-api'
import '../api/storage-api'
import '../api/user-api'
import '../api/login-api'
import '../api/setting-api'
import '../api/sync-api'
import '../api/dashboard-api'

// 这个模块汇总注册 Web 接口所需的中间件和 API 路由。

export { app } from './hono';
