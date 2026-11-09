import 'package:flutter/material.dart';
import 'package:pixtale_sync/l10n/localizations.dart';
import 'package:pixtale_sync/models/rule.dart';
import 'package:pixtale_sync/services/rule_service.dart';
import 'package:pixtale_sync/services/user_service.dart';

/// 只编辑模板名称，不修改模板下的规则。
class TemplateNameDialog extends StatefulWidget {
  const TemplateNameDialog({
    super.key,
    required this.template,
    required this.service,
  });

  final Rule template;
  final RuleService service;

  @override
  State<TemplateNameDialog> createState() => _TemplateNameDialogState();
}

class _TemplateNameDialogState extends State<TemplateNameDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.template.name);
  bool _saving = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    UserService.changes.addListener(_onAccountChanged);
  }

  void _onAccountChanged() {
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    UserService.changes.removeListener(_onAccountChanged);
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.service.rename(id: widget.template.id, name: _name.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(l10n.editTemplate),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _name,
                    enabled: !_saving,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _save(),
                    decoration: InputDecoration(labelText: l10n.templateName),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? l10n.templateNameRequired
                        : null,
                  ),
                  if (_failed) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.actionFailed,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
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
          TextButton(onPressed: _saving ? null : _save, child: Text(l10n.save)),
        ],
      ),
    );
  }
}
