import 'package:flutter/material.dart';

import '../../core/session_controller.dart';
import '../calendar/calendar_page.dart';
import '../family/family_page.dart';
import '../records/records_page.dart';
import '../today/today_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.session});
  final SessionController session;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _composer = ValueNotifier<String?>(null);

  void _openTab(int index) => setState(() => _index = index);

  void _compose(String action) {
    if (action == 'event' || action == 'task') _openTab(1);
    if (action == 'record') _openTab(2);
    _composer.value = action;
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayPage(
        session: widget.session,
        onOpenTab: _openTab,
        onCompose: _compose,
      ),
      CalendarPage(session: widget.session, composer: _composer),
      RecordsPage(session: widget.session, composer: _composer),
      FamilyPage(session: widget.session),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _openTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny_rounded),
            label: '今天',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '日历',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: '记录',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '家庭',
          ),
        ],
      ),
    );
  }
}
