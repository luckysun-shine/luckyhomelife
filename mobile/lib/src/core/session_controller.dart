import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class FamilySummary {
  const FamilySummary({
    required this.id,
    required this.name,
    required this.memberId,
    required this.role,
  });
  final String id;
  final String name;
  final String memberId;
  final String role;

  factory FamilySummary.fromJson(Map<String, dynamic> json) => FamilySummary(
    id: json['id'] as String,
    name: json['name'] as String,
    memberId: json['memberId'] as String,
    role: json['role'] as String,
  );
}

class SessionController extends ChangeNotifier {
  SessionController({ApiClient? api, FlutterSecureStorage? storage})
    : _baseApi = api ?? ApiClient(),
      _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'family_os_access_token';
  static const _familyKey = 'family_os_selected_family';
  final ApiClient _baseApi;
  final FlutterSecureStorage _storage;
  String? _token;
  bool initialized = false;
  bool loadingFamilies = false;
  int pendingOperations = 0;
  List<FamilySummary> families = [];
  String? selectedFamilyId;

  bool get isAuthenticated => _token != null;
  ApiClient get api => _token == null ? _baseApi : _baseApi.withToken(_token!);
  FamilySummary? get selectedFamily {
    for (final family in families) {
      if (family.id == selectedFamilyId) return family;
    }
    return families.isEmpty ? null : families.first;
  }

  Future<void> initialize() async {
    _token = await _storage.read(key: _tokenKey);
    selectedFamilyId = (await SharedPreferences.getInstance()).getString(
      _familyKey,
    );
    if (_token != null) {
      try {
        await refreshFamilies();
      } on ApiException catch (error) {
        if (error.statusCode == 401) await logout();
      }
    }
    initialized = true;
    notifyListeners();
  }

  Future<void> login(String token) async {
    _token = token;
    await _storage.write(key: _tokenKey, value: token);
    await refreshFamilies();
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    families = [];
    selectedFamilyId = null;
    await _storage.delete(key: _tokenKey);
    await api.clearLocalData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_familyKey);
    notifyListeners();
  }

  Future<void> refreshFamilies() async {
    loadingFamilies = true;
    notifyListeners();
    try {
      final response = await api.get('/api/v1/families');
      families = (response['data'] as List)
          .map((item) => FamilySummary.fromJson(item as Map<String, dynamic>))
          .toList();
      if (families.isNotEmpty &&
          !families.any((family) => family.id == selectedFamilyId)) {
        await selectFamily(families.first.id);
      }
      await api.syncPending();
      pendingOperations = await api.pendingCount();
    } finally {
      loadingFamilies = false;
      notifyListeners();
    }
  }

  Future<void> selectFamily(String familyId) async {
    selectedFamilyId = familyId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_familyKey, familyId);
    notifyListeners();
  }
}
