import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/api_client.dart';
import '../../core/session_controller.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key, required this.session, this.composer});
  final SessionController session;
  final ValueNotifier<String?>? composer;
  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  bool loading = true;
  String? error;
  List<dynamic> items = [];
  List<Map<String, dynamic>> members = [];
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
    if (widget.composer?.value != 'record') return;
    widget.composer?.value = null;
    add();
  }

  Future<void> load() async {
    final f = widget.session.selectedFamilyId;
    if (f == null) {
      setState(() => loading = false);
      return;
    }
    setState(() => loading = true);
    try {
      final responses = await Future.wait([
        widget.session.api.get('/api/v1/families/$f/records?limit=50'),
        widget.session.api.get('/api/v1/families/$f/members'),
      ]);
      items = responses[0]['data'] as List;
      members = (responses[1]['data'] as List).cast<Map<String, dynamic>>();
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> add() async {
    final text = TextEditingController();
    XFile? photo;
    var visibility = 'family';
    final viewerIds = <String>{};
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (x) => StatefulBuilder(
        builder: (x, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(x).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('记录此刻', style: Theme.of(x).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: text,
                maxLines: 5,
                autofocus: true,
                decoration: const InputDecoration(labelText: '发生了什么？'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: visibility,
                decoration: const InputDecoration(labelText: '谁可以看'),
                items: const [
                  DropdownMenuItem(value: 'family', child: Text('全家可见')),
                  DropdownMenuItem(value: 'self', child: Text('仅自己可见')),
                  DropdownMenuItem(value: 'admins', child: Text('仅我和管理员')),
                  DropdownMenuItem(value: 'selected', child: Text('指定家庭成员')),
                ],
                onChanged: (value) =>
                    setSheetState(() => visibility = value ?? 'family'),
              ),
              if (visibility == 'selected')
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: ListView(
                    shrinkWrap: true,
                    children: members
                        .map(
                          (member) => CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(member['displayName'] as String),
                            value: viewerIds.contains(member['id']),
                            onChanged: (selected) => setSheetState(() {
                              if (selected == true) {
                                viewerIds.add(member['id'] as String);
                              } else {
                                viewerIds.remove(member['id']);
                              }
                            }),
                          ),
                        )
                        .toList(),
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final selected = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 88,
                    maxWidth: 2400,
                  );
                  if (selected != null) setSheetState(() => photo = selected);
                },
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(photo == null ? '选择照片' : '已选择 ${photo!.name}'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: visibility == 'selected' && viewerIds.isEmpty
                    ? null
                    : () => Navigator.pop(x, true),
                child: const Text('发布到家庭时间线'),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true && text.text.trim().isNotEmpty) {
      final response = await widget.session.api
          .post('/api/v1/families/${widget.session.selectedFamilyId}/records', {
            'body': text.text.trim(),
            'happenedAt': DateTime.now().toUtc().toIso8601String(),
            'visibility': visibility,
            'memberIds': [],
            'viewerMemberIds': viewerIds.toList(),
            'clientOperationId': const Uuid().v4(),
          });
      final record = response['data'] as Map<String, dynamic>;
      if (photo != null &&
          record['id'] != null &&
          record['pendingSync'] != true) {
        final mime = photo!.name.toLowerCase().endsWith('.png')
            ? 'image/png'
            : 'image/jpeg';
        await widget.session.api.uploadMedia(
          '/api/v1/families/${widget.session.selectedFamilyId}/media?recordId=${record['id']}&mimeType=${Uri.encodeComponent(mime)}',
          await photo!.readAsBytes(),
          mime,
        );
      }
      if (mounted) await showAppSnackBar(context, '已发布到家庭时间线');
      await load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton(
      tooltip: '发布家庭记录',
      onPressed: add,
      child: const Icon(Icons.add),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? ErrorRetry(message: error!, onRetry: load)
        : RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 96),
              children: [
                PageHeader(
                  eyebrow:
                      '${widget.session.selectedFamily?.name ?? '我们家'} · 家庭时间线',
                  title: '日子，有迹可循',
                ),
                if (items.isEmpty)
                  EmptyState(
                    icon: Icons.auto_stories_outlined,
                    message: '还没有家庭记录，写下第一件小事吧。',
                    actionLabel: '发布记录',
                    onAction: add,
                  )
                else
                  for (final raw in items)
                    SoftCard(
                      child: _RecordBody(
                        item: (raw as Map).cast<String, dynamic>(),
                        session: widget.session,
                        visibilityName: _visibilityName,
                      ),
                    ),
                const SizedBox(height: 8),
                Text(
                  '每个普通日子，都在慢慢发光。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
  );

  String _visibilityName(String value) =>
      const {
        'family': '全家可见',
        'self': '仅自己可见',
        'admins': '仅我和管理员',
        'selected': '指定成员可见',
        'guardians': '本人和监护人可见',
      }[value] ??
      value;
}

class _RecordBody extends StatelessWidget {
  const _RecordBody({
    required this.item,
    required this.session,
    required this.visibilityName,
  });

  final Map<String, dynamic> item;
  final SessionController session;
  final String Function(String value) visibilityName;

  @override
  Widget build(BuildContext context) {
    final media = (item['media'] as List?) ?? const [];
    final happened = DateTime.parse(item['happenedAt'] as String).toLocal();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: brandMist,
              foregroundColor: brandTealDeep,
              child: Text('${item['createdByName'] ?? '家'}'.characters.first),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item['createdByName'] ?? '家人'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${DateFormat('M月d日 HH:mm').format(happened)} · ${visibilityName(item['visibility'] as String? ?? 'family')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (media.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ProtectedPhoto(
            api: session.api,
            familyId: session.selectedFamilyId!,
            mediaId: media.first['id'] as String,
          ),
        ],
        const SizedBox(height: 12),
        Text(
          '${item['body'] ?? ''}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class _ProtectedPhoto extends StatelessWidget {
  const _ProtectedPhoto({
    required this.api,
    required this.familyId,
    required this.mediaId,
  });
  final ApiClient api;
  final String familyId;
  final String mediaId;
  @override
  Widget build(BuildContext context) => FutureBuilder<List<int>>(
    future: api.downloadBytes('/api/v1/families/$familyId/media/$mediaId'),
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            Uint8List.fromList(snapshot.data!),
            height: 190,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        );
      }
      if (snapshot.hasError) {
        return const SizedBox(
          height: 80,
          child: Center(child: Icon(Icons.broken_image_outlined)),
        );
      }
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    },
  );
}
