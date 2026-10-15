import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/api_client.dart';
import '../../core/session_controller.dart';

class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key, required this.session});
  final SessionController session;
  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  bool loading = true;
  String? error;
  List<dynamic> ledgers = [];
  List<dynamic> items = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final f = widget.session.selectedFamilyId;
    if (f == null) {
      setState(() => loading = false);
      return;
    }
    setState(() => loading = true);
    try {
      var r = await widget.session.api.get('/api/v1/families/$f/ledgers');
      ledgers = r['data'] as List;
      if (ledgers.isEmpty) {
        await widget.session.api.post('/api/v1/families/$f/ledgers', {
          'name': '家庭账本',
          'isPersonal': false,
        });
        r = await widget.session.api.get('/api/v1/families/$f/ledgers');
        ledgers = r['data'] as List;
      }
      final n = DateTime.now();
      final from = DateTime(n.year, n.month, 1).toUtc().toIso8601String();
      final to = DateTime(n.year, n.month + 1, 1).toUtc().toIso8601String();
      items =
          (await widget.session.api.get(
                '/api/v1/families/$f/transactions?from=${Uri.encodeComponent(from)}&to=${Uri.encodeComponent(to)}',
              ))['data']
              as List;
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> add() async {
    final amount = TextEditingController(), note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (x) => AlertDialog(
        title: const Text('记一笔'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '金额'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: '备注（选填）'),
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
    final value = double.tryParse(amount.text);
    if (ok == true && value != null && value > 0) {
      await widget.session.api.post(
        '/api/v1/families/${widget.session.selectedFamilyId}/transactions',
        {
          'ledgerId': ledgers.first['id'],
          'type': 'expense',
          'amountMinor': (value * 100).round(),
          'currency': 'CNY',
          'category': '其他',
          'occurredAt': DateTime.now().toUtc().toIso8601String(),
          'note': note.text.trim(),
          'idempotencyKey': const Uuid().v4(),
        },
      );
      await load();
    }
  }

  @override
  Widget build(BuildContext c) {
    final spend = items
        .where((e) => e['type'] == 'expense')
        .fold<int>(0, (a, e) => a + int.parse(e['amountMinor'].toString()));
    return Scaffold(
      appBar: AppBar(title: const Text('家庭账本')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loading ? null : add,
        icon: const Icon(Icons.add),
        label: const Text('记一笔'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text(error!))
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('本月支出'),
                          const SizedBox(height: 8),
                          Text(
                            '¥ ${(spend / 100).toStringAsFixed(2)}',
                            style: Theme.of(c).textTheme.headlineMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('最近流水', style: Theme.of(c).textTheme.titleLarge),
                  if (items.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('还没有账目'),
                      ),
                    ),
                  ...items.map(
                    (e) => Card(
                      child: ListTile(
                        title: Text(e['category']),
                        subtitle: Text(
                          '${DateFormat('M月d日').format(DateTime.parse(e['occurredAt']).toLocal())}${e['note'] == null ? '' : ' · ${e['note']}'}',
                        ),
                        trailing: Text(
                          '${e['type'] == 'expense' ? '-' : '+'}¥ ${(int.parse(e['amountMinor'].toString()) / 100).toStringAsFixed(2)}',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
