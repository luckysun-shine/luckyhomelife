import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/session_controller.dart';

class GrowthPage extends StatefulWidget {
  const GrowthPage({super.key, required this.session, required this.members});
  final SessionController session;
  final List<Map<String, dynamic>> members;
  @override
  State<GrowthPage> createState() => _GrowthPageState();
}

class _GrowthPageState extends State<GrowthPage> {
  String? memberId;
  bool loading = false;
  List<dynamic> items = [];
  @override
  void initState() {
    super.initState();
    if (widget.members.isNotEmpty) {
      memberId = widget.members.first['id'];
      load();
    }
  }

  Future<void> load() async {
    if (memberId == null) return;
    setState(() => loading = true);
    items =
        (await widget.session.api.get(
              '/api/v1/families/${widget.session.selectedFamilyId}/growth-milestones?memberId=$memberId',
            ))['data']
            as List;
    if (mounted) setState(() => loading = false);
  }

  Future<void> add() async {
    final title = TextEditingController(), note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (x) => AlertDialog(
        title: const Text('添加成长里程碑'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: '里程碑'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: '记录详情'),
            ),
          ],
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
    if (ok == true && title.text.trim().isNotEmpty) {
      await widget.session.api.post(
        '/api/v1/families/${widget.session.selectedFamilyId}/growth-milestones',
        {
          'memberId': memberId,
          'title': title.text.trim(),
          'note': note.text.trim(),
          'happenedAt': DateTime.now().toUtc().toIso8601String(),
          'clientOperationId': const Uuid().v4(),
        },
      );
      await load();
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('成长记录')),
    floatingActionButton: FloatingActionButton(
      onPressed: add,
      child: const Icon(Icons.add),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<String>(
            initialValue: memberId,
            decoration: const InputDecoration(labelText: '家庭成员'),
            items: widget.members
                .map(
                  (m) => DropdownMenuItem(
                    value: m['id'] as String,
                    child: Text(m['displayName']),
                  ),
                )
                .toList(),
            onChanged: (v) {
              memberId = v;
              load();
            },
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
              ? const Center(child: Text('还没有成长记录'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final e = items[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.auto_awesome),
                        title: Text(e['title']),
                        subtitle: Text(
                          '${DateFormat('yyyy-MM-dd').format(DateTime.parse(e['happenedAt']).toLocal())}${(e['note'] ?? '').isEmpty ? '' : ' · ${e['note']}'}',
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}
