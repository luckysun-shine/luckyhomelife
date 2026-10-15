import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'offline_store.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.code, this.statusCode});
  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    String? baseUrl,
    this.accessToken,
    http.Client? httpClient,
    OfflineStore? offlineStore,
  }) : baseUrl = _resolveBaseUrl(baseUrl),
       _httpClient = httpClient ?? http.Client(),
       _offlineStore = offlineStore ?? OfflineStore.shared;

  final String baseUrl;
  final String? accessToken;
  final http.Client _httpClient;
  final OfflineStore _offlineStore;

  static String _resolveBaseUrl(String? baseUrl) {
    final configured =
        baseUrl ??
        const String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (configured.isNotEmpty) return configured;
    return kIsWeb ? 'http://localhost:8080' : 'http://10.0.2.2:8080';
  }

  ApiClient withToken(String token) => ApiClient(
    baseUrl: baseUrl,
    accessToken: token,
    httpClient: _httpClient,
    offlineStore: _offlineStore,
  );

  Future<int> pendingCount() => _offlineStore.count();
  Future<void> clearLocalData() => _offlineStore.clearSensitiveData();
  Future<void> syncPending() async {
    for (final operation in await _offlineStore.pending()) {
      try {
        await _request(
          operation.method,
          operation.path,
          operation.body,
          allowQueue: false,
        );
        await _offlineStore.remove(operation.id);
      } on ApiException catch (error) {
        if (error.statusCode != null &&
            error.statusCode! >= 400 &&
            error.statusCode! < 500) {
          await _offlineStore.remove(operation.id);
        } else {
          await _offlineStore.failed(operation.id, error.message);
          break;
        }
      }
    }
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      _request('POST', path, body);
  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) =>
      _request('PATCH', path, body);
  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) =>
      _request('PUT', path, body);
  Future<Map<String, dynamic>> get(String path) => _request('GET', path, null);
  Future<Map<String, dynamic>> delete(String path) =>
      _request('DELETE', path, null);

  Future<Map<String, dynamic>> uploadMedia(
    String path,
    List<int> bytes,
    String mimeType,
  ) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl$path'),
        headers: {
          'Content-Type': mimeType,
          if (accessToken != null) 'Authorization': 'Bearer $accessToken',
        },
        body: bytes,
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          (json['error'] as Map<String, dynamic>?)?['message'] as String? ??
              '照片上传失败',
          statusCode: response.statusCode,
        );
      }
      return json;
    } on http.ClientException {
      throw const ApiException('照片尚未上传，请恢复网络后重试');
    }
  }

  Future<List<int>> downloadBytes(String path) async {
    final response = await _httpClient.get(
      Uri.parse('$baseUrl$path'),
      headers: {
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode != 200) {
      throw ApiException('照片无法访问', statusCode: response.statusCode);
    }
    return response.bodyBytes;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path,
    Map<String, dynamic>? body, {
    bool allowQueue = true,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };
      final encoded = body == null ? null : jsonEncode(body);
      final response = await switch (method) {
        'POST' => _httpClient.post(uri, headers: headers, body: encoded),
        'PATCH' => _httpClient.patch(uri, headers: headers, body: encoded),
        'PUT' => _httpClient.put(uri, headers: headers, body: encoded),
        'DELETE' => _httpClient.delete(uri, headers: headers),
        _ => _httpClient.get(uri, headers: headers),
      }.timeout(const Duration(seconds: 15));
      final raw = response.body;
      final json = raw.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = json['error'] as Map<String, dynamic>?;
        throw ApiException(
          error?['message'] as String? ?? '请求失败，请稍后重试',
          code: error?['code'] as String?,
          statusCode: response.statusCode,
        );
      }
      if (method == 'GET') await _offlineStore.cache(path, json);
      return json;
    } on ApiException {
      rethrow;
    } on http.ClientException {
      return _offlineFallback(method, path, body, allowQueue);
    } on TimeoutException {
      return _offlineFallback(method, path, body, allowQueue);
    } on FormatException {
      throw const ApiException('服务器返回了无法识别的数据');
    }
  }

  Future<Map<String, dynamic>> _offlineFallback(
    String method,
    String path,
    Map<String, dynamic>? body,
    bool allowQueue,
  ) async {
    if (method == 'GET') {
      final cached = await _offlineStore.cached(path);
      if (cached != null) return {...cached, 'offline': true};
    }
    if (allowQueue && body != null && _queueable(method, path)) {
      final id = await _offlineStore.enqueue(method, path, body);
      return {
        'data': {'pendingSync': true, 'localOperationId': id},
      };
    }
    throw const ApiException('无法连接家庭服务器，请检查网络或 NAS 状态');
  }

  bool _queueable(String method, String path) =>
      {'POST', 'PATCH', 'PUT'}.contains(method) &&
      (path.contains('/tasks') ||
          path.contains('/events') ||
          path.contains('/transactions') ||
          path.contains('/records') ||
          path.contains('/growth-milestones') ||
          path.contains('/medication-logs'));
}
