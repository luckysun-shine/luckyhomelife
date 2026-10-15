import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/api_client.dart';
import '../../core/session_controller.dart';
import '../../theme.dart';

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
      appBar: AppBar(title: const Text('过日子，心里有数')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text(error!))
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                children: [
                  Text(
                    '家庭账本 · ${DateFormat('yyyy年 M月').format(DateTime.now())}',
                    style: Theme.of(c).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(c).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: brandTeal,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '本月家庭支出 · 人民币',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '¥ ${(spend / 100).toStringAsFixed(2)}',
                            style: Theme.of(c).textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            '${items.length} 笔共同账目',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: add,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('记一笔日常'),
                    style: FilledButton.styleFrom(backgroundColor: brandCoral),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('最近流水', style: Theme.of(c).textTheme.titleLarge),
                      Text(
                        '本月 ${items.length} 笔',
                        style: Theme.of(
                          c,
                        ).textTheme.bodySmall?.copyWith(color: brandTeal),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: e['type'] == 'expense'
                                ? brandPeach
                                : brandMist,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            e['type'] == 'expense'
                                ? Icons.shopping_bag_outlined
                                : Icons.savings_outlined,
                            color: e['type'] == 'expense'
                                ? brandCoral
                                : brandTeal,
                          ),
                        ),
                        title: Text(
                          e['category'],
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${DateFormat('M月d日').format(DateTime.parse(e['occurredAt']).toLocal())}${e['note'] == null ? '' : ' · ${e['note']}'}',
                        ),
                        trailing: Text(
                          '${e['type'] == 'expense' ? '-' : '+'}¥ ${(int.parse(e['amountMinor'].toString()) / 100).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: e['type'] == 'expense'
                                ? brandCoral
                                : brandTeal,
                          ),
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
