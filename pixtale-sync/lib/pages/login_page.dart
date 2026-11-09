import 'package:flutter/material.dart';
import 'package:pixtale_sync/l10n/localizations.dart';
import 'package:pixtale_sync/services/auth_service.dart';

// 独立登录页面，登录完成后由应用根据账户变化切换到主界面。

/// 收集服务端点及登录凭证。
class LoginPage extends StatefulWidget {
  /// 创建可注入登录服务的页面。
  const LoginPage({super.key, this.authService});

  /// 登录及账户初始化服务。
  final AuthService? authService;

  /// 创建登录表单状态。
  @override
  State<LoginPage> createState() => _LoginPageState();
}

/// 管理登录表单校验、提交和错误提示。
class _LoginPageState extends State<LoginPage> {
  /// 表单校验状态及端点、用户名、密码输入。
  final _formKey = GlobalKey<FormState>();
  final _endpoint = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();

  /// 请求期间禁止重复提交，失败时在表单下方显示原因。
  bool _loggingIn = false;
  String? _error;

  /// 释放登录输入控制器。
  @override
  void dispose() {
    _endpoint.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  /// 校验凭证并登录，账户保存成功后由主页面监听切换。
  Future<void> _login() async {
    if (_loggingIn || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loggingIn = true;
      _error = null;
    });
    try {
      await (widget.authService ?? AuthService()).login(
        endpoint: _endpoint.text.trim().replaceFirst(RegExp(r'/+$'), ''),
        username: _username.text.trim(),
        password: _password.text,
      );
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  /// 仅允许具有主机地址的 HTTP 或 HTTPS 端点。
  String? _validateEndpoint(String? value) {
    final l10n = AppLocalizations.of(context);
    final text = value?.trim() ?? '';
    if (text.isEmpty) return l10n.enterEndpoint;
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      return l10n.invalidEndpoint;
    }
    return null;
  }

  /// 居中显示登录表单，窄屏和键盘打开时允许滚动。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: Image(
                          image: AssetImage('assets/logo.png'),
                          width: 64,
                          height: 64,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Pixtale Sync',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _endpoint,
                        enabled: !_loggingIn,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: l10n.endpoint,
                          hintText: 'https://example.com',
                        ),
                        validator: _validateEndpoint,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _username,
                        enabled: !_loggingIn,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: InputDecoration(labelText: l10n.username),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? l10n.enterUsername
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        enabled: !_loggingIn,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(labelText: l10n.password),
                        validator: (value) => value == null || value.isEmpty
                            ? l10n.enterPassword
                            : null,
                        onFieldSubmitted: (_) => _login(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _loggingIn ? null : _login,
                        child: _loggingIn
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.signIn),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
