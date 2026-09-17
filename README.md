# VoltTrack Mobile (Flutter)

Aplikasi pelanggan VoltTrack. Mengonsumsi REST API Laravel di `volttrack_os-laravel`
(auth token Sanctum). Bagian dari workspace VOLTTRACK, sejajar dengan backend.

## Fitur
- Login / Register (token Sanctum, disimpan aman via flutter_secure_storage)
- Marketplace (daftar produk)
- Order milik user
- Live monitoring energi (polling `/energy/{id}/latest` tiap 5 detik)

## Menjalankan
1. Jalankan backend Laravel lebih dulu:
   ```
   cd ../volttrack_os-laravel && php artisan serve
   ```
2. Sesuaikan base URL API bila perlu (default `http://127.0.0.1:8000/api`):
   - Android emulator: `--dart-define=API_BASE_URL=http://10.0.2.2:8000/api`
   - Device fisik: pakai IP komputer Anda
3. Jalankan app:
   ```
   flutter run
   # atau dengan base URL kustom:
   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
   ```

## Struktur
- `lib/config.dart` — konfigurasi base URL & interval polling
- `lib/services/` — api_client (Bearer token), auth_service, data_service
- `lib/screens/` — login, home (marketplace + orders), monitoring (live)

## Uji cepat data telemetri (agar monitoring "hidup")
Di backend, jalankan simulator untuk perangkat milik user yang login:
```
php artisan telemetry:simulate --token=<device_token> --interval=5
```
`device_token` didapat dari aktivasi garansi perangkat.
