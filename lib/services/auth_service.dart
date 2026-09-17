import 'api_client.dart';

/// Layanan autentikasi terhadap API Laravel (Sanctum).
class AuthService {
  final _api = ApiClient.instance;

  /// Login -> simpan token. Mengembalikan pesan error bila gagal, null bila sukses.
  Future<String?> login(String email, String password) async {
    final res = await _api.post('/login', {
      'email': email,
      'password': password,
      'device_name': 'flutter',
    }, auth: false);

    if (res.ok && res.body is Map && res.body['token'] != null) {
      await _api.saveToken(res.body['token'] as String);
      return null;
    }

    if (res.body is Map && res.body['action_required'] == 'force_password_reset') {
      return 'Kata sandi usang. Silakan reset kata sandi Anda.';
    }
    if (res.body is Map && res.body['message'] != null) {
      return res.body['message'] as String;
    }
    return 'Login gagal (HTTP ${res.status}).';
  }

  /// Registrasi akun baru. Null bila sukses, pesan error bila gagal.
  Future<String?> register(String fullName, String email, String password) async {
    final res = await _api.post('/register', {
      'full_name': fullName,
      'email': email,
      'password': password,
    }, auth: false);

    if (res.ok) return null;
    if (res.body is Map && res.body['message'] != null) {
      return res.body['message'] as String;
    }
    return 'Registrasi gagal (HTTP ${res.status}).';
  }

  Future<Map<String, dynamic>?> me() async {
    final res = await _api.get('/me');
    if (res.ok && res.body is Map) {
      return (res.body['user'] as Map).cast<String, dynamic>();
    }
    return null;
  }

  Future<void> logout() async {
    await _api.post('/logout', {});
    await _api.clearToken();
  }

  Future<bool> isLoggedIn() async => (await _api.token) != null;
}
