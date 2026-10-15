import 'package:uuid/uuid.dart';

class PendingOperation {
  const PendingOperation({
    required this.id,
    required this.method,
    required this.path,
    required this.body,
    required this.attempts,
  });
  final String id;
  final String method;
  final String path;
  final Map<String, dynamic> body;
  final int attempts;
}

class _Pending {
  _Pending({
    required this.id,
    required this.method,
    required this.path,
    required this.body,
    required this.createdAt,
    required this.attempts,
  });
  final String id;
  final String method;
  final String path;
  final Map<String, dynamic> body;
  final int createdAt;
  int attempts;
  String? lastError;
}

class OfflineStore {
  OfflineStore._();
  static final shared = OfflineStore._();
  final Map<String, Map<String, dynamic>> _cache = {};
  final Map<String, _Pending> _pending = {};

  Future<void> cache(String key, Map<String, dynamic> payload) async {
    _cache[key] = payload;
  }

  Future<Map<String, dynamic>?> cached(String key) async => _cache[key];

  Future<String> enqueue(
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    final id = const Uuid().v4();
    _pending[id] = _Pending(
      id: id,
      method: method,
      path: path,
      body: body,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      attempts: 0,
    );
    return id;
  }

  Future<List<PendingOperation>> pending() async {
    final items = _pending.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items
        .take(100)
        .map(
          (item) => PendingOperation(
            id: item.id,
            method: item.method,
            path: item.path,
            body: item.body,
            attempts: item.attempts,
          ),
        )
        .toList();
  }

  Future<void> remove(String id) async {
    _pending.remove(id);
  }

  Future<void> failed(String id, String message) async {
    final item = _pending[id];
    if (item == null) return;
    item.attempts += 1;
    item.lastError = message;
  }

  Future<int> count() async => _pending.length;

  Future<void> clearSensitiveData() async {
    _cache.clear();
    _pending.clear();
  }
}
