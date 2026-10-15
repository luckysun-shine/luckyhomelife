import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/session_controller.dart';
import '../health/health_page.dart';
import '../growth/growth_page.dart';

class FamilyPage extends StatefulWidget {
  const FamilyPage({super.key, required this.session});
  final SessionController session;

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _families = [];
  List<Map<String, dynamic>> _members = [];
  String? _selectedFamilyId;

  @override
  void initState() {
    super.initState();
    _loadFamilies();
  }

  Future<void> _loadFamilies() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.session.api.get('/api/v1/families');
      _families = (response['data'] as List).cast<Map<String, dynamic>>();
      if (_families.isNotEmpty) {
        _selectedFamilyId =
            widget.session.selectedFamilyId ?? _families.first['id'] as String;
        await widget.session.selectFamily(_selectedFamilyId!);
        await _loadMembers();
      }
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMembers() async {
    final response = await widget.session.api.get(
      '/api/v1/families/$_selectedFamilyId/members',
    );
    _members = (response['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> _createFamily() async {
    final name = TextEditingController(text: '我们家');
    final memberName = TextEditingController(text: '妈妈');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建家庭'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: '家庭名称'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: memberName,
              decoration: const InputDecoration(labelText: '我的家庭称呼'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.session.api.post('/api/v1/families', {
        'name': name.text.trim(),
        'memberName': memberName.text.trim(),
      });
      await widget.session.refreshFamilies();
      await _loadFamilies();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _joinFamily() async {
    final code = TextEditingController();
    final name = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('加入家庭'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: '邀请码'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: '我的家庭称呼'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('加入'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.session.api.post('/api/v1/invites/accept', {
        'code': code.text.trim(),
        'displayName': name.text.trim(),
      });
      await widget.session.refreshFamilies();
      await _loadFamilies();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _createInvite() async {
    if (_selectedFamilyId == null) return;
    var role = 'adult';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('邀请家人'),
          content: DropdownButtonFormField<String>(
            initialValue: role,
            decoration: const InputDecoration(labelText: '加入后的身份'),
            items: const [
              DropdownMenuItem(value: 'adult', child: Text('成人成员')),
              DropdownMenuItem(value: 'elder', child: Text('长辈')),
              DropdownMenuItem(value: 'teen', child: Text('青少年')),
              DropdownMenuItem(value: 'child', child: Text('儿童')),
              DropdownMenuItem(value: 'caregiver', child: Text('临时照护者')),
            ],
            onChanged: (value) => setDialogState(() => role = value ?? 'adult'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('生成邀请码'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      final response = await widget.session.api.post(
        '/api/v1/families/$_selectedFamilyId/invites',
        {'role': role, 'expiresInHours': 48},
      );
      final data = response['data'] as Map<String, dynamic>;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('邀请码已生成'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                data['code'] as String,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const Text('请只发送给需要加入的家人。邀请码将在 48 小时后失效。'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('完成'),
            ),
          ],
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _createManagedMember() async {
    final name = TextEditingController();
    var role = 'child';
    final ok = await showDialog<bool>(
      context: context,
      builder: (x) => StatefulBuilder(
        builder: (x, setDialogState) => AlertDialog(
          title: const Text('添加家庭成员档案'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: '家庭称呼'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: role,
                items: const [
                  DropdownMenuItem(value: 'child', child: Text('儿童')),
                  DropdownMenuItem(value: 'teen', child: Text('青少年')),
                  DropdownMenuItem(value: 'elder', child: Text('长辈')),
                ],
                onChanged: (value) =>
                    setDialogState(() => role = value ?? 'child'),
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
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await widget.session.api.post(
        '/api/v1/families/$_selectedFamilyId/member-profiles',
        {'displayName': name.text.trim(), 'role': role},
      );
      await _loadMembers();
      setState(() {});
    }
  }

  Future<void> _editMember(Map<String, dynamic> member) async {
    final name = TextEditingController(text: member['displayName'] as String);
    var role = member['role'] as String;
    String? guardianId = member['guardianMemberId'] as String?;
    final guardianCandidates = _members
        .where((item) => item['role'] == 'admin' || item['role'] == 'adult')
        .toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('编辑家庭成员'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: '家庭称呼'),
              ),
              const SizedBox(height: 8),
              if (role != 'admin')
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: '家庭身份'),
                  items: const [
                    DropdownMenuItem(value: 'adult', child: Text('成人成员')),
                    DropdownMenuItem(value: 'elder', child: Text('长辈')),
                    DropdownMenuItem(value: 'teen', child: Text('青少年')),
                    DropdownMenuItem(value: 'child', child: Text('儿童')),
                    DropdownMenuItem(value: 'caregiver', child: Text('照护者')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => role = value ?? role),
                ),
              if ((role == 'child' || role == 'teen') &&
                  guardianCandidates.isNotEmpty) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue:
                      guardianCandidates.any((item) => item['id'] == guardianId)
                      ? guardianId
                      : null,
                  decoration: const InputDecoration(labelText: '监护人'),
                  items: guardianCandidates
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item['id'] as String,
                          child: Text(item['displayName'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => guardianId = value),
                ),
              ],
            ],
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
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    await widget.session.api
        .patch('/api/v1/families/$_selectedFamilyId/members/${member['id']}', {
          'displayName': name.text.trim(),
          if (member['role'] != 'admin') 'role': role,
          if (member['role'] != 'admin' && (role == 'child' || role == 'teen'))
            'guardianMemberId': guardianId,
          if (member['role'] != 'admin' && role != 'child' && role != 'teen')
            'guardianMemberId': null,
        });
    await _loadMembers();
    if (mounted) setState(() {});
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移除家庭成员'),
        content: Text('确定将“${member['displayName']}”移出当前家庭吗？相关历史记录不会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认移除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.session.api.delete(
      '/api/v1/families/$_selectedFamilyId/members/${member['id']}',
    );
    await _loadMembers();
    if (mounted) setState(() {});
  }

  Future<void> _transferAdmin(Map<String, dynamic> member) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('交接家庭管理员'),
        content: Text('将管理员交接给“${member['displayName']}”后，你会变为成人成员。是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认交接'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.session.api.post(
      '/api/v1/families/$_selectedFamilyId/admin-transfer',
      {'targetMemberId': member['id']},
    );
    await widget.session.refreshFamilies();
    await _loadFamilies();
  }

  Future<void> _handleMemberAction(
    String action,
    Map<String, dynamic> member,
  ) async {
    try {
      if (action == 'edit') await _editMember(member);
      if (action == 'remove') await _removeMember(member);
      if (action == 'transfer') await _transferAdmin(member);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我们这一家'),
        actions: [
          IconButton(
            onPressed: widget.session.logout,
            tooltip: '退出登录',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _loadFamilies,
                    child: const Text('重试'),
                  ),
                ],
              ),
            )
          : _families.isEmpty
          ? _EmptyFamily(onCreate: _createFamily, onJoin: _joinFamily)
          : RefreshIndicator(
              onRefresh: _loadFamilies,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedFamilyId,
                    decoration: const InputDecoration(labelText: '当前家庭'),
                    items: _families
                        .map(
                          (family) => DropdownMenuItem(
                            value: family['id'] as String,
                            child: Text(family['name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (value) async {
                      _selectedFamilyId = value;
                      if (value != null) {
                        await widget.session.selectFamily(value);
                      }
                      await _loadMembers();
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 20),
                  Text('家庭成员', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  ..._members.map(
                    (member) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            (member['displayName'] as String).characters.first,
                          ),
                        ),
                        title: Text(member['displayName'] as String),
                        subtitle: Text(_roleName(member['role'] as String)),
                        trailing: widget.session.selectedFamily?.role == 'admin'
                            ? PopupMenuButton<String>(
                                onSelected: (action) =>
                                    _handleMemberAction(action, member),
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('编辑成员'),
                                  ),
                                  if (member['accountBound'] == true &&
                                      member['id'] !=
                                          widget
                                              .session
                                              .selectedFamily
                                              ?.memberId &&
                                      member['role'] != 'admin')
                                    const PopupMenuItem(
                                      value: 'transfer',
                                      child: Text('交接管理员'),
                                    ),
                                  if (member['id'] !=
                                          widget
                                              .session
                                              .selectedFamily
                                              ?.memberId &&
                                      member['role'] != 'admin')
                                    const PopupMenuItem(
                                      value: 'remove',
                                      child: Text('移除成员'),
                                    ),
                                ],
                              )
                            : Icon(
                                member['accountBound'] == true
                                    ? Icons.verified_user_outlined
                                    : Icons.person_add_alt_outlined,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.health_and_safety_outlined),
                      title: const Text('家庭健康档案'),
                      subtitle: const Text('体检、就诊、用药计划和服药确认'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HealthPage(
                            session: widget.session,
                            members: _members,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.auto_awesome_outlined),
                      title: const Text('成长记录'),
                      subtitle: const Text('保存孩子和家人的成长里程碑'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GrowthPage(
                            session: widget.session,
                            members: _members,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _createManagedMember,
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('添加儿童或长辈档案'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _createInvite,
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('邀请家人'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _joinFamily,
                    icon: const Icon(Icons.group_add_outlined),
                    label: const Text('使用邀请码加入另一个家庭'),
                  ),
                ],
              ),
            ),
    );
  }

  String _roleName(String role) =>
      const {
        'admin': '家庭管理员',
        'adult': '成人成员',
        'elder': '长辈',
        'teen': '青少年',
        'child': '儿童',
        'caregiver': '照护者',
      }[role] ??
      role;
}

class _EmptyFamily extends StatelessWidget {
  const _EmptyFamily({required this.onCreate, required this.onJoin});
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.family_restroom, size: 72),
          const SizedBox(height: 20),
          Text('建立你的家庭空间', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('创建一个新家庭，或者使用家人发来的邀请码加入。', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onCreate, child: const Text('创建家庭')),
          TextButton(onPressed: onJoin, child: const Text('使用邀请码加入')),
        ],
      ),
    ),
  );
}
