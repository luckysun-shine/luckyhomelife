import 'package:flutter/material.dart';

import '../../core/api_client.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.api, required this.onLoggedIn});
  final ApiClient api;
  final ValueChanged<String> onLoggedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phone = TextEditingController(text: '13800000000');
  final _name = TextEditingController(text: '妈妈');
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_phone.text.trim().length < 6 || _name.text.trim().isEmpty) {
      setState(() => _error = '请填写手机号和家庭称呼');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_codeSent) {
        final result = await widget.api.post('/api/v1/auth/request-code', {
          'phone': _phone.text.trim(),
        });
        final data = result['data'] as Map<String, dynamic>;
        if (data['debugCode'] != null) _code.text = data['debugCode'] as String;
        setState(() => _codeSent = true);
      } else {
        final result = await widget.api.post('/api/v1/auth/verify-code', {
          'phone': _phone.text.trim(),
          'code': _code.text.trim(),
          'displayName': _name.text.trim(),
        });
        final data = result['data'] as Map<String, dynamic>;
        widget.onLoggedIn(data['accessToken'] as String);
      }
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.family_restroom_rounded, size: 64),
                  const SizedBox(height: 24),
                  Text(
                    '欢迎回家',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '一起安排今天，保存一家人的生活',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: '手机号'),
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(labelText: '短信验证码'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: '家庭称呼'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_codeSent ? '验证并登录' : '获取验证码'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _codeSent
                        ? '验证码 5 分钟内有效，请勿告诉他人。'
                        : '登录即表示你同意仅将家庭数据用于本人授权的家庭协作。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
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
