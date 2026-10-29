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
import 'package:pixtale_sync/services/auth_service.dart';
import 'package:pixtale_sync/services/settings_service.dart';
import 'package:pixtale_sync/services/user_service.dart';

// 设置页面：用户登录、账户展示和应用设置。

/// 设置页面。
/// 展示用户账户和应用功能设置。
class SettingsPage extends StatefulWidget {
  /// 创建设置页面。
  const SettingsPage({super.key, this.sync});

  /// 与任务页共用的同步状态。修改并发时用来停止并重新启动。
  final SyncProvider? sync;

  /// 创建设置页面状态。
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

/// 加载并保存用户信息及应用设置。
class _SettingsPageState extends State<SettingsPage> {
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
      user = await UserService.instance.get();
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
      final bytes = await UserService.instance.refreshAvatar(user);
      if (!mounted || !identical(_user, user) || identical(_avatar, bytes)) {
        return;
      }
      if (bytes != null) setState(() => _avatar = bytes);
    } catch (_) {
      // 网络不可用时继续使用已缓存的头像。
    }
  }

  /// 打开账户弹窗，并在登录或退出后更新用户与头像。
  Future<void> _openUserCard() async {
    if (_user == null) {
      final user = await showDialog<User>(
        context: context,
        builder: (_) => const _LoginDialog(),
      );
      if (user != null) {
        await UserService.instance.add(user);
        final saved = await UserService.instance.get();
        if (!mounted) return;
        setState(() {
          _user = saved;
          _avatar = saved?.avatarBytes;
        });
        if (saved != null) _refreshAvatar(saved);
      }
      return;
    }

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.account),
          content: Text(l10n.signedInAs(_user!.username)),
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
      await UserService.instance.remove(_user!.userId);
      if (mounted) {
        setState(() {
          _user = null;
          _avatar = null;
        });
      }
    }
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

  /// 同步正在进行时先停止，再按新的并发数重新启动。
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
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).settings)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(top: 16, bottom: 24),
              children: [
                _UserCard(
                  user: _user,
                  avatar: _avatar,
                  endpointLabel: _user == null
                      ? ''
                      : _endpointLabel(_user!.endpoint),
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

  final User? user;
  final Uint8List? avatar;
  final String endpointLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = user?.username ?? AppLocalizations.of(context).notSignedIn;
    final placeholder = Icon(
      user == null ? Icons.person_outline : Icons.person,
    );
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
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user == null
                          ? AppLocalizations.of(context).tapToSignIn
                          : endpointLabel,
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
      AppNotice.show(context, AppLocalizations.of(context).cannotOpenDataFolder);
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
      leading: Icon(
        icon,
        size: 24,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
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
}) async {
  return showDialog<int>(
    context: context,
    requestFocus: false,
    builder: (context) => _IntegerEditorDialog(
      title: title,
      initialValue: initialValue,
      min: min,
      max: max,
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
  });

  final String title;
  final int initialValue;
  final int min;
  final int? max;

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

/// 收集端点、用户名和密码的登录弹窗。
class _LoginDialog extends StatefulWidget {
  /// 创建登录弹窗。
  const _LoginDialog();

  /// 创建登录弹窗状态。
  @override
  State<_LoginDialog> createState() => _LoginDialogState();
}

/// 管理登录表单校验、提交和错误提示。
class _LoginDialogState extends State<_LoginDialog> {
  final _formKey = GlobalKey<FormState>();
  final _endpoint = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loggingIn = false;
  String? _error;

  @override
  void dispose() {
    _endpoint.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final endpoint = _endpoint.text.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(endpoint);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).invalidEndpoint);
      return;
    }
    setState(() {
      _loggingIn = true;
      _error = null;
    });
    try {
      final user = await const AuthService().login(
        endpoint: endpoint,
        username: _username.text.trim(),
        password: _password.text,
      );
      if (mounted) Navigator.pop(context, user);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  /// 移动端登录框左右各留 20 像素，桌面宽度设为 440 像素。
  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final mobile =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    return AlertDialog(
      insetPadding: mobile
          ? const EdgeInsets.symmetric(horizontal: 20, vertical: 24)
          : null,
      constraints: mobile
          ? BoxConstraints(minWidth: MediaQuery.sizeOf(context).width - 40)
          : const BoxConstraints(minWidth: 440, maxWidth: 440),
      title: Text(AppLocalizations.of(context).signIn),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _endpoint,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).endpoint,
                  hintText: 'https://example.com',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? AppLocalizations.of(context).enterEndpoint
                    : null,
              ),
              TextFormField(
                controller: _username,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).username,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? AppLocalizations.of(context).enterUsername
                    : null,
              ),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).password,
                ),
                validator: (value) => value == null || value.isEmpty
                    ? AppLocalizations.of(context).enterPassword
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loggingIn ? null : () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).cancel),
        ),
        FilledButton(
          onPressed: _loggingIn ? null : _login,
          child: _loggingIn
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppLocalizations.of(context).signIn),
        ),
      ],
    );
  }
}
