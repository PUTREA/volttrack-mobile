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
  final _unitPrice = TextEditingController(text: '3500000');

  List<Map<String, dynamic>> _devices = [];
  int? _activationId;
  Map<String, dynamic>? _result;
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
      _result = r;
      if (r == null) _message = 'Gagal menghitung ROI.';
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_devices.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Aktivasi perangkat dulu untuk menghitung ROI.',
              textAlign: TextAlign.center),
        ),
      );
    }

    final r = _result;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('ROI Calculator', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
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
          onChanged: (v) => setState(() => _activationId = v),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _tariff,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Tarif listrik (Rp/kWh)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _unitPrice,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Harga perangkat (Rp)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : _calculate,
                child: const Text('Hitung ROI'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _result == null ? null : _saveSnapshot,
                child: const Text('Simpan Snapshot'),
              ),
            ),
          ],
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(_message!,
                style: TextStyle(
                    color: _message!.contains('tersimpan')
                        ? Colors.green
                        : Colors.red)),
          ),
        const SizedBox(height: 16),
        if (r != null) ...[
          _row('Total produksi', '${r['total_kwh']} kWh'),
          _row('Energi ter-offset', '${r['offset_kwh']} kWh'),
          _row('Estimasi hemat', 'Rp${r['estimated_saving']}'),
          _row('Proyeksi hemat/bulan', 'Rp${r['monthly_saving_projection']}'),
          _row('Payback', '${r['payback_months'] ?? '-'} bulan'),
          _row('Kualitas data', '${r['data_quality']}'),
        ],
      ],
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
