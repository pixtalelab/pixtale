import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pixtale_sync/l10n/localizations.dart';
import 'package:pixtale_sync/components/common/app_notice.dart';
import 'package:pixtale_sync/db/database_path.dart';
import 'package:pixtale_sync/models/settings.dart';
import 'package:path/path.dart' as path;
import 'package:pixtale_sync/models/user.dart';
import 'package:pixtale_sync/providers/sync_provider.dart';
import 'package:pixtale_sync/l10n/locale.dart';
import 'package:pixtale_sync/services/settings_service.dart';
import 'package:pixtale_sync/services/user_service.dart';

// 设置页面：账户展示、退出登录和应用设置。

/// 设置页面。
/// 展示用户账户和应用功能设置。
class SettingsPage extends StatefulWidget {
  /// 创建设置页面。
  const SettingsPage({super.key, this.sync, this.userService});

  /// 与任务页共用的同步状态。修改并发时停止并重新启动。
  final SyncProvider? sync;

  /// 当前登录会话及头像服务。
  final UserService? userService;

  /// 创建设置页面状态。
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

/// 加载并保存用户信息及应用设置。
class _SettingsPageState extends State<SettingsPage> {
  late final _users = widget.userService ?? UserService.instance;
  User? _user;

  /// 当前头像图片，先展示数据库缓存，再静默刷新。
  Uint8List? _avatar;
  Settings? _settings;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    UserService.changes.addListener(_onUserChanged);
    _load();
  }

  @override
  void dispose() {
    UserService.changes.removeListener(_onUserChanged);
    super.dispose();
  }

  /// 登录或登录失效后重新读取本地用户。
  void _onUserChanged() {
    unawaited(_load());
  }

  /// 优先展示本地用户与头像，再异步刷新头像图片。
  Future<void> _load() async {
    User? user;
    Settings settings = const Settings(
      taskInterval: 10,
      logMaxCount: 500,
      taskStatus: 2,
      uploadConcurrency: 1,
    );
    try {
      user = await _users.get();
      settings = await SettingsService.instance.get();
    } on StateError {
      // 测试或数据库尚未初始化时仍展示可用的默认设置。
    }
    if (!mounted) return;
    setState(() {
      _user = user;
      _avatar = user?.avatarBytes;
      _settings = settings;
      _loading = false;
    });
    if (user != null) _refreshAvatar(user);
  }

  /// 更新头像时保留旧图片，页面退出或用户变化后丢弃结果。
  Future<void> _refreshAvatar(User user) async {
    try {
      final bytes = await _users.refreshAvatar(user);
      if (!mounted || !identical(_user, user) || identical(_avatar, bytes)) {
        return;
      }
      if (bytes != null) setState(() => _avatar = bytes);
    } catch (_) {
      // 网络不可用时继续使用已缓存的头像。
    }
  }

