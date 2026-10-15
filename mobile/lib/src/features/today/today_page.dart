import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/session_controller.dart';
import '../../theme.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key, required this.session});
  final SessionController session;
  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  bool loading = true;
  String? error;
  List<dynamic> events = [];
  List<dynamic> tasks = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final id = widget.session.selectedFamilyId;
    if (id == null) {
      setState(() => loading = false);
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await widget.session.api.get(
        '/api/v1/families/$id/today?timezone=Asia%2FShanghai',
      );
      final d = r['data'] as Map<String, dynamic>;
      events = d['events'] as List;
      tasks = d['tasks'] as List;
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> toggle(Map<String, dynamic> task) async {
    final id = widget.session.selectedFamilyId!;
    await widget.session.api.patch(
      '/api/v1/families/$id/tasks/${task['id']}/completion',
      {'completed': true, 'expectedVersion': task['version']},
    );
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? _Error(text: error!, retry: load)
        : RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 54, 24, 28),
              children: [
                Text(
                  '${widget.session.selectedFamily?.name ?? '我们家'} · ${DateFormat('M月d日 EEEE', 'zh_CN').format(DateTime.now())}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '早安，家人',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: load,
                      icon: const Icon(Icons.notifications_none_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: brandMist,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${DateTime.now().day}',
                        style: Theme.of(
                          context,
                        ).textTheme.displaySmall?.copyWith(color: brandTeal),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '今天，也一起好好生活',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${events.length} 项安排 · ${tasks.length} 项待办',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: brandNavy.withValues(alpha: .66),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _QuickAction(
                      icon: Icons.account_balance_wallet_outlined,
                      label: '记一笔',
                      color: brandCoral,
                    ),
                    _QuickAction(
                      icon: Icons.event_available_outlined,
                      label: '加日程',
                      color: brandTeal,
                    ),
                    _QuickAction(
                      icon: Icons.task_alt_rounded,
                      label: '建任务',
                      color: brandYellow,
                    ),
                    _QuickAction(
                      icon: Icons.add_a_photo_outlined,
                      label: '发照片',
                      color: brandCoral,
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                _Title('今天的安排', events.length + tasks.length),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        if (events.isEmpty && tasks.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(18),
                            child: Text('今天还没有安排，享受轻松的一天吧'),
                          ),
                        ...events.map(
                          (e) => _ScheduleRow(
                            time: _time(e['startsAt']),
                            title: e['title'],
                            detail: e['location'] ?? '家庭日程',
                            icon: Icons.calendar_today_outlined,
                          ),
                        ),
                        ...tasks.map(
                          (e) => _ScheduleRow(
                            time: e['dueAt'] == null ? '待办' : _time(e['dueAt']),
                            title: e['title'],
                            detail: '点击即可完成',
                            icon: Icons.circle_outlined,
                            onTap: () =>
                                toggle((e as Map).cast<String, dynamic>()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: brandPeach,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.favorite_outline_rounded, color: brandCoral),
                      SizedBox(width: 12),
                      Expanded(child: Text('把普通日子，慢慢过成家的故事。')),
                    ],
                  ),
                ),
              ],
            ),
          ),
  );
  static String _time(dynamic value) =>
      DateFormat('HH:mm').format(DateTime.parse(value as String).toLocal());
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 62,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(icon, color: color),
      ),
      const SizedBox(height: 7),
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.time,
    required this.title,
    required this.detail,
    required this.icon,
    this.onTap,
  });
  final String time;
  final String title;
  final String detail;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              time,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: brandTeal,
              ),
            ),
          ),
          Icon(icon, size: 20, color: brandCoral),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Title extends StatelessWidget {
  const _Title(this.text, this.count);
  final String text;
  final int count;
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(text, style: Theme.of(c).textTheme.titleLarge),
        Text('$count 项'),
      ],
    ),
  );
}

class _Error extends StatelessWidget {
  const _Error({required this.text, required this.retry});
  final String text;
  final VoidCallback retry;
  @override
  Widget build(BuildContext c) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        const SizedBox(height: 12),
        FilledButton(onPressed: retry, child: const Text('重试')),
      ],
    ),
  );
}
