import 'package:flutter/material.dart';
import 'package:pixtale_sync/l10n/localizations.dart';
import 'package:pixtale_sync/models/rule.dart';
import 'package:timeline_tile/timeline_tile.dart';

/// 模板卡片，通过时间线按添加顺序展示规则的范围、类型和存储。
class TemplateCard extends StatelessWidget {
  const TemplateCard({
    super.key,
    required this.template,
    required this.storageNames,
    required this.onAdd,
    required this.onItemSelected,
    required this.onSelected,
    this.enabled = true,
  });

  final Rule template;
  final Map<String, String> storageNames;
  final VoidCallback? onAdd;
  final void Function(RuleItem, TemplateItemAction) onItemSelected;
  final ValueChanged<TemplateAction> onSelected;
  final bool enabled;

  String _size(int bytes) => (bytes / (1024 * 1024))
      .toStringAsFixed(6)
      .replaceFirst(RegExp(r'\.?0+$'), '');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    template.name,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                _menu(
                  context,
                  icon: Icons.more_vert,
                  onEdit: () => onSelected(TemplateAction.edit),
                  onPin: () => onSelected(TemplateAction.pin),
                  onDelete: () => onSelected(TemplateAction.remove),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < template.items.length; index++)
              TimelineTile(
                key: ValueKey(template.items[index].id),
                isFirst: index == 0,
                isLast: index == template.items.length - 1,
                indicatorStyle: IndicatorStyle(
                  width: 10,
                  color: colors.onSurfaceVariant,
                  padding: const EdgeInsets.only(right: 14),
                ),
                beforeLineStyle: LineStyle(
                  color: colors.outlineVariant,
                  thickness: 2,
                ),
                endChild: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 72),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _item(context, template.items[index]),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onAdd,
                child: Text(l10n.addTemplateItem),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, RuleItem item) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final type = switch (item.fileType) {
      RuleFileType.photo => l10n.fileTypePhoto,
      RuleFileType.video => l10n.fileTypeVideo,
      RuleFileType.any => l10n.fileTypeAny,
    };
    final storage = storageNames[item.storageId];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_size(item.fileMinSize)} - ${_size(item.fileMaxSize)} MB $type',
              ),
              const SizedBox(height: 4),
              Text(
                storage ?? l10n.storageUnavailable,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: storage == null
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        _menu(
          context,
          icon: Icons.settings_outlined,
          onEdit: () => onItemSelected(item, TemplateItemAction.edit),
          onDelete: () => onItemSelected(item, TemplateItemAction.remove),
        ),
      ],
    );
  }

  Widget _menu(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    VoidCallback? onPin,
  }) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    const itemStyle = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(180, 52)),
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
    );
    return MenuAnchor(
      useRootOverlay: true,
      clipBehavior: Clip.antiAlias,
      style: MenuStyle(
        alignment: AlignmentDirectional.bottomEnd,
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        elevation: const WidgetStatePropertyAll(8),
        backgroundColor: WidgetStatePropertyAll(colors.surfaceContainer),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      menuChildren: [
        MenuItemButton(
          onPressed: enabled ? onEdit : null,
          style: itemStyle,
          leadingIcon: const Icon(Icons.edit_outlined),
          child: Text(l10n.edit),
        ),
        if (onPin != null)
          MenuItemButton(
            onPressed: enabled ? onPin : null,
            style: itemStyle,
            leadingIcon: const Icon(Icons.vertical_align_top),
            child: Text(l10n.pinToTop),
          ),
        const Divider(height: 1, thickness: 1),
        MenuItemButton(
          onPressed: enabled ? onDelete : null,
          style: itemStyle.copyWith(
            backgroundColor: WidgetStatePropertyAll(colors.error),
            foregroundColor: WidgetStatePropertyAll(colors.onError),
            iconColor: WidgetStatePropertyAll(colors.onError),
          ),
          leadingIcon: const Icon(Icons.delete_outline),
          child: Text(l10n.delete),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        onPressed: enabled
            ? () {
                controller.isOpen ? controller.close() : controller.open();
              }
            : null,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, color: colors.onSurfaceVariant),
      ),
    );
  }
}

/// 单条模板规则的菜单操作。
enum TemplateItemAction { edit, remove }

/// 整张模板卡片的菜单操作。
enum TemplateAction { edit, pin, remove }
