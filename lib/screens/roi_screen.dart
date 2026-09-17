import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/data_service.dart';

class RoiScreen extends StatefulWidget {
  const RoiScreen({super.key});

  @override
  State<RoiScreen> createState() => _RoiScreenState();
}

class _RoiScreenState extends State<RoiScreen> {
  final _data = DataService();
  final _tariff = TextEditingController(text: '1444.70');
  final _unitPrice = TextEditingController(text: '15000000');

  List<Map<String, dynamic>> _devices = [];
  int? _activationId;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _forecast = [];
  bool _loading = true;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final list = await _data.myWarranties();
    if (!mounted) return;
    setState(() {
      _devices = list;
      _loading = false;
      if (list.isNotEmpty) _activationId = list.first['id'] as int;
    });
  }

  Future<void> _calculate() async {
    if (_activationId == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final r = await _data.roiCalculate(
      _activationId!,
      double.tryParse(_tariff.text) ?? 1444.70,
      double.tryParse(_unitPrice.text) ?? 0,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r == null) {
        _message = 'Gagal menghitung ROI.';
        _summary = null;
        _forecast = [];
      } else {
        _summary = r['summary'] as Map<String, dynamic>;
        _forecast = (r['forecast'] as List).cast<Map<String, dynamic>>();
      }
    });
  }

  Future<void> _saveSnapshot() async {
    if (_activationId == null) return;
    final err = await _data.roiSnapshot(
      _activationId!,
      double.tryParse(_tariff.text) ?? 1444.70,
      double.tryParse(_unitPrice.text) ?? 0,
    );
    if (!mounted) return;
    setState(() => _message = err ?? 'Snapshot ROI tersimpan.');
  }

  double _num(dynamic v) => v == null ? 0 : (v as num).toDouble();

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_devices.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aktivasi perangkat dulu untuk menghitung ROI.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final s = _summary;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('ROI Calculator', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
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
          onChanged: (v) => setState(() => _activationId = v),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _tariff,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Tarif listrik (Rp/kWh)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _unitPrice,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Harga perangkat (Rp)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : _calculate,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Hitung ROI'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _summary == null ? null : _saveSnapshot,
                child: const Text('Simpan Snapshot'),
              ),
            ),
          ],
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _message!,
              style: TextStyle(
                color: _message!.contains('tersimpan')
                    ? Colors.green
                    : Colors.red,
              ),
            ),
          ),
        const SizedBox(height: 16),

        if (s != null) ...[
          // Metrik input vs output daya.
          Row(
            children: [
              Expanded(
                child: _metric(
                  'Produksi (output)',
                  '${s['total_kwh']} kWh',
                  const Color(0xFF0F766E),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metric(
                  'Beban (input)',
                  '${s['load_kwh']} kWh',
                  const Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _metric(
                  'Self-consumption',
                  '${((_num(s['self_consumption_ratio'])) * 100).toStringAsFixed(0)}%',
                  const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metric(
                  'Payback',
                  '${s['payback_months'] ?? '-'} bln',
                  const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Chart 1: Daya rata-rata vs puncak (produksi & beban).
          _chartCard('Daya Produksi vs Beban (W)', _powerBarChart(s)),
          const SizedBox(height: 16),

          // Chart 2: Forecast kumulatif penghematan vs investasi.
          _chartCard(
            'Proyeksi Penghematan Kumulatif vs Investasi',
            _forecastChart(),
          ),
          const SizedBox(height: 16),

          // Rincian angka.
          _row('Energi ter-offset', '${s['offset_kwh']} kWh'),
          _row('Net energi (surplus)', '${s['net_kwh']} kWh'),
          _row('Estimasi hemat', 'Rp${s['estimated_saving']}'),
          _row('Proyeksi hemat/bulan', 'Rp${s['monthly_saving_projection']}'),
          _row('Kualitas data', '${s['data_quality']}'),
        ],
      ],
    );
  }

  // ---- Chart: bar daya produksi vs beban (avg & max) ----
  Widget _powerBarChart(Map<String, dynamic> s) {
    final avgProd = _num(s['avg_production_watt']);
    final maxProd = _num(s['max_production_watt']);
    final avgLoad = _num(s['avg_load_watt']);
    final maxLoad = _num(s['max_load_watt']);
    final maxY =
        [avgProd, maxProd, avgLoad, maxLoad].reduce((a, b) => a > b ? a : b) *
        1.2;

    const teal = Color(0xFF0F766E);
    const blue = Color(0xFF3B82F6);

    BarChartGroupData group(int x, double v1, double v2) => BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: v1,
          color: teal,
          width: 14,
          borderRadius: BorderRadius.circular(3),
        ),
        BarChartRodData(
          toY: v2,
          color: blue,
          width: 14,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: maxY <= 0 ? 100 : maxY,
              gridData: FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    getTitlesWidget: (v, m) => Text(
                      v.toInt().toString(),
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, m) {
                      const labels = ['Rata-rata', 'Puncak'];
                      final i = v.toInt();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          i < labels.length ? labels[i] : '',
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                group(0, avgProd, avgLoad),
                group(1, maxProd, maxLoad),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            _Legend(color: teal, label: 'Produksi'),
            SizedBox(width: 16),
            _Legend(color: blue, label: 'Beban'),
          ],
        ),
      ],
    );
  }

  // ---- Chart: forecast kumulatif saving (line) vs investasi (garis datar) ----
  Widget _forecastChart() {
    if (_forecast.isEmpty) return const Center(child: Text('Belum ada data'));

    final savingSpots = <FlSpot>[];
    double investment = 0;
    for (var i = 0; i < _forecast.length; i++) {
      final f = _forecast[i];
      savingSpots.add(FlSpot(i.toDouble(), _num(f['cumulative_saving'])));
      investment = _num(f['investment']);
    }
    final maxSaving = savingSpots
        .map((e) => e.y)
        .reduce((a, b) => a > b ? a : b);
    final maxY = [maxSaving, investment].reduce((a, b) => a > b ? a : b) * 1.15;

    final investLine = <FlSpot>[
      FlSpot(0, investment),
      FlSpot((_forecast.length - 1).toDouble(), investment),
    ];

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY <= 0 ? 100 : maxY,
              gridData: FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 2,
                    getTitlesWidget: (v, m) => Text(
                      'Th${v.toInt()}',
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              lineBarsData: [
                // Penghematan kumulatif
                LineChartBarData(
                  spots: savingSpots,
                  isCurved: true,
                  color: const Color(0xFF0F766E),
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF0F766E).withValues(alpha: 0.15),
                  ),
                ),
                // Investasi (garis merah datar = target break-even)
                LineChartBarData(
                  spots: investLine,
                  isCurved: false,
                  color: Colors.redAccent,
                  barWidth: 2,
                  dashArray: [6, 4],
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            _Legend(color: Color(0xFF0F766E), label: 'Hemat kumulatif'),
            SizedBox(width: 16),
            _Legend(color: Colors.redAccent, label: 'Investasi'),
          ],
        ),
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
            const SizedBox(height: 12),
            chart,
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
