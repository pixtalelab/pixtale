import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pixtale_sync/l10n/localizations.dart';
import 'package:pixtale_sync/models/rule.dart';
import 'package:pixtale_sync/providers/storage_provider.dart';
import 'package:pixtale_sync/services/storage_service.dart';
import 'package:pixtale_sync/services/rule_service.dart';
import 'package:pixtale_sync/services/user_service.dart';

/// 创建模板、追加规则或编辑已有规则。
class TemplateDialog extends StatefulWidget {
  const TemplateDialog({
    super.key,
    required this.service,
    required this.storageService,
    this.pid,
    this.item,
  });

  final RuleService service;
  final StorageService storageService;
  final String? pid;
  final RuleItem? item;

  @override
  State<TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends State<TemplateDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _minimum = TextEditingController();
  final _maximum = TextEditingController();
  late final _storages = StorageProvider(widget.storageService);
  RuleFileType _type = RuleFileType.any;
  bool _saving = false;
  bool _storageTouched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _minimum.text = (item.fileMinSize / (1024 * 1024))
          .toString()
          .replaceFirst(RegExp(r'\.0$'), '');
      _maximum.text = (item.fileMaxSize / (1024 * 1024))
          .toString()
          .replaceFirst(RegExp(r'\.0$'), '');
      _type = item.fileType;
      _storages.select(item.storageId);
      _storages.addListener(_restoreStorageSelection);
    }
    UserService.changes.addListener(_accountChanged);
    unawaited(_storages.load());
  }

  void _accountChanged() {
    if (mounted) Navigator.of(context).pop();
  }

  /// 缓存与远端列表先后返回时保留原存储，用户手动选择后不再覆盖。
  void _restoreStorageSelection() {
    final id = widget.item?.storageId;
    if (!_storageTouched &&
        id != null &&
        _storages.selectedId != id &&
        _storages.items.any((storage) => storage.id == id)) {
      _storages.select(id);
    }
  }

  @override
  void dispose() {
    UserService.changes.removeListener(_accountChanged);
    _storages.removeListener(_restoreStorageSelection);
    _storages.dispose();
    _name.dispose();
    _minimum.dispose();
    _maximum.dispose();
    super.dispose();
  }

  int? _bytes(String text) {
    final value = double.tryParse(text.trim());
    if (value == null || !value.isFinite || value < 0) return null;
    final bytes = value * 1024 * 1024;
    if (!bytes.isFinite || bytes > 9007199254740991) return null;
    return bytes.round();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final storage = _storages.selected;
    if (storage == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final item = widget.item;
      final pid = widget.pid;
      if (item != null) {
        await widget.service.updateItem(
          id: item.id,
          pid: item.pid,
          fileType: _type,
          fileMinSize: _bytes(_minimum.text)!,
          fileMaxSize: _bytes(_maximum.text)!,
          storageId: storage.id,
        );
      } else if (pid == null) {
        await widget.service.add(
          name: _name.text,
          fileType: _type,
          fileMinSize: _bytes(_minimum.text)!,
          fileMaxSize: _bytes(_maximum.text)!,
          storageId: storage.id,
        );
      } else {
        await widget.service.addItem(
          pid: pid,
          fileType: _type,
          fileMinSize: _bytes(_minimum.text)!,
          fileMaxSize: _bytes(_maximum.text)!,
          storageId: storage.id,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).actionFailed);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_saving,
      child: ListenableBuilder(
        listenable: _storages,
        builder: (context, _) => AlertDialog(
          title: Text(
            widget.item != null
                ? l10n.editTemplateItem
                : widget.pid == null
                ? l10n.addTemplate
                : l10n.addTemplateItem,
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.pid == null && widget.item == null) ...[
                      TextFormField(
                        controller: _name,
                        enabled: !_saving,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.templateName,
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? l10n.templateNameRequired
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(l10n.fileSizeRange),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _minimum,
                            enabled: !_saving,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: l10n.fileMinSize,
                              errorMaxLines: 3,
                            ),
                            validator: (value) => _bytes(value ?? '') == null
                                ? l10n.invalidFileSize
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _maximum,
                            enabled: !_saving,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: l10n.fileMaxSize,
                              errorMaxLines: 3,
                            ),
                            validator: (value) {
                              final maximum = _bytes(value ?? '');
                              if (maximum == null) return l10n.invalidFileSize;
                              final minimum = _bytes(_minimum.text);
                              if (minimum != null && maximum < minimum) {
                                return l10n.invalidFileRange;
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<RuleFileType>(
                      initialValue: _type,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l10n.fileType),
                      items: [
                        DropdownMenuItem(
                          value: RuleFileType.photo,
                          child: Text(l10n.fileTypePhoto),
                        ),
                        DropdownMenuItem(
                          value: RuleFileType.video,
                          child: Text(l10n.fileTypeVideo),
                        ),
                        DropdownMenuItem(
                          value: RuleFileType.any,
                          child: Text(l10n.fileTypeAny),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _type = value!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_storages.selectedId),
                      initialValue: _storages.selectedId,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l10n.storage),
                      hint: Text(l10n.noStorageAvailable),
                      items: [
                        for (final storage in _storages.items)
                          DropdownMenuItem(
                            value: storage.id,
                            child: Text(
                              storage.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) {
                              _storageTouched = true;
                              _storages.select(value);
                            },
                      validator: (_) => _storages.selected == null
                          ? l10n.chooseStorage
                          : null,
                    ),
                    if (_storages.error != null)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.loadStoragesFailed,
                              style: TextStyle(color: colors.error),
                            ),
                          ),
                          TextButton(
                            onPressed: _saving ? null : _storages.load,
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: colors.error)),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: _saving || _storages.selected == null ? null : _save,
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
