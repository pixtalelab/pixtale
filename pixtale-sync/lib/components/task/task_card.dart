import 'package:flutter/material.dart';
import 'package:pixtale_sync/l10n/localizations.dart';
import 'package:pixtale_sync/models/task_preview.dart';

// 任务列表中的相册卡片，展示封面、存储和同步进度。

/// 显示相册封面、名称、目标存储及同步张数。
class TaskCard extends StatelessWidget {
  /// 创建任务卡片。
  const TaskCard({
    super.key,
    required this.preview,
    required this.completed,
    required this.total,
    required this.storageName,
    required this.storageMissing,
    required this.syncing,
    required this.enabled,
    required this.onBlocked,
    required this.onSelected,
  });

  /// 相册及其封面信息。
  final TaskPreview preview;

  /// 已同步张数、本地总张数和存储名称。
  final int completed;
  final int total;
  final String storageName;
  final bool storageMissing;

  /// 当前相册正在核对或上传。
  final bool syncing;

  /// 是否允许打开菜单并执行操作。
  final bool enabled;

  /// 同步期间点击更多按钮时显示提示。
  final VoidCallback? onBlocked;

  /// 将菜单操作交给页面处理。
  final ValueChanged<TaskAction> onSelected;

  /// 再次点击更多按钮时关闭菜单。
  void _toggleMenu(MenuController controller) {
    if (controller.isOpen) {
      controller.close();
    } else {
      controller.open();
    }
  }

  /// 构建任务卡片。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final platform = Theme.of(context).platform;
    final desktop =
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
    final titleStyle = textTheme.titleMedium?.copyWith(
      fontWeight: desktop ? FontWeight.bold : FontWeight.w400,
      letterSpacing: 0,
    );
    final bodyStyle = textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    );
    final cardSize = preview.path == null ? 104.0 : 124.0;
    const itemStyle = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(180, 52)),
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
    );
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: cardSize,
        child: Row(
          children: [
            SizedBox(
              width: cardSize,
              height: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  preview.cover == null
                      ? ColoredBox(
                          color: colors.surfaceContainerHighest,
                          child: Icon(
                            Icons.photo_outlined,
                            color: colors.outline,
                          ),
                        )
                      : Image.memory(
                          preview.cover!,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                  if (syncing)
                    const Positioned(
                      right: 6,
                      bottom: 6,
                      child: _SyncIndicator(),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (preview.isInvalid) ...[
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.error,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Text(
                              l10n.unavailable,
                              style: textTheme.labelSmall?.copyWith(
                                color: colors.onError,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          preview.albumName.isEmpty
                              ? l10n.unnamedAlbum
                              : preview.albumName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ),
                      ),
                    ],
                  ),
                  if (preview.path != null && preview.path!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      preview.path!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bodyStyle?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    storageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bodyStyle?.copyWith(
                      color: storageMissing
                          ? colors.error
                          : colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          l10n.photoCount(
                            completed.clamp(0, total).toInt(),
                            total,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: bodyStyle,
                        ),
                      ),
                      if (total > 0 && completed.clamp(0, total) == total) ...[
                        const SizedBox(width: 6),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Text(
                              l10n.syncComplete,
                              style: textTheme.labelSmall?.copyWith(
                                color: colors.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 48,
              height: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MenuAnchor(
                    useRootOverlay: true,
                    clipBehavior: Clip.antiAlias,
                    style: MenuStyle(
                      alignment: AlignmentDirectional.bottomEnd,
                      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                      elevation: const WidgetStatePropertyAll(8),
                      backgroundColor: WidgetStatePropertyAll(
                        colors.surfaceContainer,
                      ),
                      shape: const WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                    ),
                    menuChildren: [
                      MenuItemButton(
                        onPressed: enabled
                            ? () => onSelected(TaskAction.edit)
                            : null,
                        style: itemStyle,
                        leadingIcon: const Icon(Icons.edit_outlined),
                        child: Text(l10n.edit),
                      ),
                      MenuItemButton(
                        onPressed: enabled
                            ? () => onSelected(TaskAction.pin)
                            : null,
                        style: itemStyle,
                        leadingIcon: const Icon(Icons.vertical_align_top),
                        child: Text(l10n.pinToTop),
                      ),
                      const Divider(height: 1, thickness: 1),
                      MenuItemButton(
                        onPressed: enabled
                            ? () => onSelected(TaskAction.remove)
                            : null,
                        style: itemStyle.copyWith(
                          backgroundColor: WidgetStatePropertyAll(colors.error),
                          foregroundColor: WidgetStatePropertyAll(
                            colors.onError,
                          ),
                          iconColor: WidgetStatePropertyAll(colors.onError),
                        ),
                        leadingIcon: const Icon(Icons.delete_outline),
                        child: Text(l10n.delete),
                      ),
                    ],
                    builder: (context, controller, _) => IconButton(
                      onPressed: enabled
                          ? () => _toggleMenu(controller)
                          : onBlocked,
                      icon: Icon(
                        Icons.more_vert,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 在当前相册封面显示旋转同步状态。
class _SyncIndicator extends StatefulWidget {
  /// 创建同步指示图标。
  const _SyncIndicator();

  /// 创建动画状态。
  @override
  State<_SyncIndicator> createState() => _SyncIndicatorState();
}

/// 随指示图标挂载和卸载管理旋转动画。
class _SyncIndicatorState extends State<_SyncIndicator>
    with SingleTickerProviderStateMixin {
  /// 持续匀速旋转的动画控制器。
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  /// 显示时开始旋转。
  @override
  void initState() {
    super.initState();
    _rotation.repeat();
  }

  /// 移除时释放动画。
  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  /// 构建封面上的同步状态图标。
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: SizedBox.square(
        dimension: 28,
        child: Center(
          child: RotationTransition(
            turns: _rotation,
            child: Icon(
              Icons.sync,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 卡片菜单支持的一次性操作。
enum TaskAction { edit, pin, remove }
