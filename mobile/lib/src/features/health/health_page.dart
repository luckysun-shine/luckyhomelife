import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/api_client.dart';
import '../../core/session_controller.dart';
import '../../core/notification_service.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';

class HealthPage extends StatefulWidget {
  const HealthPage({super.key, required this.session, required this.members});
  final SessionController session;
  final List<Map<String, dynamic>> members;
  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  String? memberId;
  bool loading = false;
  String? error;
  Map<String, dynamic>? data;
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
    try {
      data =
          (await widget.session.api.get(
                '/api/v1/families/${widget.session.selectedFamilyId}/health/profiles/$memberId',
              ))['data']
              as Map<String, dynamic>;
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> editProfile() async {
    final current = (data?['profile'] as Map<String, dynamic>?);
    final allergies = TextEditingController(text: current?['allergies'] ?? '');
    final chronic = TextEditingController(
      text: current?['chronicConditions'] ?? '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (x) => AlertDialog(
        title: const Text('健康基础资料'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: allergies,
              decoration: const InputDecoration(labelText: '过敏史'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: chronic,
              decoration: const InputDecoration(labelText: '慢性病史'),
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
    if (ok == true) {
      await widget.session.api.put(
        '/api/v1/families/${widget.session.selectedFamilyId}/health/profiles/$memberId',
        {'allergies': allergies.text, 'chronicConditions': chronic.text},
      );
      await load();
    }
  }

  Future<void> addVisit() async {
    final hospital = TextEditingController(),
        diagnosis = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (x) => AlertDialog(
        title: const Text('添加就诊记录'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: hospital,
              decoration: const InputDecoration(labelText: '医院'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: diagnosis,
              decoration: const InputDecoration(labelText: '医生诊断原文'),
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
    if (ok == true && hospital.text.trim().isNotEmpty) {
      await widget.session.api.post(
        '/api/v1/families/${widget.session.selectedFamilyId}/health/visits',
        {
          'memberId': memberId,
          'visitedAt': DateTime.now().toUtc().toIso8601String(),
          'hospital': hospital.text.trim(),
          'diagnosis': diagnosis.text.trim(),
        },
      );
      await load();
    }
  }

  Future<void> addMedication() async {
    final name = TextEditingController(), dose = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (x) => AlertDialog(
        title: const Text('添加用药计划'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: '药品名称'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: dose,
              decoration: const InputDecoration(labelText: '每次剂量，例如 1 片'),
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
            child: const Text('每天 08:00 提醒'),
          ),
        ],
      ),
    );
    if (ok == true &&
        name.text.trim().isNotEmpty &&
        dose.text.trim().isNotEmpty) {
      final response = await widget.session.api.post(
        '/api/v1/families/${widget.session.selectedFamilyId}/health/medication-plans',
        {
          'memberId': memberId,
          'medicationName': name.text.trim(),
          'dose': dose.text.trim(),
          'scheduleTimes': ['08:00'],
          'startDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'timezone': 'Asia/Shanghai',
          'source': 'manual',
        },
      );
      final plan = response['data'] as Map<String, dynamic>;
      if (plan['id'] != null) {
        final member = widget.members.firstWhere(
          (item) => item['id'] == memberId,
        );
        await NotificationService.instance.scheduleDailyMedication(
          planId: plan['id'] as String,
          memberName: member['displayName'] as String,
          medicationName: name.text.trim(),
          dose: dose.text.trim(),
          hour: 8,
          minute: 0,
        );
      }
      await load();
    }
  }

  Future<void> confirmMedication(
    Map<String, dynamic> plan,
    String status,
  ) async {
    final now = DateTime.now();
    await widget.session.api.post(
      '/api/v1/families/${widget.session.selectedFamilyId}/health/medication-logs',
      {
        'planId': plan['id'],
        'scheduledAt': DateTime(
          now.year,
          now.month,
          now.day,
          8,
        ).toUtc().toIso8601String(),
        'actualAt': now.toUtc().toIso8601String(),
        'status': status,
        'clientOperationId': const Uuid().v4(),
      },
    );
    if (mounted) {
      await showAppSnackBar(context, status == 'taken' ? '已记录服药' : '已记录跳过');
    }
  }

  Future<void> grantAccess() async {
    if (memberId == null) return;
    final candidates = widget.members
        .where((member) => member['id'] != memberId)
        .toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先添加其他家庭成员')));
      return;
    }
    String granteeId = candidates.first['id'] as String;
    bool canWrite = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('授权查看健康档案'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: granteeId,
                decoration: const InputDecoration(labelText: '授权给'),
                items: candidates
                    .map(
                      (member) => DropdownMenuItem<String>(
                        value: member['id'] as String,
                        child: Text(member['displayName'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) granteeId = value;
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('允许编辑'),
                subtitle: const Text('关闭时仅可查看'),
                value: canWrite,
                onChanged: (value) => setDialogState(() => canWrite = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('确认授权'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await widget.session.api.post(
      '/api/v1/families/${widget.session.selectedFamilyId}/health/access-grants',
      {
        'subjectMemberId': memberId,
        'granteeMemberId': granteeId,
        'canWrite': canWrite,
      },
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('健康档案授权已保存')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = data?['profile'] as Map<String, dynamic>?;
    final visits = (data?['visits'] as List?) ?? [];
    final plans = (data?['medicationPlans'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('健康档案')),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? ErrorRetry(message: error!, onRetry: load)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      const PageHeader(
                        eyebrow: '家庭健康 · 授权后才共享',
                        title: '把关心，放在日常',
                      ),
                      const InfoBanner(
                        icon: Icons.lock_outline_rounded,
                        text: '健康是私事。档案默认不公开，需要本人或监护人授权后，家人才能查看。',
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: memberId,
                        decoration: const InputDecoration(labelText: '家庭成员'),
                        items: widget.members
                            .map(
                              (member) => DropdownMenuItem(
                                value: member['id'] as String,
                                child: Text(member['displayName'] as String),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          memberId = value;
                          load();
                        },
                      ),
                      const SizedBox(height: 8),
                      SectionTitle(
                        '今天的照护',
                        actionLabel: '档案授权',
                        onAction: grantAccess,
                      ),
                      SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '过敏：${profile?['allergies'] ?? '未记录'}',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '慢性病：${profile?['chronicConditions'] ?? '未记录'}',
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: editProfile,
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('编辑基础资料'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: addVisit,
                              icon: const Icon(Icons.local_hospital_outlined),
                              label: const Text('记录就诊'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: addMedication,
                              icon: const Icon(Icons.medication_outlined),
                              label: const Text('用药计划'),
                            ),
                          ),
                        ],
                      ),
                      const SectionTitle('用药计划'),
                      if (plans.isEmpty)
                        const EmptyState(
                          icon: Icons.medication_outlined,
                          message: '还没有用药计划。',
                        ),
                      for (final raw in plans)
                        SoftCard(
                          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.alarm,
                              color: brandCoralDeep,
                            ),
                            title: Text('${raw['medicationName']}'),
                            subtitle: Text(
                              '${raw['dose']} · ${(raw['scheduleTimes'] as List).join('、')}',
                            ),
                            trailing: PopupMenuButton<String>(
                              tooltip: '记录服药',
                              onSelected: (value) => confirmMedication(
                                (raw as Map).cast<String, dynamic>(),
                                value,
                              ),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'taken',
                                  child: Text('已服用'),
                                ),
                                PopupMenuItem(
                                  value: 'skipped',
                                  child: Text('跳过'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SectionTitle('最近就诊'),
                      if (visits.isEmpty)
                        const EmptyState(
                          icon: Icons.local_hospital_outlined,
                          message: '暂无就诊记录。',
                        ),
                      for (final raw in visits)
                        SoftCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${raw['hospital']}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${DateFormat('yyyy-MM-dd').format(DateTime.parse(raw['visitedAt'] as String).toLocal())}${raw['diagnosis'] == null ? '' : ' · ${raw['diagnosis']}'}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        '这里的记录只供家庭照护参考，不构成医疗建议。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
