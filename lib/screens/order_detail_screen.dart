import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/data_service.dart';

/// Detail order + upload bukti pembayaran (dari galeri/kamera).
class OrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _data = DataService();
  final _picker = ImagePicker();
  bool _busy = false;
  String? _message;

  Future<void> _upload(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      _busy = true;
      _message = null;
    });
    final err = await _data.uploadPaymentProof(
        widget.order['id'] as int, picked.path);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = err ?? 'Bukti pembayaran terkirim. Menunggu verifikasi admin.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final product = o['product'] as Map<String, dynamic>?;
    final pending = o['payment_status'] == 'pending';

    return Scaffold(
      appBar: AppBar(title: Text('Order #${o['id']}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${product?['product_name'] ?? '-'}',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Jumlah: ${o['quantity']}'),
                  Text('Total: Rp${o['total_price']}'),
                  Text('Alamat: ${o['shipping_address'] ?? '-'}'),
                  Text('Status bayar: ${o['payment_status']}'),
                  Text('Status order: ${o['order_status']}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (pending) ...[
            Text('Unggah Bukti Pembayaran',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _upload(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeri'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _upload(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Kamera'),
                  ),
                ),
              ],
            ),
          ] else
            const Text('Pembayaran sudah diproses.'),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_message!,
                  style: TextStyle(
                      color: _message!.contains('terkirim')
                          ? Colors.green
                          : Colors.red)),
            ),
        ],
      ),
    );
  }
}
