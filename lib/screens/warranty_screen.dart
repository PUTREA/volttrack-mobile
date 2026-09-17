import 'package:flutter/material.dart';

import '../services/data_service.dart';

class WarrantyScreen extends StatefulWidget {
  const WarrantyScreen({super.key});

  @override
  State<WarrantyScreen> createState() => _WarrantyScreenState();
}

class _WarrantyScreenState extends State<WarrantyScreen> {
  final _data = DataService();
  final _serial = TextEditingController();
  final _location = TextEditingController();
  final _date = TextEditingController();

  List<Map<String, dynamic>> _warranties = [];
  bool _loading = true;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _data.myWarranties();
    if (!mounted) return;
    setState(() {
      _warranties = list;
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) {
      _date.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final err = await _data.activateWarranty(
        _serial.text.trim(), _location.text.trim(), _date.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = err ?? 'Aktivasi garansi berhasil.';
    });
    if (err == null) {
      _serial.clear();
      _location.clear();
      _date.clear();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Aktivasi Garansi',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
          controller: _serial,
          decoration: const InputDecoration(
              labelText: 'Serial Number', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _location,
          decoration: const InputDecoration(
              labelText: 'Lokasi Instalasi', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _date,
          readOnly: true,
          onTap: _pickDate,
          decoration: const InputDecoration(
              labelText: 'Tanggal Instalasi',
              hintText: 'YYYY-MM-DD',
              border: OutlineInputBorder()),
        ),
        const SizedBox(height: 14),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_message!,
                style: TextStyle(
                    color: _message!.contains('berhasil')
                        ? Colors.green
                        : Colors.red)),
          ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Aktivasi'),
        ),
        const Divider(height: 32),
        Text('Perangkat Saya', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_warranties.isEmpty)
          const Text('Belum ada perangkat teraktivasi.')
        else
          ..._warranties.map((w) {
            final product = w['product'] as Map<String, dynamic>?;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.verified, color: Color(0xFF0F766E)),
                title: Text('${product?['product_name'] ?? 'Unit'}'),
                subtitle: Text(
                    'SN: ${w['serial_number']} · ${w['status']}\nGaransi s.d. ${w['warranty_end_date'] ?? '-'}'),
                isThreeLine: true,
              ),
            );
          }),
      ],
    );
  }
}
