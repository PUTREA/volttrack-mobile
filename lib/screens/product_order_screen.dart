import 'package:flutter/material.dart';

import '../services/data_service.dart';

/// Layar buat order dari sebuah produk marketplace.
class ProductOrderScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductOrderScreen({super.key, required this.product});

  @override
  State<ProductOrderScreen> createState() => _ProductOrderScreenState();
}

class _ProductOrderScreenState extends State<ProductOrderScreen> {
  final _data = DataService();
  final _qty = TextEditingController(text: '1');
  final _address = TextEditingController();

  bool _busy = false;
  String? _message;
  bool _success = false;

  Future<void> _submit() async {
    final qty = int.tryParse(_qty.text) ?? 0;
    if (qty <= 0) {
      setState(() => _message = 'Jumlah harus lebih dari 0.');
      return;
    }
    if (_address.text.trim().isEmpty) {
      setState(() => _message = 'Alamat instalasi wajib diisi.');
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    final err = await _data.createOrder(
      widget.product['id'] as int,
      qty,
      _address.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      _success = err == null;
      _message = err ?? 'Order berhasil dibuat. Lanjut ke tab Order untuk bayar.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final price = (p['price'] ?? 0).toString();

    return Scaffold(
      appBar: AppBar(title: Text('${p['product_name']}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${p['product_name']}',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('${p['model'] ?? '-'}',
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text('Harga: Rp$price',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('Stok tersedia: ${p['stock_qty']}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _qty,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Jumlah', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'Alamat Instalasi', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_message!,
                  style: TextStyle(
                      color: _success ? Colors.green : Colors.red)),
            ),
          FilledButton(
            onPressed: (_busy || _success) ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Pesan Sekarang'),
          ),
          if (_success)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kembali'),
              ),
            ),
        ],
      ),
    );
  }
}
