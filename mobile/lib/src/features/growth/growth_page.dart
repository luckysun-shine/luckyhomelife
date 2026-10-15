import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/session_controller.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';

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
      if (mounted) await showAppSnackBar(context, '成长记录已保存');
      await load();
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? member;
    for (final item in widget.members) {
      if (item['id'] == memberId) member = item;
    }
    member ??= widget.members.isEmpty ? null : widget.members.first;
    return Scaffold(
      appBar: AppBar(title: const Text('成长记录')),
      floatingActionButton: FloatingActionButton(
        tooltip: '添加成长里程碑',
        onPressed: add,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                    children: [
                      PageHeader(
                        eyebrow: '${member?['displayName'] ?? '家人'} · 成长手记',
                        title: '慢慢长大的你',
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: memberId,
                        decoration: const InputDecoration(labelText: '家庭成员'),
                        items: widget.members
                            .map(
                              (item) => DropdownMenuItem(
                                value: item['id'] as String,
                                child: Text(item['displayName'] as String),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          memberId = value;
                          load();
                        },
                      ),
                      const SizedBox(height: 12),
                      SoftCard(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? null
                            : brandMist,
                        child: Text(
                          items.isEmpty
                              ? '每一小步，都值得被看见。'
                              : '已记下 ${items.length} 个成长脚印。',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (items.isEmpty)
                        EmptyState(
                          icon: Icons.auto_awesome_outlined,
                          message: '还没有成长记录。',
                          actionLabel: '写下一笔',
                          onAction: add,
                        )
                      else
                        for (final raw in items)
                          SoftCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('yyyy-MM-dd').format(
                                    DateTime.parse(
                                      raw['happenedAt'] as String,
                                    ).toLocal(),
                                  ),
                                  style: const TextStyle(
                                    color: brandCoralDeep,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${raw['title']}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                if ('${raw['note'] ?? ''}'.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text('${raw['note']}'),
                                ],
                              ],
                            ),
                          ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
