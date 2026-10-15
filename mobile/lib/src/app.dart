import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/session_controller.dart';
import 'features/auth/login_page.dart';
import 'features/home/home_shell.dart';
import 'theme.dart';

class FamilyOsApp extends StatefulWidget {
  const FamilyOsApp({super.key});

  @override
  State<FamilyOsApp> createState() => _FamilyOsAppState();
}

class _FamilyOsAppState extends State<FamilyOsApp> {
  late final SessionController _session;

  @override
  void initState() {
    super.initState();
    _session = SessionController(api: ApiClient())..addListener(_refresh);
    _session.initialize();
  }

  void _refresh() => mounted ? setState(() {}) : null;

  @override
  void dispose() {
    _session.removeListener(_refresh);
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '家庭生活 OS',
      debugShowCheckedModeBanner: false,
      theme: buildFamilyTheme(Brightness.light),
      darkTheme: buildFamilyTheme(Brightness.dark),
      home: !_session.initialized
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : !_session.isAuthenticated
          ? LoginPage(api: _session.api, onLoggedIn: _session.login)
          : HomeShell(session: _session),
    );
  }
}
