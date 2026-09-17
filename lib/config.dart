/// Konfigurasi aplikasi VoltTrack Mobile.
class AppConfig {
  /// Base URL REST API Laravel.
  ///
  /// Catatan platform:
  /// - Android emulator: gunakan `http://10.0.2.2:8000/api`
  /// - iOS simulator / desktop / web: `http://127.0.0.1:8000/api`
  /// - Device fisik: `http://IP-komputer:8000/api`
  ///
  /// Jalankan backend: `php artisan serve` di folder volttrack_os-laravel.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api',
  );

  /// Interval polling live monitoring energy (detik).
  static const int livePollSeconds = 5;
}
