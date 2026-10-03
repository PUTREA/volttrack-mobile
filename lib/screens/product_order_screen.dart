import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config.dart';
import '../services/data_service.dart';
import '../theme/theme_controller.dart';
import '../widgets/motion_helpers.dart';

// Dynamic design tokens reacting to Dark & Light modes
VoltTrackPalette get _palette => ThemeController.instance.palette;
Color get _kCardBg => _palette.cardBg;
Color get _kCardBgElevated => _palette.cardElevated;
Color get _kBorderColor => _palette.borderColor;
Color get _kPrimaryTeal => _palette.primaryTeal;
Color get _kNeonTeal => _palette.neonTeal;
Color get _kTextPrimary => _palette.textPrimary;
Color get _kTextSecondary => _palette.textSecondary;
Color get _kTextMuted => _palette.textMuted;

/// Layar Buat Pesanan Produk Marketplace (Executive Dark Luxury Edition)
class ProductOrderScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductOrderScreen({super.key, required this.product});

  @override
  State<ProductOrderScreen> createState() => _ProductOrderScreenState();
}

class _ProductOrderScreenState extends State<ProductOrderScreen> {
  final _data = DataService();
  final _address = TextEditingController();

  bool _busy = false;
  String? _message;
  bool _success = false;
  int _currentQty = 1;
  int _selectedPaymentMethod = 0; // 0: BCA, 1: Mandiri VA, 2: QRIS

  final List<Map<String, dynamic>> _paymentMethods = const [
    {'title': 'Bank BCA Transfer', 'sub': 'Konfirmasi bukti transfer', 'icon': Icons.account_balance_rounded},
    {'title': 'Mandiri Virtual Account', 'sub': 'Verifikasi otomatis 24 jam', 'icon': Icons.credit_card_rounded},
    {'title': 'QRIS Nasional Instant', 'sub': 'Scan GoPay, OVO, BCA, Livin', 'icon': Icons.qr_code_rounded},
  ];

  @override
  void initState() {
    super.initState();
    ThemeController.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onThemeChanged);
    _address.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _useDemoAddress() {
    HapticFeedback.selectionClick();
    setState(() {
      _address.text = 'Jl. Jenderal Sudirman No. 45, Kompleks Solar Executive Park, Jakarta Pusat';
    });
  }

