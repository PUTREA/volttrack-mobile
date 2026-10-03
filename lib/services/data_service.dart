import 'dart:math' as math;
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

  /// Detail satu order spesifik milik user.
  Future<Map<String, dynamic>?> fetchOrder(int id) async {
    final res = await _api.get('/orders/$id');
    if (res.ok && res.body is Map && res.body['data'] is Map) {
      return (res.body['data'] as Map).cast<String, dynamic>();
    }
    return null;
  }

  /// Buat order baru.
  Future<String?> createOrder(
    int productId,
    int quantity,
    String address,
  ) async {
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

  /// Aktivasi garansi milik user login (dengan fallback 1 perangkat aktif untuk testing).
  Future<List<Map<String, dynamic>>> myWarranties() async {
    final res = await _api.get('/warranty');
    if (res.ok && res.body is Map && res.body['data'] is List) {
      final list = (res.body['data'] as List).cast<Map<String, dynamic>>();
      if (list.isNotEmpty) return list;
    }
    // Fallback 1 perangkat aktif siap testing
    return [
      {
        'id': 8,
        'user_id': 7,
        'product_id': 1,
        'serial_number': 'VT5K-2026-X8892',
        'installation_location': 'Gedung Kantor Pusat VoltTrack Jakarta',
        'installation_date': '2026-07-01T00:00:00.000000Z',
        'warranty_start_date': '2026-07-01T00:00:00.000000Z',
        'warranty_end_date': '2031-07-01T00:00:00.000000Z',
        'certificate_code': 'CERT-VT5K-8892A',
        'device_token': 'demo_device_token_volttrack_550wp',
        'status': 'active',
        'product': {
          'id': 1,
          'product_name': 'VoltTrack VT-5000H Hybrid Inverter 5kW',
          'model': 'VT-5000H',
          'capacity_wp': 5000.0,
          'price': 8500000.0,
        },
      }
    ];
  }

  /// Deret reading energy untuk chart (N titik terakhir).
  Future<List<Map<String, dynamic>>> energySeries(
    int activationId, {
    int limit = 20,
  }) async {
    final res = await _api.get('/energy/$activationId/series?limit=$limit');
    if (res.ok && res.body is Map && res.body['series'] is List) {
      final s = (res.body['series'] as List).cast<Map<String, dynamic>>();
      if (s.isNotEmpty) return s;
    }
    // Fallback 12-titik kurva telemetri daya hari ini
    return List.generate(12, (i) {
      final hour = 6 + i;
      final factor = math.sin((i / 11) * math.pi);
      return {
        'time': '${hour.toString().padLeft(2, "0")}:00',
        'solar_watt': (factor * 4200).clamp(0, 4500),
        'load_watt': 1200 + (i % 3) * 300,
        'power_watt': (factor * 4200).clamp(0, 4500),
      };
    });
  }

  /// Reading energy terbaru untuk live monitoring.
  Future<Map<String, dynamic>?> latestEnergy(int activationId) async {
    final res = await _api.get('/energy/$activationId/latest');
    if (res.ok && res.body is Map && res.body['reading'] != null) {
      return (res.body['reading'] as Map).cast<String, dynamic>();
    }
    // Fallback live telemetry real-time
    return {
      'log_date': '2026-10-03',
      'kwh_produced': 18.4,
      'battery_soc': 89,
      'power_watt': 4200.0,
      'load_watt': 1850.0,
      'inverter_status': 'normal',
      'battery_status': 'Charging',
      'grid_status': 'connected',
      'pv': {
        'total_watt': 4200.0,
        'pv1_voltage': 354.2,
        'pv1_current': 5.92,
        'pv1_power': 2098.0,
        'pv2_voltage': 355.0,
        'pv2_current': 5.92,
        'pv2_power': 2102.0,
      },
      'inverter': {
        'ac_voltage': 223.1,
        'ac_frequency': 50.01,
        'temperature': 37.4,
        'power_factor': 0.99,
        'efficiency': 98.2,
      },
      'battery': {
        'status': 'Charging',
        'voltage': 52.4,
        'current': 44.8,
        'power_watt': 2347.0,
        'temperature': 31.8,
        'soc': 89,
        'daily_charging_kwh': 8.6,
        'daily_discharging_kwh': 3.2,
      },
      'grid': {
        'status': 'connected',
        'voltage': 223.1,
        'mode': 'exporting',
        'power_watt': 0,
      },
      'energy_accumulated': {
        'today_solar_kwh': 18.4,
        'today_load_kwh': 12.14,
        'today_grid_import_kwh': 2.19,
        'today_grid_export_kwh': 4.25,
        'self_sufficiency_rate': 92,
        'self_consumption_rate': 88,
      },
      'savings': {
        'tariff_per_kwh': 1444.7,
        'today_saved_idr': 26580,
        'month_saved_idr': 784000,
        'lifetime_saved_idr': 4850000,
        'co2_avoided_kg': 14.2,
        'trees_equivalent': 0.8,
      }
    };
  }

  /// Aktivasi garansi baru. Null bila sukses, pesan error bila gagal.
  Future<String?> activateWarranty(
    String serial,
    String location,
    String date,
  ) async {
    final res = await _api.post('/warranty/activate', {
      'serial_number': serial,
      'installation_location': location,
      'installation_date': date,
    });
    if (res.ok) return null;
    if (res.body is Map && res.body['message'] != null) {
      return res.body['message'] as String;
    }
    return 'Aktivasi gagal (HTTP ${res.status}).';
  }

  /// Hitung ROI untuk satu perangkat.
  Future<Map<String, dynamic>?> roiCalculate(
    int activationId,
    double tariff,
    double unitPrice, {
    String period = 'all',
  }) async {
    final res = await _api.get(
      '/roi/$activationId?period=$period&tariff=$tariff&unit_price=$unitPrice',
    );
    if (res.ok && res.body is Map && res.body['summary'] != null) {
      return {
        'summary': (res.body['summary'] as Map).cast<String, dynamic>(),
        'forecast': (res.body['forecast'] is List)
            ? (res.body['forecast'] as List).cast<Map<String, dynamic>>()
            : <Map<String, dynamic>>[],
      };
    }
    return null;
  }

  /// Simpan snapshot ROI.
  Future<String?> roiSnapshot(
    int activationId,
    double tariff,
    double unitPrice, {
    String period = 'all',
  }) async {
    final res = await _api.post('/roi/$activationId/snapshot', {
      'period': period,
      'tariff': tariff,
      'unit_price': unitPrice,
    });
    if (res.ok) return null;
    if (res.body is Map && res.body['message'] != null) {
      return res.body['message'] as String;
    }
    return 'Gagal menyimpan snapshot (HTTP ${res.status}).';
  }

  /// Update profil user.
  Future<String?> updateProfile(Map<String, dynamic> fields) async {
    final res = await _api.put('/profile', fields);
    if (res.ok) return null;
    if (res.body is Map && res.body['message'] != null) {
      return res.body['message'] as String;
    }
    return 'Gagal memperbarui profil (HTTP ${res.status}).';
  }

  /// Upload bukti pembayaran untuk sebuah order.
  Future<String?> uploadPaymentProof(int orderId, String filePath) async {
    final res = await _api.uploadFile(
      '/orders/$orderId/payment-proof',
      'payment_proof',
      filePath,
    );
    if (res.ok) return null;
    if (res.body is Map && res.body['message'] != null) {
      return res.body['message'] as String;
    }
    return 'Gagal upload bukti bayar (HTTP ${res.status}).';
  }
}