  /// 展示当前账户，并在确认后停止同步、清除登录会话。
  Future<void> _openUserCard() async {
    final user = _user;
    if (user == null) return;

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.account),
          content: Text(l10n.signedInAs(user.username)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.signOut),
            ),
          ],
        );
      },
    );
    if (shouldLogout == true) {
      await widget.sync?.stop();
      await _users.logout();
      if (mounted) {
        setState(() {
          _user = null;
          _avatar = null;
        });
      }
    }
  }

  /// 展示后台同步常见问题，提示用户手动调整手机省电策略。
  Future<void> _showInfo() async {
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      requestFocus: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsFaqTitle),
        content: Text(l10n.settingsFaqDescription),
        scrollable: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF0A0A0A),
            ),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _updateSettings(Settings next) async {
    final current = _settings;
    if (current == null) return;
    if (next.taskInterval != current.taskInterval) {
      await SettingsService.instance.updateTaskInterval(next.taskInterval);
    }
    if (next.logMaxCount != current.logMaxCount) {
      await SettingsService.instance.updateLogMaxCount(next.logMaxCount);
    }
    if (next.uploadConcurrency != current.uploadConcurrency) {
      await SettingsService.instance.updateUploadConcurrency(
        next.uploadConcurrency,
      );
    }
    if (next.locale != current.locale) {
      await AppLocale.instance.setCode(next.locale);
    }
    if (mounted) setState(() => _settings = next);
    if (next.uploadConcurrency != current.uploadConcurrency) {
      await _restartSync();
    }
  }

  /// 同步正在进行时先停止，再按新的上传设置重新启动。
  Future<void> _restartSync() async {
    final sync = widget.sync;
    if (sync == null || !sync.active || sync.stopping) return;
    // 弹窗 pop 早于关闭动画结束，延后重启避免和转场争用主线程。
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted || !sync.active || sync.stopping) return;
    await sync.stop();
    if (!sync.active) unawaited(sync.start());
  }

  String _endpointLabel(String endpoint) {
    final uri = Uri.tryParse(endpoint);
    return uri?.host.isNotEmpty == true ? uri!.host : endpoint;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        actions: [
          IconButton(
            onPressed: _showInfo,
            tooltip: l10n.settingsFaqTitle,
            icon: const Icon(Icons.info_outline),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(top: 16, bottom: 24),
              children: [
                if (_user != null)
                  _UserCard(
                    user: _user!,
                    avatar: _avatar,
                    endpointLabel: _endpointLabel(_user!.endpoint),
                    onTap: _openUserCard,
                  ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    AppLocalizations.of(context).preferences,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                if (_settings != null)
                  _SettingsCard(
                    settings: _settings!,
                    onChanged: _updateSettings,
                  ),
              ],
            ),
    );
  }
}

/// 以平铺列表项展示头像、用户名和服务端点。
class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.avatar,
    required this.endpointLabel,
    required this.onTap,
  });

  final User user;
  final Uint8List? avatar;
  final String endpointLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final placeholder = const Icon(Icons.person);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.grey.shade300,
                foregroundColor: Theme.of(context).colorScheme.primary,
                child: avatar == null
                    ? placeholder
                    : ClipOval(
                        child: Image.memory(
                          avatar!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => placeholder,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      endpointLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 以带分隔线的列表展示应用功能设置。
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.settings, required this.onChanged});

  final Settings settings;
  final ValueChanged<Settings> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          _SettingRow(
            icon: Icons.cloud_outlined,
            label: l10n.uploadConcurrency,
            value: '${settings.uploadConcurrency}',
            onTap: () async {
              final value = await _showIntegerEditor(
                context,
                title: l10n.uploadConcurrency,
                initialValue: settings.uploadConcurrency,
                min: 1,
                max: 20,
              );
              if (value != null) {
                onChanged(settings.copyWith(uploadConcurrency: value));
              }
            },
          ),
          const Divider(height: 1),
          _SettingRow(
            icon: Icons.schedule_outlined,
            label: l10n.syncInterval,
            value: settings.taskInterval == 0
                ? l10n.off
                : l10n.minutes(settings.taskInterval),
            onTap: () async {
              final value = await _showIntegerEditor(
                context,
                title: l10n.syncInterval,
                initialValue: settings.taskInterval,
                min: 0,
              );
              if (value != null) {
                onChanged(settings.copyWith(taskInterval: value));
              }
            },
          ),
          const Divider(height: 1),
          _SettingRow(
            icon: Icons.receipt_long_outlined,
            label: l10n.logRetention,
            value: l10n.logRetentionValue(settings.logMaxCount),
            onTap: () async {
              final value = await _showIntegerEditor(
                context,
                title: l10n.logRetention,
                initialValue: settings.logMaxCount,
                min: 10,
                max: 1000,
              );
              if (value != null) {
                onChanged(settings.copyWith(logMaxCount: value));
              }
            },
          ),
          const Divider(height: 1),
          _SettingRow(
            icon: Icons.language_outlined,
            label: l10n.language,
            value: _languageLabel(l10n, settings.locale),
            onTap: () async {
              final value = await _showLanguagePicker(
                context,
                current: settings.locale,
              );
              if (value == null) return;
              // 弹窗 pop 早于关闭动画结束，延后切换避免和转场争用主线程。
              await Future<void>.delayed(const Duration(milliseconds: 300));
              if (!context.mounted) return;
              onChanged(settings.copyWith(locale: value));
            },
          ),
          const Divider(height: 1),
          if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) ...[
            _SettingRow(
              icon: Icons.folder_open_outlined,
              label: l10n.dataFolder,
              value: l10n.open,
              onTap: () => _openDataDirectory(context),
            ),
            const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

String _languageLabel(AppLocalizations l10n, String locale) {
  return switch (locale) {
    'zh' => l10n.languageChinese,
    'en' => l10n.languageEnglish,
    _ => l10n.languageSystem,
  };
}

/// 弹出语言列表，点选后立即返回。
Future<String?> _showLanguagePicker(
  BuildContext context, {
  required String current,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _LanguageDialog(current: current),
  );
}

/// 语言选择弹窗。选项名用各自语言，避免切错后看不懂。
class _LanguageDialog extends StatelessWidget {
  const _LanguageDialog({required this.current});

  final String current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.language),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in [
            ('', l10n.languageSystem),
            ('zh', l10n.languageChinese),
            ('en', l10n.languageEnglish),
          ])
            RadioListTile<String>(
              title: Text(option.$2),
              value: option.$1,
              groupValue: current,
              onChanged: (value) => Navigator.pop(context, value),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

/// 在系统文件管理器中打开桌面端数据库所在目录。
Future<void> _openDataDirectory(BuildContext context) async {
  try {
    final databaseFile = await prepareDesktopDatabase(
      await desktopDatabaseDirectory(),
    );
    final directory = path.dirname(databaseFile);
    if (Platform.isWindows) {
      await Process.run('explorer', [directory]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [directory]);
    } else {
      await Process.run('xdg-open', [directory]);
    }
  } catch (_) {
    if (context.mounted) {
      AppNotice.show(
        context,
        AppLocalizations.of(context).cannotOpenDataFolder,
      );
    }
  }
}

/// 左侧显示图标，右侧显示设置名称及可选的当前值。
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    this.value,
    required this.onTap,
  });

  /// 设置项的语义图标。
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minLeadingWidth: 24,
      horizontalTitleGap: 20,
      leading: Icon(icon, size: 24, color: const Color(0xFF111111)),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(fontWeight: FontWeight.normal),
      ),
      subtitle: value == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                value!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
    );
  }
}

