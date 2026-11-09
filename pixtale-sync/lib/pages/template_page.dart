import 'package:flutter/material.dart';
import 'package:pixtale_sync/components/common/app_notice.dart';
import 'package:pixtale_sync/components/template/template_card.dart';
import 'package:pixtale_sync/components/template/template_dialog.dart';
import 'package:pixtale_sync/components/template/template_name_dialog.dart';
import 'package:pixtale_sync/l10n/localizations.dart';
import 'package:pixtale_sync/models/rule.dart';
import 'package:pixtale_sync/services/storage_service.dart';
import 'package:pixtale_sync/services/rule_service.dart';
import 'package:pixtale_sync/services/user_service.dart';

/// 启动时预加载当前账户的模板，账户变化后重新加载。
class TemplatePage extends StatefulWidget {
  const TemplatePage({super.key, this.service, this.storageService});

  final RuleService? service;
  final StorageService? storageService;

  @override
  State<TemplatePage> createState() => _TemplatePageState();
}

class _TemplatePageState extends State<TemplatePage> {
  late final _service = widget.service ?? RuleService.instance;
  late final _storages = widget.storageService ?? StorageService();
  List<Rule> _templates = [];
  Map<String, String> _storageNames = {};
  bool _loaded = false;
  bool _failed = false;
  bool _dialogOpen = false;
  bool _editing = false;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    StorageService.changes.addListener(_onChanged);
    UserService.changes.addListener(_onAccountChanged);
    _reload();
  }

  @override
  void dispose() {
    StorageService.changes.removeListener(_onChanged);
    UserService.changes.removeListener(_onAccountChanged);
    super.dispose();
  }

  void _onChanged() {
    _reload();
  }

  void _onAccountChanged() {
    // 立即清掉旧账户内容，_reload 的版本号会丢弃旧查询。
    setState(() {
      _templates = [];
      _storageNames = {};
      _loaded = false;
      _failed = false;
    });
    _reload();
  }

  Future<void> _reload() async {
    final revision = ++_revision;
    // 加载与刷新都保持列表挂载，不闪烁、不丢滚动位置。
    setState(() => _failed = false);
    try {
      final templates = await _service.list();
      final storages = await _storages.list();
      if (!mounted || revision != _revision) return;
      setState(() {
        _templates = templates;
        _loaded = true;
        _storageNames = {
          for (final storage in storages) storage.id: storage.name,
        };
      });
    } catch (_) {
      if (mounted && revision == _revision) {
        if (_loaded) {
          AppNotice.show(
            context,
            AppLocalizations.of(context).loadTemplatesFailed,
          );
        } else {
          setState(() => _failed = true);
        }
      }
    }
  }

  Future<void> _add([String? pid, RuleItem? item]) async {
    if (_dialogOpen || _editing) return;
    setState(() => _dialogOpen = true);
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TemplateDialog(
        service: _service,
        storageService: _storages,
        pid: pid,
        item: item,
      ),
    );
    if (!mounted) return;
    setState(() => _dialogOpen = false);
    if (saved == true) await _reload();
  }

  Future<void> _onItemSelected(RuleItem item, TemplateItemAction action) async {
    if (_dialogOpen || _editing) return;
    if (action == TemplateItemAction.edit) {
      await _add(item.pid, item);
      return;
    }
    await _apply(() => _service.removeItem(id: item.id, pid: item.pid));
  }

  Future<void> _onTemplateSelected(Rule template, TemplateAction action) async {
    if (_dialogOpen || _editing) return;
    if (action == TemplateAction.edit) {
      setState(() => _dialogOpen = true);
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            TemplateNameDialog(template: template, service: _service),
      );
      if (!mounted) return;
      setState(() => _dialogOpen = false);
      if (saved == true) await _reload();
      return;
    }
    await _apply(
      () => action == TemplateAction.pin
          ? _service.pin(template.id)
          : _service.remove(template.id),
    );
  }

  Future<void> _apply(Future<void> Function() operation) async {
    setState(() => _editing = true);
    try {
      await operation();
      if (mounted) await _reload();
    } catch (_) {
      if (mounted) {
        AppNotice.show(context, AppLocalizations.of(context).actionFailed);
      }
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.templates),
        actions: [
          IconButton(
            onPressed: _dialogOpen || _editing ? null : () => _add(),
            tooltip: l10n.addTemplate,
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _failed
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.loadTemplatesFailed),
                  TextButton(onPressed: _reload, child: Text(l10n.retry)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _templates.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final template = _templates[index];
                return TemplateCard(
                  key: ValueKey(template.id),
                  template: template,
                  storageNames: _storageNames,
                  onAdd: _dialogOpen || _editing
                      ? null
                      : () => _add(template.id),
                  enabled: !_dialogOpen && !_editing,
                  onItemSelected: _onItemSelected,
                  onSelected: (action) => _onTemplateSelected(template, action),
                );
              },
            ),
    );
  }
}
