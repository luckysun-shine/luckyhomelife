import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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
      themeMode: ThemeMode.light,
      builder: (context, child) {
        if (!kIsWeb) return child ?? const SizedBox.shrink();
        return _WebPhoneFrame(child: child ?? const SizedBox.shrink());
      },
      home: !_session.initialized
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : !_session.isAuthenticated
          ? LoginPage(api: _session.api, onLoggedIn: _session.login)
          : HomeShell(session: _session),
    );
  }
}

class _WebPhoneFrame extends StatelessWidget {
  const _WebPhoneFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF4E6), Color(0xFFFFE4D8), Color(0xFFE6F7F3)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = math.min(constraints.maxHeight - 48, 900.0);
          return Center(
            child: Container(
              width: 402,
              height: height < 640 ? constraints.maxHeight : height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: brandIvory,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white, width: 8),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33FF6548),
                    blurRadius: 32,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