/// 弹出整数输入框并返回用户确认后的值。
Future<int?> _showIntegerEditor(
  BuildContext context, {
  required String title,
  required int initialValue,
  required int min,
  int? max,
  String? suffixText,
}) async {
  return showDialog<int>(
    context: context,
    requestFocus: false,
    builder: (context) => _IntegerEditorDialog(
      title: title,
      initialValue: initialValue,
      min: min,
      max: max,
      suffixText: suffixText,
    ),
  );
}

/// 承载设置整数值输入和校验的弹窗。
class _IntegerEditorDialog extends StatefulWidget {
  const _IntegerEditorDialog({
    required this.title,
    required this.initialValue,
    required this.min,
    this.max,
    this.suffixText,
  });

  final String title;
  final int initialValue;
  final int min;
  final int? max;
  final String? suffixText;

  @override
  State<_IntegerEditorDialog> createState() => _IntegerEditorDialogState();
}

/// 管理整数设置输入框的校验状态。
class _IntegerEditorDialogState extends State<_IntegerEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initialValue}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, int.parse(_controller.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: false,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).value,
            suffixText: widget.suffixText,
          ),
          onFieldSubmitted: (_) => _submit(),
          validator: (value) {
            final l10n = AppLocalizations.of(context);
            final parsed = int.tryParse(value?.trim() ?? '');
            if (parsed == null) return l10n.enterInteger;
            if (parsed < widget.min) return l10n.enterMinValue(widget.min);
            if (widget.max != null && parsed > widget.max!) {
              return l10n.enterMaxValue(widget.max!);
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(AppLocalizations.of(context).save),
        ),
      ],
    );
  }
}
