import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/api_client.dart';
import '../../core/session_controller.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';

class LedgerPage extends StatefulWidget {
  const LedgerPage({
    super.key,
    required this.session,
    this.openComposer = false,
  });
  final SessionController session;
  final bool openComposer;
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
    load().whenComplete(() {
      if (widget.openComposer && mounted && ledgers.isNotEmpty) add();
    });
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
    final amount = TextEditingController();
    final note = TextEditingController();
    var type = 'expense';
    var category = '餐饮食材';
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
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
              Text('记一笔日常', style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 12),
              SegmentControl(
                labels: const ['支出', '收入'],
                index: type == 'expense' ? 0 : 1,
                onChanged: (value) => setSheetState(
                  () => type = value == 0 ? 'expense' : 'income',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: '金额 · 人民币'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final item in const [
                    '餐饮食材',
                    '交通出行',
                    '教育成长',
                    '医疗健康',
                    '其他',
                  ])
                    ChoiceChip(
                      label: Text(item),
                      selected: category == item,
                      onSelected: (_) => setSheetState(() => category = item),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: '备注（选填）'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext, true),
                child: Text(type == 'expense' ? '保存这笔支出' : '保存这笔收入'),
              ),
            ],
          ),
        ),
      ),
    );
    final value = double.tryParse(amount.text);
    final noteText = note.text.trim();
    amount.dispose();
    note.dispose();
    if (saved == true && value != null && value > 0) {
      await widget.session.api.post(
        '/api/v1/families/${widget.session.selectedFamilyId}/transactions',
        {
          'ledgerId': ledgers.first['id'],
          'type': type,
          'amountMinor': (value * 100).round(),
          'currency': 'CNY',
          'category': category,
          'occurredAt': DateTime.now().toUtc().toIso8601String(),
          'note': noteText,
          'idempotencyKey': const Uuid().v4(),
        },
      );
      if (mounted) await showAppSnackBar(context, '这笔账已记下');
      await load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final spend = items
        .where((item) => item['type'] == 'expense')
        .fold<int>(
          0,
          (sum, item) => sum + int.parse(item['amountMinor'].toString()),
        );
    final income = items
        .where((item) => item['type'] == 'income')
        .fold<int>(
          0,
          (sum, item) => sum + int.parse(item['amountMinor'].toString()),
        );
    final theme = Theme.of(context);
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
                        '${widget.session.selectedFamily?.name ?? '家庭账本'} · ${DateFormat('yyyy年 M月').format(DateTime.now())}',
                    title: '过日子，心里有数',
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: brandTealDeep,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '本月家庭支出 · 人民币',
                          style: TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '¥ ${(spend / 100).toStringAsFixed(2)}',
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '收入 ¥ ${(income / 100).toStringAsFixed(2)}    结余 ¥ ${((income - spend) / 100).toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: ledgers.isEmpty ? null : add,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('记一笔日常'),
                  ),
                  const SizedBox(height: 8),
                  SectionTitle('最近流水', meta: '本月 ${items.length} 笔'),
                  if (items.isEmpty)
                    const EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      message: '还没有账目。把今天的一笔开销记下来。',
                    )
                  else
                    for (final raw in items)
                      _TransactionTile(
                        item: (raw as Map).cast<String, dynamic>(),
                      ),
                ],
              ),
            ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final expense = item['type'] == 'expense';
    final amount = int.parse(item['amountMinor'].toString());
    final when = DateTime.parse(item['occurredAt'] as String).toLocal();
    final note = item['note'] == null || '${item['note']}'.isEmpty
        ? ''
        : ' · ${item['note']}';
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: expense ? brandPeach : brandMist,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              expense ? Icons.shopping_bag_outlined : Icons.savings_outlined,
              color: expense ? brandCoralDeep : brandTealDeep,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['category']}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${DateFormat('M月d日 HH:mm').format(when)}$note',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '${expense ? '-' : '+'}¥ ${(amount / 100).toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: expense ? brandCoralDeep : brandTealDeep,
            ),
          ),
        ],
      ),
    );
  }
}
