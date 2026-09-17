import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

/// Hasil pemanggilan API yang seragam.
class ApiResult {
  final int status;
  final dynamic body;

  ApiResult(this.status, this.body);

  bool get ok => status >= 200 && status < 300;
}

/// Client HTTP terpusat untuk API VoltTrack (Sanctum Bearer token).
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'volttrack_token';

  String? _token;

  Future<String?> get token async {
    _token ??= await _storage.read(key: _tokenKey);
    return _token;
  }

  Future<void> saveToken(String token) async {
    _token = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> clearToken() async {
    _token = null;
    await _storage.delete(key: _tokenKey);
  }

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (auth) {
      final t = await token;
      if (t != null) headers['Authorization'] = 'Bearer $t';
    }
    return headers;
  }

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Future<ApiResult> get(String path, {bool auth = true}) async {
    final res = await http.get(_uri(path), headers: await _headers(auth: auth));
    return _parse(res);
  }

  Future<ApiResult> post(
    String path,
    Map<String, dynamic> data, {
    bool auth = true,
  }) async {
    final res = await http.post(
      _uri(path),
      headers: await _headers(auth: auth),
      body: jsonEncode(data),
    );
    return _parse(res);
  }

  Future<ApiResult> put(
    String path,
    Map<String, dynamic> data, {
    bool auth = true,
  }) async {
    final res = await http.put(
      _uri(path),
      headers: await _headers(auth: auth),
      body: jsonEncode(data),
    );
    return _parse(res);
  }

  /// Upload file (multipart) — mis. bukti pembayaran.
  Future<ApiResult> uploadFile(
    String path,
    String fieldName,
    String filePath,
  ) async {
    final request = http.MultipartRequest('POST', _uri(path));
    final t = await token;
    request.headers['Accept'] = 'application/json';
    if (t != null) request.headers['Authorization'] = 'Bearer $t';
    request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _parse(res);
  }

  ApiResult _parse(http.Response res) {
    dynamic body;
    try {
      body = res.body.isNotEmpty ? jsonDecode(res.body) : null;
    } catch (_) {
      body = res.body;
    }
    return ApiResult(res.statusCode, body);
  }
}