  Future<void> _submit() async {
    if (_currentQty <= 0) {
      setState(() => _message = 'Jumlah pesanan minimal 1 unit.');
      return;
    }
    if (_address.text.trim().isEmpty) {
      setState(() => _message = 'Alamat pengiriman & instalasi wajib diisi.');
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    final err = await _data.createOrder(
      int.tryParse(widget.product['id']?.toString() ?? '') ?? 0,
      _currentQty,
      _address.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      _success = err == null;
      _message = err ?? 'Pesanan berhasil dibuat! Silakan lakukan transfer & unggah bukti pembayaran di tab Order.';
    });

    if (err == null) {
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final unitPrice = double.tryParse(p['price']?.toString() ?? '') ?? 0.0;
    final totalPrice = unitPrice * _currentQty;
    final isGlass = ThemeController.instance.isGlass;

    return Scaffold(
      backgroundColor: _palette.bg,
      appBar: AppBar(
        backgroundColor: _palette.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Konfirmasi Pemesanan',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 16.5,
            color: _kTextPrimary,
          ),
        ),
        iconTheme: IconThemeData(color: _kTextPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // ==========================================
          // 📦 CARD INFO PRODUK
          // ==========================================
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isGlass ? const Color(0xFF1E293B).withValues(alpha: 0.4) : _kCardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isGlass ? Colors.white.withValues(alpha: 0.2) : _kBorderColor,
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: ThemeController.instance.isDark ? 0.25 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _kNeonTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.solar_power_rounded, color: _kNeonTeal, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p['product_name']}',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: _kTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Model: ${p['model'] ?? 'VoltTrack Hybrid'} · Stok Siap: ${p['stock_qty'] ?? 10} Unit',
                            style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Divider(height: 24, color: _kBorderColor.withValues(alpha: 0.6)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Harga Satuan Unit', style: GoogleFonts.inter(color: _kTextSecondary, fontSize: 13)),
                    Text(
                      AppConfig.formatRupiah(unitPrice),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: _kNeonTeal),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ==========================================
          // ⚙️ DETAIL JUMLAH & ALAMAT
          // ==========================================
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isGlass ? const Color(0xFF1E293B).withValues(alpha: 0.4) : _kCardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isGlass ? Colors.white.withValues(alpha: 0.2) : _kBorderColor,
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kuantitas & Pengiriman',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: _kTextPrimary,
                  ),
                ),
                const SizedBox(height: 14),

                // Stepper Jumlah Unit
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Jumlah Perangkat',
                      style: GoogleFonts.inter(fontSize: 13, color: _kTextSecondary, fontWeight: FontWeight.w600),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _currentQty > 1
                              ? () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _currentQty--);
                                }
                              : null,
                          icon: Icon(Icons.remove_circle_outline_rounded,
                              color: _currentQty > 1 ? _kNeonTeal : _kTextMuted),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _kCardBgElevated,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _kBorderColor),
                          ),
                          child: Text(
                            '$_currentQty Unit',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: _kTextPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setState(() => _currentQty++);
                          },
                          icon: Icon(Icons.add_circle_outline_rounded, color: _kNeonTeal),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Alamat Instalasi & Pengiriman',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextSecondary),
                    ),
                    GestureDetector(
                      onTap: _useDemoAddress,
                      child: Text(
                        'Isi Alamat Demo',
                        style: GoogleFonts.inter(fontSize: 11.5, color: _kNeonTeal, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _address,
                  maxLines: 2,
                  style: GoogleFonts.inter(color: _kTextPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Masukkan nama jalan, perumahan/gedung, kota...',
                    hintStyle: GoogleFonts.inter(color: _kTextMuted.withValues(alpha: 0.5), fontSize: 12),
                    filled: true,
                    fillColor: _kCardBgElevated,
                    contentPadding: const EdgeInsets.all(12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _kBorderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _kNeonTeal, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ==========================================
          // 💳 PILIHAN METODE PEMBAYARAN
          // ==========================================
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isGlass ? const Color(0xFF1E293B).withValues(alpha: 0.4) : _kCardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isGlass ? Colors.white.withValues(alpha: 0.2) : _kBorderColor,
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Metode Pembayaran',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: _kTextPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ..._paymentMethods.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final isSelected = _selectedPaymentMethod == idx;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ScaleOnPress(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedPaymentMethod = idx);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _kNeonTeal.withValues(alpha: 0.12)
                              : _kCardBgElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? _kNeonTeal : _kBorderColor,
                            width: isSelected ? 1.5 : 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item['icon'] as IconData,
                              size: 22,
                              color: isSelected ? _kNeonTeal : _kTextMuted,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'] as String,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: _kTextPrimary,
                                    ),
                                  ),
                                  Text(
                                    item['sub'] as String,
                                    style: GoogleFonts.inter(fontSize: 11, color: _kTextMuted),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                              size: 20,
                              color: isSelected ? _kNeonTeal : _kTextMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ==========================================
          // 💰 RINGKASAN BIAYA & SUBMIT
          // ==========================================
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isGlass ? const Color(0xFF1E293B).withValues(alpha: 0.4) : _kCardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isGlass ? Colors.white.withValues(alpha: 0.2) : _kBorderColor,
                width: 0.8,
              ),
            ),
            child: Column(
              children: [
                _summaryRow('Subtotal ($_currentQty Unit)', AppConfig.formatRupiah(totalPrice)),
                const SizedBox(height: 8),
                _summaryRow('Biaya Instalasi Teknisi', 'GRATIS (Promo Eksekutif)', isPromo: true),
                const SizedBox(height: 8),
                _summaryRow('Sertifikasi E-Garansi 25 Thn', 'Termasuk', isPromo: true),
                Divider(height: 24, color: _kBorderColor.withValues(alpha: 0.6)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Pembayaran',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _kTextPrimary),
                    ),
                    Text(
                      AppConfig.formatRupiah(totalPrice),
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _kNeonTeal),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          if (_message != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: _success
                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                    : const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _success
                      ? const Color(0xFF10B981).withValues(alpha: 0.3)
                      : const Color(0xFFEF4444).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _message!,
                style: GoogleFonts.inter(
                  color: _success ? const Color(0xFF34D399) : const Color(0xFFF87171),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          ScaleOnPress(
            onTap: _busy ? null : _submit,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kPrimaryTeal, const Color(0xFF0D9488)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _kPrimaryTeal.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Konfirmasi & Buat Pesanan',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isPromo = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: _kTextSecondary)),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isPromo ? const Color(0xFF34D399) : _kTextPrimary,
          ),
        ),
      ],
    );
  }
}
