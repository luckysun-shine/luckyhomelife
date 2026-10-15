import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.api, required this.onLoggedIn});
  final ApiClient api;
  final ValueChanged<String> onLoggedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _account = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _registering = false;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _account.dispose();
    _name.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final account = _account.text.trim();
    final password = _password.text;
    if (account.length < 3) {
      setState(() => _error = '账号至少 3 个字符');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = '密码至少 8 位');
      return;
    }
    if (_registering) {
      if (_name.text.trim().isEmpty) {
        setState(() => _error = '请填写家庭称呼');
        return;
      }
      if (_confirm.text != password) {
        setState(() => _error = '两次输入的密码不一致');
        return;
      }
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.api
          .post(_registering ? '/api/v1/auth/register' : '/api/v1/auth/login', {
            'account': account,
            'password': password,
            if (_registering) 'displayName': _name.text.trim(),
          });
      final data = result['data'] as Map<String, dynamic>;
      widget.onLoggedIn(data['accessToken'] as String);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildFamilyTheme(Brightness.light),
      child: _LoginCanvas(),
    );
  }
}

class _LoginCanvas extends StatelessWidget {
  const _LoginCanvas();

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_LoginPageState>()!;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: brandIvory,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('HomeLife OS', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Text('一起，把日子过好', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 16),
                  Container(
                    height: 148,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFE5F7F3),
                          Color(0xFFFFF6EA),
                          Color(0xFFFFE7DF),
                        ],
                      ),
                    ),
                    child: const Center(child: BrandMark(size: 84)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    state._registering
                        ? '留一个账号，再邀请家人一起用。'
                        : '一家人的今天，在这里相遇。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: brandMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentControl(
                            labels: const ['登录', '注册'],
                            index: state._registering ? 1 : 0,
                            onChanged: (value) => state.setState(() {
                              state._registering = value == 1;
                              state._error = null;
                            }),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: state._account,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: '账号',
                              hintText: '字母、数字或中文',
                            ),
                          ),
                          if (state._registering) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: state._name,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: '家庭称呼',
                                hintText: '例如：妈妈',
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextField(
                            controller: state._password,
                            obscureText: state._obscure,
                            decoration: InputDecoration(
                              labelText: '密码',
                              hintText: '至少 8 位',
                              suffixIcon: IconButton(
                                tooltip: state._obscure ? '显示密码' : '隐藏密码',
                                onPressed: () => state.setState(
                                  () => state._obscure = !state._obscure,
                                ),
                                icon: Icon(
                                  state._obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          if (state._registering) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: state._confirm,
                              obscureText: state._obscure,
                              onSubmitted: (_) => state._submit(),
                              decoration: const InputDecoration(
                                labelText: '再次输入密码',
                              ),
                            ),
                          ],
                          if (state._error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              state._error!,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ],
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: state._loading ? null : state._submit,
                            child: state._loading
                                ? const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    state._registering ? '注册并进入' : '登录，回到家',
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '继续即表示你同意仅将家庭数据用于本人授权的家庭协作。',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
