import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/session_controller.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';
import '../ledger/ledger_page.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({
    super.key,
    required this.session,
    required this.onOpenTab,
    required this.onCompose,
  });
  final SessionController session;
  final ValueChanged<int> onOpenTab;
  final ValueChanged<String> onCompose;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  bool loading = true;
  String? error;
  List<dynamic> events = [];
  List<dynamic> tasks = [];
  List<dynamic> records = [];
  int monthSpendMinor = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final id = widget.session.selectedFamilyId;
    if (id == null) {
      setState(() {
        loading = false;
        events = [];
        tasks = [];
        records = [];
      });
      return;
    }
    setState(() {
      loading = events.isEmpty && tasks.isEmpty;
      error = null;
    });
    try {
      final today = await widget.session.api.get(
        '/api/v1/families/$id/today?timezone=Asia%2FShanghai',
      );
      final data = today['data'] as Map<String, dynamic>;
      events = data['events'] as List;
      tasks = data['tasks'] as List;
      await _loadSecondary(id);
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadSecondary(String id) async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1).toUtc().toIso8601String();
    final to = DateTime(now.year, now.month + 1, 1).toUtc().toIso8601String();
    try {
      final tx = await widget.session.api.get(
        '/api/v1/families/$id/transactions?from=${Uri.encodeComponent(from)}&to=${Uri.encodeComponent(to)}',
      );
      final items = tx['data'] as List;
      monthSpendMinor = items
          .where((item) => item['type'] == 'expense')
          .fold<int>(
            0,
            (sum, item) => sum + int.parse(item['amountMinor'].toString()),
          );
    } on ApiException {
      monthSpendMinor = 0;
    }
    try {
      final response = await widget.session.api.get(
        '/api/v1/families/$id/records?limit=1',
      );
      records = response['data'] as List;
    } on ApiException {
      records = [];
    }
  }

  Future<void> toggle(Map<String, dynamic> task) async {
    final id = widget.session.selectedFamilyId!;
    await widget.session.api.patch(
      '/api/v1/families/$id/tasks/${task['id']}/completion',
      {'completed': true, 'expectedVersion': task['version']},
    );
    if (mounted) await showAppSnackBar(context, '已完成这项待办');
    await load();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return '早安';
    if (hour < 18) return '午安';
    return '晚安';
  }

  String _roleName(String? role) =>
      const {
        'admin': '家庭管理员',
        'adult': '成人成员',
        'elder': '长辈',
        'teen': '青少年',
        'child': '儿童',
        'caregiver': '照护者',
      }[role] ??
      '家人';

  @override
  Widget build(BuildContext context) {
    final family = widget.session.selectedFamily;
    final theme = Theme.of(context);
    final openTasks = tasks.where((task) => task['status'] != 'completed');
    return Scaffold(
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? ErrorRetry(message: error!, onRetry: load)
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                children: [
                  PageHeader(
                    eyebrow:
                        '${family?.name ?? '我们家'} · ${DateFormat('M月d日 EEEE', 'zh_CN').format(DateTime.now())}',
                    title: '${_greeting()}，家人',
                    subtitle: _roleName(family?.role),
                    trailing: IconButton.filledTonal(
                      tooltip: '刷新今天',
                      onPressed: load,
                      icon: const Icon(Icons.notifications_none_rounded),
                    ),
                  ),
                  if (family == null)
                    EmptyState(
                      icon: Icons.home_outlined,
                      message: '先建立一个家庭空间，今天的安排才会出现在这里。',
                      actionLabel: '去创建家庭',
                      onAction: () => widget.onOpenTab(3),
                    )
                  else ...[
                    SoftCard(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? null
                          : brandMist,
                      child: Row(
                        children: [
                          Text(
                            '${DateTime.now().day}',
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: brandTealDeep,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '今天，也一起好好生活',
                                  style: theme.textTheme.titleLarge,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${events.length} 项安排 · ${tasks.length} 项待办 · ${records.length} 条近况',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        QuickActionTile(
                          icon: Icons.account_balance_wallet_outlined,
                          label: '记一笔',
                          color: brandCoralDeep,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LedgerPage(
                                session: widget.session,
                                openComposer: true,
                              ),
                            ),
                          ),
                        ),
                        QuickActionTile(
                          icon: Icons.event_available_outlined,
                          label: '加日程',
                          color: brandTealDeep,
                          onTap: () => widget.onCompose('event'),
                        ),
                        QuickActionTile(
                          icon: Icons.task_alt_rounded,
                          label: '建任务',
                          color: brandCoral,
                          onTap: () => widget.onCompose('task'),
                        ),
                        QuickActionTile(
                          icon: Icons.add_a_photo_outlined,
                          label: '发照片',
                          color: brandTeal,
                          onTap: () => widget.onCompose('record'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SectionTitle(
                      '今天的安排',
                      actionLabel: '查看全部',
                      onAction: () => widget.onOpenTab(1),
                    ),
                    SoftCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: events.isEmpty && tasks.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Text('今天还没有安排，享受轻松的一天吧'),
                            )
                          : Column(
                              children: [
                                for (final raw in events)
                                  _ScheduleRow(
                                    time: _time(raw['startsAt']),
                                    title: '${raw['title']}',
                                    detail: '${raw['location'] ?? '家庭日程'}',
                                    tag: '日程',
                                  ),
                                for (final raw in tasks)
                                  _ScheduleRow(
                                    time: raw['dueAt'] == null
                                        ? '待办'
                                        : _time(raw['dueAt']),
                                    title: '${raw['title']}',
                                    detail: raw['status'] == 'completed'
                                        ? '已完成'
                                        : '点击即可完成',
                                    tag: raw['status'] == 'completed'
                                        ? '已完成'
                                        : '待完成',
                                    onTap: raw['status'] == 'completed'
                                        ? null
                                        : () => toggle(
                                            (raw as Map)
                                                .cast<String, dynamic>(),
                                          ),
                                  ),
                              ],
                            ),
                    ),
                    if (openTasks.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      InfoBanner(
                        icon: Icons.checklist_rounded,
                        text:
                            '你的待办：${openTasks.take(2).map((task) => task['title']).join('、')}',
                        onTap: () => widget.onOpenTab(1),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SoftCard(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? null
                          : brandSage,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LedgerPage(session: widget.session),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '本月支出 ¥ ${(monthSpendMinor / 100).toStringAsFixed(2)}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: brandTealDeep,
                              ),
                            ),
                          ),
                          Text(
                            '账本',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: brandTealDeep,
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: brandTealDeep),
                        ],
                      ),
                    ),
                    SectionTitle(
                      '生活里的小美好',
                      actionLabel: '家庭时间线',
                      onAction: () => widget.onOpenTab(2),
                    ),
                    if (records.isEmpty)
                      const EmptyState(
                        icon: Icons.photo_outlined,
                        message: '还没有家庭记录。去时间线写下第一件小事吧。',
                      )
                    else
                      SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${records.first['body'] ?? ''}',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${records.first['createdByName'] ?? '家人'} · ${DateFormat('M月d日 HH:mm').format(DateTime.parse(records.first['happenedAt'] as String).toLocal())}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }

  static String _time(dynamic value) =>
      DateFormat('HH:mm').format(DateTime.parse(value as String).toLocal());
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.time,
    required this.title,
    required this.detail,
    required this.tag,
    this.onTap,
  });

  final String time;
  final String title;
  final String detail;
  final String tag;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
                  color: brandTealDeep,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(detail, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: brandMist,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                tag,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: brandTealDeep,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
