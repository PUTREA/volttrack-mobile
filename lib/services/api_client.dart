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

/// Satu event Server-Sent Events: nama event + payload JSON ter-decode.
class SseEvent {
  final String event;
  final Map<String, dynamic> data;

  const SseEvent(this.event, this.data);
}

/// Client HTTP terpusat untuk API VoltTrack (Sanctum Bearer token).
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static const _tokenKey = 'volttrack_token';

  String? _token;

  /// Getter MURNI: hanya membaca token tersimpan. TIDAK melakukan login diam-diam.
  /// (Auto-login demo dulu di sini menyebabkan sesi membajak login manual &
  /// menyembunyikan error koneksi — dipindah ke pemanggil eksplisit di _Gate.)
  Future<String?> get token async {
    if (_token != null) return _token;
    try {
      _token = await _storage
          .read(key: _tokenKey)
          .timeout(const Duration(milliseconds: 1500), onTimeout: () => null);
    } catch (_) {
      _token = null;
    }
    return _token;
  }

  Future<void> saveToken(String token) async {
    _token = token;
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {}
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
    try {
      final res = await http
          .get(_uri(path), headers: await _headers(auth: auth))
          .timeout(const Duration(seconds: 8));
      return _parse(res);
    } catch (e) {
      return ApiResult(500, {'message': 'Koneksi timeout/gagal: $e'});
    }
  }

  Future<ApiResult> post(
    String path,
    Map<String, dynamic> data, {
    bool auth = true,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final res = await http
          .post(
            _uri(path),
            headers: await _headers(auth: auth),
            body: jsonEncode(data),
          )
          .timeout(timeout);
      return _parse(res);
    } catch (e) {
      return ApiResult(500, {'message': 'Koneksi timeout/gagal: $e'});
    }
  }

  /// POST yang menghasilkan aliran SSE (`event:` / `data:`). Dipakai AURA streaming.
  ///
  /// Melempar bila gagal menyambung atau status awal bukan 2xx — pemanggil
  /// menangkapnya untuk fallback ke endpoint JSON biasa.
  Stream<SseEvent> postStream(
    String path,
    Map<String, dynamic> data, {
    bool auth = true,
  }) async* {
    final client = http.Client();
    try {
      final req = http.Request('POST', _uri(path));
      req.headers.addAll(await _headers(auth: auth));
      req.headers['Accept'] = 'text/event-stream';
      req.body = jsonEncode(data);

      final streamed = await client
          .send(req)
          .timeout(const Duration(seconds: 60));
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        // Baca sedikit body untuk pesan, lalu lempar agar caller fallback.
        final body = await streamed.stream.bytesToString();
        throw http.ClientException('SSE HTTP ${streamed.statusCode}: $body');
      }

      final lines = streamed.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      String? eventName;
      final dataBuf = StringBuffer();

      await for (final line in lines) {
        if (line.isEmpty) {
          // Baris kosong = akhir satu event. Emit bila ada data.
          if (dataBuf.isNotEmpty) {
            final raw = dataBuf.toString();
            dataBuf.clear();
            Map<String, dynamic> parsed;
            try {
              final decoded = jsonDecode(raw);
              parsed = decoded is Map
                  ? Map<String, dynamic>.from(decoded)
                  : {'value': decoded};
            } catch (_) {
              parsed = {'raw': raw};
            }
            yield SseEvent(eventName ?? 'message', parsed);
          }
          eventName = null;
          continue;
        }
        if (line.startsWith('event:')) {
          eventName = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          // Beberapa frame bisa punya banyak baris data.
          if (dataBuf.isNotEmpty) dataBuf.write('\n');
          dataBuf.write(line.substring(5).trim());
        }
        // baris lain (comment ':', id:, retry:) diabaikan.
      }

      // Flush sisa buffer bila stream berakhir tanpa baris kosong penutup.
      if (dataBuf.isNotEmpty) {
        try {
          final decoded = jsonDecode(dataBuf.toString());
          if (decoded is Map) {
            yield SseEvent(
              eventName ?? 'message',
              Map<String, dynamic>.from(decoded),
            );
          }
        } catch (_) {}
      }
    } finally {
      client.close();
    }
  }

  Future<ApiResult> put(
    String path,
    Map<String, dynamic> data, {
    bool auth = true,
  }) async {
    try {
      final res = await http
          .put(
            _uri(path),
            headers: await _headers(auth: auth),
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 8));
      return _parse(res);
    } catch (e) {
      return ApiResult(500, {'message': 'Koneksi timeout/gagal: $e'});
    }
  }

  Future<ApiResult> delete(String path, {bool auth = true}) async {
    try {
      final res = await http
          .delete(_uri(path), headers: await _headers(auth: auth))
          .timeout(const Duration(seconds: 8));
      return _parse(res);
    } catch (e) {
      return ApiResult(500, {'message': 'Koneksi timeout/gagal: $e'});
    }
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
