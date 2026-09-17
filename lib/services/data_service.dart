import 'api_client.dart';

/// Layanan pengambilan data bisnis dari API VoltTrack (read + write ringan).
class DataService {
  final _api = ApiClient.instance;

  /// Daftar produk marketplace (publik).
  Future<List<Map<String, dynamic>>> products() async {
    final res = await _api.get('/marketplace', auth: false);
    if (res.ok && res.body is Map && res.body['data'] is List) {
      return (res.body['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Order milik user login.
  Future<List<Map<String, dynamic>>> myOrders() async {
    final res = await _api.get('/orders');
    if (res.ok && res.body is Map && res.body['data'] is List) {
      return (res.body['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Buat order baru.
  Future<String?> createOrder(int productId, int quantity, String address) async {
    final res = await _api.post('/orders', {
      'product_id': productId,
      'quantity': quantity,
      'shipping_address': address,
    });
    if (res.ok) return null;
    if (res.body is Map && res.body['message'] != null) {
      return res.body['message'] as String;
    }
    return 'Gagal membuat order (HTTP ${res.status}).';
  }

  /// Aktivasi garansi milik user login.
  Future<List<Map<String, dynamic>>> myWarranties() async {
    final res = await _api.get('/warranty');
    if (res.ok && res.body is Map && res.body['data'] is List) {
      return (res.body['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Reading energy terbaru untuk live monitoring.
  Future<Map<String, dynamic>?> latestEnergy(int activationId) async {
    final res = await _api.get('/energy/$activationId/latest');
    if (res.ok && res.body is Map && res.body['reading'] != null) {
      return (res.body['reading'] as Map).cast<String, dynamic>();
    }
    return null;
  }
}
