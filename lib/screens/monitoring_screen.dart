import 'dart:async';

import 'package:flutter/material.dart';

import '../config.dart';
import '../services/data_service.dart';

/// Live monitoring energi: pilih perangkat (aktivasi garansi milik user),
/// lalu poll reading terbaru tiap AppConfig.livePollSeconds detik.
class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  final _data = DataService();

  List<Map<String, dynamic>> _devices = [];
  int? _activationId;
  Map<String, dynamic>? _reading;
  Timer? _timer;
  bool _loadingDevices = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    final list = await _data.myWarranties();
    if (!mounted) return;
    setState(() {
      _devices = list;
      _loadingDevices = false;
      if (list.isNotEmpty) {
        _activationId = list.first['id'] as int;
      }
    });
    if (_activationId != null) _startPolling();
  }

  void _startPolling() {
    _timer?.cancel();
    _poll();
    _timer = Timer.periodic(
      const Duration(seconds: AppConfig.livePollSeconds),
      (_) => _poll(),
    );
  }

  Future<void> _poll() async {
    if (_activationId == null) return;
    final r = await _data.latestEnergy(_activationId!);
    if (!mounted) return;
    setState(() => _reading = r);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingDevices) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_devices.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Belum ada perangkat teraktivasi. Aktivasi garansi dulu untuk monitoring.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final r = _reading;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<int>(
            initialValue: _activationId,
            decoration: const InputDecoration(
                labelText: 'Perangkat', border: OutlineInputBorder()),
            items: _devices.map((d) {
              final product = d['product'] as Map<String, dynamic>?;
              return DropdownMenuItem<int>(
                value: d['id'] as int,
                child: Text('${product?['product_name'] ?? 'Unit'} · ${d['serial_number']}'),
              );
            }).toList(),
            onChanged: (v) {
              setState(() {
                _activationId = v;
                _reading = null;
              });
              _startPolling();
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.circle, size: 10, color: Colors.green),
              const SizedBox(width: 6),
              Text('Live · refresh ${AppConfig.livePollSeconds}s',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 16),
          if (r == null)
            const Expanded(
              child: Center(child: Text('Menunggu data telemetri...')),
            )
          else
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  _metric('Produksi', '${r['kwh_produced']} kWh', Icons.solar_power),
                  _metric('Baterai (SOC)', '${r['battery_soc'] ?? '-'} %', Icons.battery_charging_full),
                  _metric('Daya', '${r['power_watt'] ?? '-'} W', Icons.flash_on),
                  _metric('Beban', '${r['load_watt'] ?? '-'} W', Icons.power),
                  _metric('Inverter', '${r['inverter_status'] ?? '-'}', Icons.settings_input_component),
                  _metric('Grid', '${r['grid_status'] ?? '-'}', Icons.electrical_services),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF0F766E)),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
