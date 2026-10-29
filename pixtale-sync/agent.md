# 项目概览

照片同步的 Flutter 客户端。图库服务端不在这个仓库。

# 目录结构

业务代码按类型放在 `lib/` 下。判断一个文件该去哪，看它是什么，不看它属于哪个功能。

```text
lib/
  main.dart          # 启动应用并配置根组件
  pages/             # 整页
  components/        # 可复用界面
    album/           # 相册选择
    common/          # 多处使用的界面
  models/            # 页面和 Service 共用的数据结构
  request/           # API 接口与统一网络请求
  services/          # 业务编排、本地存储
  db/                # 数据库连接与当前表结构
  providers/         # 页面状态
  theme/             # 颜色、字体、间距
  l10n/              # 文案与当前语言
assets/              # 图片等静态资源
packages/
  media_store/       # Android MediaStore 查询插件
```

## 放置规则

- `pages/`：占满一屏、由路由或底部导航打开的页面。文件名用 `*_page.dart`，类名以 `Page` 结尾，例如 `TaskPage`。`AppPage` 管理“任务 / 日志 / 设置”底部导航。
- `components/`：可复用或单独成篇的界面。多处使用的放 `common/`，相册选择放 `album/`。只被一个页面使用、篇幅不长的小组件留在该页面文件末尾。
- `models/`：页面和 `services/` 共用的字段类型，例如任务、相册、同步进度。只服务某一个接口的请求参数和响应类型放在对应的 `request/` 文件里，例如 `LoginParams`、`UserInfo`。
- `request/`：统一管理所有 API 接口的路径、请求参数组装、响应解析和上传协议；通用网络处理放在 `request.dart`。业务代码和页面不直接定义接口路径。
- `services/`：业务编排、读写本地数据，通过 `request/` 调用 API。不存放界面。方法要写明返回类型。
- `db/`：`db.dart` 打开 sqflite 连接。当前表结构集中在 `schema.dart` 的 `databaseSchema`，版本号是 `databaseVersion`，记在 `settings.schema_version`。已有表用 `IF NOT EXISTS` 跳过；给旧表补的列追加在建表语句后面。不使用 ORM，也不按版本拆迁移文件。查询和写入放在 Service，参数使用占位符绑定。记录类型放在 `models/`，使用与表名对应的单数名称（如 `task` 对应 `Task`）。任务通过 `album_id` 引用系统相册。
- `providers/`：页面要用的状态。改用 Bloc 或 Riverpod 时，仍放在这个目录。
- `theme/`：`ThemeData`、颜色和文字样式。
- `l10n/`：中文文案以 `zh.arb` 为模板，英文在 `en.arb`。生成结果是 `localizations.dart` 及各语言实现。当前语言由 `locale.dart` 保存。
- `main.dart`：启动前初始化前台同步、桌面端 SQLite、窗口和语言，再 `runApp`。根组件配置主题、语言和底部导航入口。
- `assets/`：静态资源。新增文件后在 `pubspec.yaml` 的 `flutter: assets` 里声明。
- `packages/media_store`：Android 上批量查询 MediaStore 的本地插件，由 `pubspec.yaml` 以 path 依赖引入。

# 页面代码规范

页面和组件按以下顺序组织，缺少的区域直接省略，不添加空区域：

1. 页面参数：构造函数、外部传入字段、`createState`。
2. 状态与依赖：状态变量、Service、控制器。
3. 派生数据：根据已有状态计算的 getter，不重复存储可计算的数据。
4. 生命周期：`initState`、`didUpdateWidget`、`dispose` 等。
5. 事件处理：点击、选择、提交等事件方法。
6. 内部方法：加载数据、数据转换、提示等辅助方法。
7. 页面渲染：`build` 放在当前页面类或 State 类的最后。
8. 私有组件：页面专用的小 Widget 放在文件末尾，构造函数和参数在前，`build` 在后。

区域之间用空行分隔，较长页面使用 `// 状态与依赖`、`// 生命周期`、`// 事件处理`、`// 内部方法`、`// 页面渲染`、`// 私有组件` 等简短注释。

统一遵守三条约定：

- 页面只处理交互和展示，SQL、持久化放在 Service。
- `build` 只组装界面，数据库读取等操作放在方法里，通过生命周期或事件触发；有逻辑的事件回调提取为方法。
- 篇幅不长的小组件先放在当前页面文件末尾。多处使用时放到 `components/common/`，相册选择放到 `components/album/`。明显拉长页面时再拆出去。

# 注释规范

- 每个方法都要写注释，说明用途。
- 在 Dart 文件中，紧跟在 `import` 之后添加文件说明，并空一行分隔。
- 为复杂的逻辑代码块添加行内注释。
- 在页面和组件内说明每个状态字段、控制器和关键变量的用途。

# 通用编码规范

- 变量名和组件名简短、避免过度抽象、过度工程化，减少非必要防御性代码，防止代码臃肿。
- 避免不必要的组件抽象。多处使用或明显拉长页面时再提取到 `components/`。

# 示例

任务相关代码分散在这些位置：

- `lib/pages/task_page.dart`
- `lib/services/task_service.dart`
- `lib/models/task.dart`
- `lib/theme/app_theme.dart`

同步相关代码分散在这些位置：

- `lib/services/sync_service.dart`
- `lib/services/foreground_sync_service.dart`
- `lib/services/sync_task_handler.dart`
- `lib/models/sync.dart`
- `lib/request/sync.dart`
