import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/session_controller.dart';

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
    appBar: AppBar(
      title: Text(widget.session.selectedFamily?.name ?? '今天'),
      actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? _Error(text: error!, retry: load)
        : RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  DateFormat('M月d日 EEEE', 'zh_CN').format(DateTime.now()),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                _Title('今日安排', events.length),
                if (events.isEmpty) const _Empty('今天还没有安排'),
                ...events.map(
                  (e) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.event),
                      title: Text(e['title']),
                      subtitle: Text(
                        '${_time(e['startsAt'])}${e['location'] == null ? '' : ' · ${e['location']}'}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _Title('待办事项', tasks.length),
                if (tasks.isEmpty) const _Empty('今天没有待办'),
                ...tasks.map(
                  (e) => Card(
                    child: ListTile(
                      leading: Checkbox(
                        value: false,
                        onChanged: (_) =>
                            toggle((e as Map).cast<String, dynamic>()),
                      ),
                      title: Text(e['title']),
                      subtitle: e['dueAt'] == null
                          ? null
                          : Text('截止 ${_time(e['dueAt'])}'),
                    ),
                  ),
                ),
              ],
            ),
          ),
  );
  static String _time(dynamic value) =>
      DateFormat('HH:mm').format(DateTime.parse(value as String).toLocal());
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

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext c) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Center(child: Text(text)),
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
