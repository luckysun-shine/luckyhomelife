import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/api_client.dart';
import '../../core/session_controller.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.session});
  final SessionController session;
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
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
    setState(() => loading = true);
    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, 1).toUtc().toIso8601String();
      final to = DateTime(now.year, now.month + 1, 1).toUtc().toIso8601String();
      final rs = await Future.wait([
        widget.session.api.get(
          '/api/v1/families/$id/events?from=${Uri.encodeComponent(from)}&to=${Uri.encodeComponent(to)}',
        ),
        widget.session.api.get(
          '/api/v1/families/$id/tasks?includeCompleted=false',
        ),
      ]);
      events = rs[0]['data'] as List;
      tasks = rs[1]['data'] as List;
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> addTask() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (x) => AlertDialog(
        title: const Text('新增家庭任务'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(labelText: '任务内容'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(x, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(x, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok == true && c.text.trim().isNotEmpty) {
      await widget.session.api.post(
        '/api/v1/families/${widget.session.selectedFamilyId}/tasks',
        {'title': c.text.trim(), 'clientOperationId': const Uuid().v4()},
      );
      await load();
    }
  }

  Future<void> addEvent() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (x) => AlertDialog(
        title: const Text('新增日程'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(labelText: '日程标题'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(x, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(x, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok == true && c.text.trim().isNotEmpty) {
      final start = DateTime.now().add(const Duration(hours: 1));
      await widget.session.api
          .post('/api/v1/families/${widget.session.selectedFamilyId}/events', {
            'title': c.text.trim(),
            'startsAt': start.toUtc().toIso8601String(),
            'endsAt': start
                .add(const Duration(hours: 1))
                .toUtc()
                .toIso8601String(),
            'allDay': false,
            'participantMemberIds': [],
            'clientOperationId': const Uuid().v4(),
          });
      await load();
    }
  }

  Future<void> editEvent(Map<String, dynamic> event) async {
    final title = TextEditingController(text: event['title'] as String);
    final ok = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('编辑日程'),
      content: TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: '日程标题')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('保存')),
      ],
    ));
    if (ok != true || title.text.trim().isEmpty) return;
    try {
      await widget.session.api.patch(
        '/api/v1/families/${widget.session.selectedFamilyId}/events/${event['id']}',
        {
          'title': title.text.trim(),
          'startsAt': event['startsAt'],
          'endsAt': event['endsAt'],
          'allDay': event['allDay'] ?? false,
          if (event['location'] != null) 'location': event['location'],
          if (event['notes'] != null) 'notes': event['notes'],
          'expectedVersion': event['version'],
        },
      );
      await load();
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> deleteEvent(Map<String, dynamic> event) async {
    final ok = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('删除日程'),
      content: Text('确定删除“${event['title']}”吗？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('删除')),
      ],
    ));
    if (ok != true) return;
    try {
      await widget.session.api.delete(
        '/api/v1/families/${widget.session.selectedFamilyId}/events/${event['id']}?expectedVersion=${event['version']}',
      );
      await load();
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> completeTask(Map<String, dynamic> task, bool completed) async {
    try {
      await widget.session.api.patch(
        '/api/v1/families/${widget.session.selectedFamilyId}/tasks/${task['id']}/completion',
        {'completed': completed, 'expectedVersion': task['version']},
      );
      await load();
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('日历与任务')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(child: Text(error!))
        : RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: addEvent,
                        icon: const Icon(Icons.event),
                        label: const Text('添加日程'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: addTask,
                        icon: const Icon(Icons.task_alt),
                        label: const Text('添加任务'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('本月日程', style: Theme.of(c).textTheme.titleLarge),
                ...events.map(
                  (raw) {
                    final e = raw as Map<String, dynamic>;
                    return Card(
                    child: ListTile(
                      title: Text(e['title']),
                      subtitle: Text(
                        DateFormat(
                          'M月d日 HH:mm',
                        ).format(DateTime.parse(e['startsAt']).toLocal()),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) => action == 'edit' ? editEvent(e) : deleteEvent(e),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('编辑')),
                          PopupMenuItem(value: 'delete', child: Text('删除')),
                        ],
                      ),
                    ),
                  );
                  },
                ),
                const SizedBox(height: 16),
                Text('未完成任务', style: Theme.of(c).textTheme.titleLarge),
                ...tasks.map(
                  (raw) {
                    final e = raw as Map<String, dynamic>;
                    return Card(
                    child: ListTile(
                      leading: Checkbox(
                        value: e['status'] == 'completed',
                        onChanged: (value) => completeTask(e, value ?? true),
                      ),
                      title: Text(e['title']),
                    ),
                  );
                  },
                ),
              ],
            ),
          ),
  );
}
