import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pixtale_sync/l10n/localizations.dart';
import 'package:pixtale_sync/components/common/app_notice.dart';
import 'package:pixtale_sync/models/log.dart';
import 'package:pixtale_sync/services/log_service.dart';

// 按时间倒序展示同步事件，支持分页和清空记录。

/// 同步日志页面，进入时加载，保留后台页面的滚动状态。
class LogPage extends StatefulWidget {
  /// 创建日志页，可注入日志服务。
  const LogPage({super.key, this.active = true, this.logService});

  final bool active;
  final LogService? logService;

  /// 创建日志页面状态。
  @override
  State<LogPage> createState() => _LogPageState();
}

/// 管理日志查询和列表交互，不在页面直接读写数据库。
class _LogPageState extends State<LogPage> {
  /// 当前显示的日志和服务。
  final List<Log> _logs = [];
  late final LogService _service = widget.logService ?? LogService.instance;

  /// 当前结果筛选，默认显示全部。
  _LogFilter _filter = _LogFilter.all;

  /// 监听滚动加载下一页，以及已持久化的日志变化。
  final ScrollController _scroll = ScrollController();
  StreamSubscription<void>? _subscription;

  /// 加载、分页和错误状态。
  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  /// 丢弃刷新之前尚未完成的旧查询。
  int _revision = 0;

  /// 仅在日志页可见时读取记录。
  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _subscription = _service.changes.listen(_onLogsChanged);
    if (widget.active) unawaited(_load());
  }

  /// 重新切回日志页时更新列表。
  @override
  void didUpdateWidget(covariant LogPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) unawaited(_load());
  }

  /// 移除异步订阅和滚动监听。
  @override
  void dispose() {
    _subscription?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// 接近列表底部时分页加载，避免一次读取全部日志。
  void _onScroll() {
    if (_scroll.position.extentAfter < 300 &&
        !_loading &&
        _hasMore &&
        _error == null) {
      unawaited(_load(more: true));
    }
  }

  /// 日志写入或清空后静默更新可见列表。
  void _onLogsChanged(void _) {
    if (widget.active) unawaited(_load());
  }

  /// 清空记录，数据库通知会自动刷新列表。
  Future<void> _clear() async {
    try {
      await _service.clear();
    } catch (_) {
      if (!mounted) return;
      AppNotice.show(context, AppLocalizations.of(context).clearLogsFailed);
    }
  }

  /// 切换筛选后从第一页重新读取。
  Future<void> _selectFilter(_LogFilter filter) async {
    if (_filter == filter) return;
    setState(() {
      _filter = filter;
      _logs.clear();
      _hasMore = true;
      _error = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    await _load();
  }

  /// 打开或关闭筛选菜单。
  void _toggleFilterMenu(MenuController controller) {
    if (controller.isOpen) {
      controller.close();
    } else {
      controller.open();
    }
  }

  /// 分页读取或刷新当前已加载的数量，旧记录在刷新时继续展示。
  Future<void> _load({bool more = false}) async {
    if (more && (_loading || !_hasMore)) return;
    final revision = ++_revision;
    final limit = more ? 100 : math.max(100, _logs.length);
    final offset = more ? _logs.length : 0;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await _service.list(
        status: _filter.status,
        offset: offset,
        limit: limit,
      );
      if (!mounted || revision != _revision) return;
      setState(() {
        if (!more) _logs.clear();
        _logs.addAll(records);
        _hasMore = records.length == limit;
      });
    } catch (_) {
      if (mounted && revision == _revision) {
        setState(() => _error = AppLocalizations.of(context).loadLogsFailed);
      }
    } finally {
      if (mounted && revision == _revision) {
        setState(() => _loading = false);
      }
    }
  }

  /// 将保存的 UTC 时间转换为本地日期和时间。
  String _formatTime(DateTime value) {
    final time = value.toLocal();
    return '${time.month}/${time.day} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }

  /// 构建日志工具栏与三行日志列表。
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).logs),
        actions: [
          MenuAnchor(
            menuChildren: [
              for (final filter in _LogFilter.values)
                MenuItemButton(
                  onPressed: () => _selectFilter(filter),
                  trailingIcon: _filter == filter
                      ? const Icon(Icons.check, size: 18)
                      : const SizedBox(width: 18),
                  child: Text(filter.label(AppLocalizations.of(context))),
                ),
            ],
            builder: (context, controller, _) => IconButton(
              onPressed: () => _toggleFilterMenu(controller),
              icon: const Icon(Icons.sort),
            ),
          ),
          IconButton(
            onPressed: _logs.isEmpty ? null : _clear,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _error != null && _logs.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            )
          : ListView.separated(
              controller: _scroll,
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _logs.length + (_error == null ? 0 : 1),
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 0, endIndent: 0),
              itemBuilder: (context, index) {
                if (index == _logs.length) {
                  return TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: Text(_error!),
                  );
                }
                final log = _logs[index];
                return _LogRow(
                  key: ValueKey(log.id),
                  log: log,
                  time: _formatTime(log.createdAt),
                );
              },
            ),
    );
  }
}

/// 日志列表支持的结果筛选。
enum _LogFilter {
  all,
  success(status: LogStatus.success),
  failure(status: LogStatus.failure);

  /// 定义对应的数据库状态。全部不限制状态。
  const _LogFilter({this.status});

  final int? status;

  /// 当前语言下的筛选名称。
  String label(AppLocalizations l10n) => switch (this) {
    all => l10n.logFilterAll,
    success => l10n.logFilterSuccess,
    failure => l10n.logFilterFailure,
  };
}

/// 展示相册与时间、事件、状态标签与结果。
class _LogRow extends StatelessWidget {
  /// 创建只读日志行。
  const _LogRow({super.key, required this.log, required this.time});

  final Log log;
  final String time;

  /// 使用主题色和错误色区分成功、失败，并在右侧显示结果。
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final succeeded = log.status == LogStatus.success;
    final statusColor = succeeded
        ? theme.colorScheme.primary
        : theme.colorScheme.error;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  log.albumName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                time,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            log.event,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  child: Text(
                    log.status == LogStatus.success
                        ? AppLocalizations.of(context).logStatusSuccess
                        : AppLocalizations.of(context).logStatusFailure,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: succeeded
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onError,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  log.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
