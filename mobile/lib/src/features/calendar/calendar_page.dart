import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../core/session_controller.dart';
import '../../widgets/month_calendar.dart';
import '../../widgets/ui.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.session, this.composer});
  final SessionController session;
  final ValueNotifier<String?>? composer;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  bool loading = true;
  String? error;
  int view = 0;
  DateTime visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selected = DateTime.now();
  List<dynamic> events = [];
  List<dynamic> tasks = [];

  @override
  void initState() {
    super.initState();
    widget.composer?.addListener(_consumeComposer);
    load();
  }

  @override
  void dispose() {
    widget.composer?.removeListener(_consumeComposer);
    super.dispose();
  }

  void _consumeComposer() {
    final action = widget.composer?.value;
    if (action != 'event' && action != 'task') return;
    widget.composer?.value = null;
    if (action == 'event') {
      addEvent();
    } else {
      addTask();
    }
  }

  Future<void> load() async {
    final id = widget.session.selectedFamilyId;
    if (id == null) {
      setState(() => loading = false);
      return;
    }
    final showSpinner = events.isEmpty && tasks.isEmpty;
    setState(() => loading = showSpinner);
    try {
      final from = DateTime(
        visibleMonth.year,
        visibleMonth.month,
        1,
      ).toUtc().toIso8601String();
      final to = DateTime(
        visibleMonth.year,
        visibleMonth.month + 1,
        1,
      ).toUtc().toIso8601String();
      final responses = await Future.wait([
        widget.session.api.get(
          '/api/v1/families/$id/events?from=${Uri.encodeComponent(from)}&to=${Uri.encodeComponent(to)}',
        ),
        widget.session.api.get(
          '/api/v1/families/$id/tasks?includeCompleted=false',
        ),
      ]);
      events = responses[0]['data'] as List;
      tasks = responses[1]['data'] as List;
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<String?> _ask(String title, String label, String confirm) async {
    final controller = TextEditingController();
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(labelText: label),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(sheetContext, controller.text.trim()),
                child: Text(confirm),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> addTask() async {
    final title = await _ask('新增家庭任务', '任务内容', '保存任务');
    if (title == null) return;
    await widget.session.api.post(
      '/api/v1/families/${widget.session.selectedFamilyId}/tasks',
      {'title': title, 'clientOperationId': const Uuid().v4()},
    );
    if (mounted) await showAppSnackBar(context, '任务已加入家庭清单');
    await load();
  }

  Future<void> addEvent() async {
    final title = await _ask('添一个家庭安排', '日程名称', '创建日程');
    if (title == null) return;
    final start = DateTime(
      selected.year,
      selected.month,
      selected.day,
      DateTime.now().hour,
      0,
    ).add(const Duration(hours: 1));
    await widget.session.api.post(
      '/api/v1/families/${widget.session.selectedFamilyId}/events',
      {
        'title': title,
        'startsAt': start.toUtc().toIso8601String(),
        'endsAt': start.add(const Duration(hours: 1)).toUtc().toIso8601String(),
        'allDay': false,
        'participantMemberIds': [],
        'clientOperationId': const Uuid().v4(),
      },
    );
    if (mounted) await showAppSnackBar(context, '日程已创建');
    await load();
  }

  Future<void> editEvent(Map<String, dynamic> event) async {
    final title = TextEditingController(text: event['title'] as String);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('编辑日程'),
        content: TextField(
          controller: title,
          autofocus: true,
          decoration: const InputDecoration(labelText: '日程标题'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    final next = title.text.trim();
    title.dispose();
    if (ok != true || next.isEmpty) return;
    try {
      await widget.session.api.patch(
        '/api/v1/families/${widget.session.selectedFamilyId}/events/${event['id']}',
        {
          'title': next,
          'startsAt': event['startsAt'],
          'endsAt': event['endsAt'],
          'allDay': event['allDay'] ?? false,
          if (event['location'] != null) 'location': event['location'],
          if (event['notes'] != null) 'notes': event['notes'],
          'expectedVersion': event['version'],
        },
      );
      if (mounted) await showAppSnackBar(context, '日程已更新');
      await load();
    } on ApiException catch (error) {
      if (mounted) await showAppSnackBar(context, error.message);
    }
  }

  Future<void> deleteEvent(Map<String, dynamic> event) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除日程'),
        content: Text('确定删除「${event['title']}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.session.api.delete(
        '/api/v1/families/${widget.session.selectedFamilyId}/events/${event['id']}?expectedVersion=${event['version']}',
      );
      if (mounted) await showAppSnackBar(context, '日程已删除');
      await load();
    } on ApiException catch (error) {
      if (mounted) await showAppSnackBar(context, error.message);
    }
  }

  Future<void> completeTask(Map<String, dynamic> task, bool completed) async {
    try {
      await widget.session.api.patch(
        '/api/v1/families/${widget.session.selectedFamilyId}/tasks/${task['id']}/completion',
        {'completed': completed, 'expectedVersion': task['version']},
      );
      if (mounted) {
        await showAppSnackBar(context, completed ? '已完成这项待办' : '已恢复这项待办');
      }
      await load();
    } on ApiException catch (error) {
      if (mounted) await showAppSnackBar(context, error.message);
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final dayEvents = events.where((raw) {
      final event = raw as Map<String, dynamic>;
      return _sameDay(
        DateTime.parse(event['startsAt'] as String).toLocal(),
        selected,
      );
    }).toList();
    final markedInMonth = <int>{};
    for (final raw in events) {
      final date = DateTime.parse(
        (raw as Map<String, dynamic>)['startsAt'] as String,
      ).toLocal();
      if (date.year == visibleMonth.year && date.month == visibleMonth.month) {
        markedInMonth.add(date.day);
      }
    }

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
                        '家庭日历 · ${DateFormat('yyyy年 M月').format(visibleMonth)}',
                    title: '把时间，留给家人',
                    trailing: IconButton.filled(
                      tooltip: '添加日程',
                      onPressed: addEvent,
                      icon: const Icon(Icons.add),
                    ),
                  ),
                  SegmentControl(
                    labels: const ['月视图', '日程表'],
                    index: view,
                    onChanged: (value) => setState(() => view = value),
                  ),
                  const SizedBox(height: 16),
                  if (view == 0)
                    SoftCard(
                      child: MonthCalendar(
                        visibleMonth: visibleMonth,
                        selected: selected,
                        markedDays: markedInMonth,
                        onSelect: (date) => setState(() => selected = date),
                        onPrevious: () {
                          setState(() {
                            visibleMonth = DateTime(
                              visibleMonth.year,
                              visibleMonth.month - 1,
                            );
                          });
                          load();
                        },
                        onNext: () {
                          setState(() {
                            visibleMonth = DateTime(
                              visibleMonth.year,
                              visibleMonth.month + 1,
                            );
                          });
                          load();
                        },
                        onToday: () {
                          final now = DateTime.now();
                          setState(() {
                            selected = now;
                            visibleMonth = DateTime(now.year, now.month);
                          });
                          load();
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  SectionTitle(
                    view == 0
                        ? '${selected.day} 日 · ${_sameDay(selected, DateTime.now()) ? '今天' : DateFormat('M月d日').format(selected)}'
                        : '本月日程',
                    meta: '${view == 0 ? dayEvents.length : events.length} 项安排',
                  ),
                  if ((view == 0 ? dayEvents : events).isEmpty)
                    const EmptyState(
                      icon: Icons.event_available_outlined,
                      message: '这一天还没有家庭安排。',
                    )
                  else
                    SoftCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          for (final raw in (view == 0 ? dayEvents : events))
                            Builder(
                              builder: (context) {
                                final event = Map<String, dynamic>.from(
                                  raw as Map,
                                );
                                return _EventTile(
                                  event: event,
                                  onEdit: () => editEvent(event),
                                  onDelete: () => deleteEvent(event),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  SectionTitle('未完成任务', actionLabel: '添加', onAction: addTask),
                  if (tasks.isEmpty)
                    const EmptyState(
                      icon: Icons.task_alt_rounded,
                      message: '清单是空的。把要一起做的事记在这里。',
                    )
                  else
                    SoftCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (final raw in tasks)
                            CheckboxListTile(
                              value:
                                  (raw as Map<String, dynamic>)['status'] ==
                                  'completed',
                              onChanged: (value) =>
                                  completeTask(raw, value ?? true),
                              title: Text('${raw['title']}'),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final start = DateTime.parse(event['startsAt'] as String).toLocal();
    return ListTile(
      title: Text('${event['title']}'),
      subtitle: Text(DateFormat('M月d日 HH:mm').format(start)),
      trailing: PopupMenuButton<String>(
        tooltip: '日程操作',
        onSelected: (action) => action == 'edit' ? onEdit() : onDelete(),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('编辑')),
          PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
      ),
    );
  }
}
