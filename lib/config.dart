import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Konfigurasi aplikasi VoltTrack Mobile.
class AppConfig {
  /// Base URL REST API Laravel dengan deteksi cerdas:
  /// - Android emulator: `http://10.0.2.2:8000/api`
  /// - iOS / Desktop / Web: `http://127.0.0.1:8000/api`
  /// - Tetap mendukung override melalui `--dart-define=API_BASE_URL=...`
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// IP LAN komputer host (Mac) — WAJIB dipakai saat run di PERANGKAT FISIK
  /// (HP asli), karena HP tidak bisa menjangkau 127.0.0.1 / 10.0.2.2 milik PC.
  /// Jalankan `ipconfig getifaddr en0` di Mac untuk mengecek nilainya.
  /// Override cepat tanpa edit kode:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.107:8000/api
  static const String hostLanIp = '192.168.1.107';

  static String get apiBaseUrl {
    // 1) Override eksplisit selalu menang.
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }
    // 2) Android emulator -> alias host loopback.
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    }
    // 3) iOS (termasuk iPhone FISIK) -> IP LAN Mac, sebab perangkat fisik tidak
    //    bisa menjangkau 127.0.0.1 (itu merujuk ke iPhone itu sendiri).
    //    iPhone & Mac harus di Wi-Fi yang sama. Simulator iOS juga aman memakai
    //    IP LAN ini. Ganti hostLanIp bila IP Mac berubah.
    if (!kIsWeb && Platform.isIOS) {
      return 'http://$hostLanIp:8000/api';
    }
    // 4) macOS Desktop / Web -> localhost Mac.
    return 'http://127.0.0.1:8000/api';
  }

  /// Interval polling live monitoring energy (detik).
  static const int livePollSeconds = 5;

  /// Kredensial demo untuk presentasi instan.
  static const String demoEmail = 'demo@volttrack.com';
  static const String demoPassword = 'password123';

  /// Format angka ke Rupiah standar Indonesia (misal: Rp 4.500.000).
  static String formatRupiah(dynamic amount) {
    if (amount == null) return 'Rp 0';
    final num val = (amount is num)
        ? amount
        : (num.tryParse(amount.toString()) ?? 0);
    final isNegative = val < 0;
    final absInt = val.abs().round();
    final s = absInt.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(s[i]);
    }
    return '${isNegative ? "-Rp " : "Rp "}${buffer.toString()}';
  }
}
