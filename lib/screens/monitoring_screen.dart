import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../services/data_service.dart';

/// Live monitoring energi dengan grafik. Pilih perangkat, lalu poll tiap
/// AppConfig.livePollSeconds detik: kartu metrik (latest) + chart (series).
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
  List<Map<String, dynamic>> _series = [];
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
      if (list.isNotEmpty) _activationId = list.first['id'] as int;
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
    final reading = await _data.latestEnergy(_activationId!);
    final series = await _data.energySeries(_activationId!, limit: 20);
    if (!mounted) return;
    setState(() {
      _reading = reading;
      _series = series;
    });
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<int>(
          initialValue: _activationId,
          decoration: const InputDecoration(
            labelText: 'Perangkat',
            border: OutlineInputBorder(),
          ),
          items: _devices.map((d) {
            final product = d['product'] as Map<String, dynamic>?;
            return DropdownMenuItem<int>(
              value: d['id'] as int,
              child: Text(
                '${product?['product_name'] ?? 'Unit'} · ${d['serial_number']}',
              ),
            );
          }).toList(),
          onChanged: (v) {
            setState(() {
              _activationId = v;
              _reading = null;
              _series = [];
            });
            _startPolling();
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.circle, size: 10, color: Colors.green),
            const SizedBox(width: 6),
            Text(
              'Live · refresh ${AppConfig.livePollSeconds}s',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Kartu metrik ringkas (nilai terkini).
        if (r == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('Menunggu data telemetri...')),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: _metric(
                  'Daya',
                  '${r['power_watt'] ?? '-'} W',
                  Icons.flash_on,
                  const Color(0xFF0F766E),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metric(
                  'Baterai',
                  '${r['battery_soc'] ?? '-'} %',
                  Icons.battery_charging_full,
                  const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _metric(
                  'Beban',
                  '${r['load_watt'] ?? '-'} W',
                  Icons.power,
                  const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metric(
                  'Inverter',
                  '${r['inverter_status'] ?? '-'}',
                  Icons.settings_input_component,
                  const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Grafik daya (W) — line chart.
          _chartCard(
            'Daya (W) — 20 titik terakhir',
            _lineChart(_series, 'power_watt', const Color(0xFF0F766E)),
          ),
          const SizedBox(height: 16),

          // Grafik baterai SOC (%) — line chart.
          _chartCard(
            'Baterai SOC (%)',
            _lineChart(
              _series,
              'battery_soc',
              const Color(0xFFF59E0B),
              maxY: 100,
            ),
          ),
        ],
      ],
    );
  }

  Widget _chartCard(String title, Widget chart) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(height: 180, child: chart),
          ],
        ),
      ),
    );
  }

  Widget _lineChart(
    List<Map<String, dynamic>> series,
    String field,
    Color color, {
    double? maxY,
  }) {
    if (series.isEmpty) {
      return const Center(child: Text('Belum ada data'));
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < series.length; i++) {
      final v = series[i][field];
      if (v != null) {
        spots.add(FlSpot(i.toDouble(), (v as num).toDouble()));
      }
    }
    if (spots.isEmpty) {
      return const Center(child: Text('Belum ada data'));
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
