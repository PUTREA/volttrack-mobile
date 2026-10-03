import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../config.dart';
import '../services/data_service.dart';
import '../theme/theme_controller.dart';

// Dynamic design tokens reacting to Dark & Light modes
VoltTrackPalette get _palette => ThemeController.instance.palette;
Color get _kCardBg => _palette.cardBg;
Color get _kCardBgElevated => _palette.cardElevated;
Color get _kBorderColor => _palette.borderColor;
Color get _kNeonTeal => _palette.neonTeal;
Color get _kSolarAmber => _palette.solarAmber;
Color get _kTextPrimary => _palette.textPrimary;
Color get _kTextSecondary => _palette.textSecondary;
Color get _kTextMuted => _palette.textMuted;

/// Detail Order & Pelacak Logistik 5-Tahap (Executive Edition)
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
  String? _uploadedPath;
  Timer? _syncTimer;
  late Map<String, dynamic> _currentOrder;

  @override
  void initState() {
    super.initState();
    ThemeController.instance.addListener(_onThemeChanged);
    _currentOrder = Map<String, dynamic>.from(widget.order);
    _uploadedPath = _currentOrder['payment_proof']?.toString();
    _startAutoSyncIfPending();
  }

  void _startAutoSyncIfPending() {
    if (_currentOrder['payment_status'] != 'paid') {
      _syncTimer?.cancel();
      _syncTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
        final orderId = int.tryParse(_currentOrder['id']?.toString() ?? '');
        if (orderId == null) return;
        final updated = await _data.fetchOrder(orderId);
        if (updated != null && mounted) {
          final wasPending = _currentOrder['payment_status'] != 'paid';
          final isNowPaid = updated['payment_status'] == 'paid';

          setState(() {
            _currentOrder = updated;
            if (updated['payment_proof'] != null) {
              _uploadedPath = updated['payment_proof'].toString();
            }
          });

          if (wasPending && isNowPaid) {
            timer.cancel();
            HapticFeedback.heavyImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF0F766E),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
                content: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: Color(0xFF34D399), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '🎉 Pembayaran Terverifikasi! Unit masuk ke Lab Perakitan & QC.',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    ThemeController.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _upload(ImageSource source) async {
    HapticFeedback.lightImpact();
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      _busy = true;
      _message = null;
    });
    final err = await _data.uploadPaymentProof(
      int.tryParse(_currentOrder['id']?.toString() ?? '') ?? 0,
      picked.path,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (err == null) {
        _uploadedPath = picked.path;
        _currentOrder['payment_proof'] = picked.path;
        _message = 'Bukti pembayaran berhasil diunggah! Finance sedang memverifikasi.';
        _startAutoSyncIfPending();
      } else {
        _message = err;
      }
    });
    if (err == null) {
      HapticFeedback.heavyImpact();
    }
  }

  void _openReceiptZoom(String path) {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kNeonTeal.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: _kNeonTeal.withValues(alpha: 0.2),
                      blurRadius: 24,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: path.startsWith('http')
                    ? Image.network(path, fit: BoxFit.contain)
                    : (File(path).existsSync()
                        ? Image.file(File(path), fit: BoxFit.contain)
                        : Container(
                            height: 250,
                            color: _kCardBg,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.receipt_long_rounded, size: 48, color: _kNeonTeal),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Bukti Transfer Terlampir',
                                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    path,
                                    style: GoogleFonts.inter(color: _kTextMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          )),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Tutup'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kCardBgElevated,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F766E),
        content: Text('$label berhasil disalin ke clipboard!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    Color bg;
    Color text;
    Color border;
    String label;

    if (status == 'paid') {
      bg = const Color(0xFF10B981).withValues(alpha: 0.14);
      text = const Color(0xFF34D399);
      border = const Color(0xFF10B981).withValues(alpha: 0.4);
      label = 'Lunas / Terverifikasi';
    } else if (status == 'failed') {
      bg = const Color(0xFFEF4444).withValues(alpha: 0.14);
      text = const Color(0xFFF87171);
      border = const Color(0xFFEF4444).withValues(alpha: 0.4);
      label = 'Gagal';
    } else {
      bg = _kSolarAmber.withValues(alpha: 0.14);
      text = _kSolarAmber;
      border = _kSolarAmber.withValues(alpha: 0.4);
      label = 'Menunggu Pembayaran';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = _currentOrder;
    final product = o['product'] as Map<String, dynamic>?;
    final isPending = o['payment_status'] == 'pending';
    final isGlass = ThemeController.instance.isGlass;

    return Scaffold(
      backgroundColor: _palette.bg,
      appBar: AppBar(
        backgroundColor: _palette.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).maybePop();
          },
          tooltip: 'Kembali',
        ),
        title: Text(
          'Detail Pesanan #${o['id']}',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 16.5,
            color: _kTextPrimary,
          ),
        ),
        iconTheme: IconThemeData(color: _kTextPrimary),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // ==========================================
          // 📦 CARD RINGKASAN PESANAN
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Faktur Pesanan #${o['id']}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: _kTextPrimary,
                      ),
                    ),
                    _buildStatusChip(o['payment_status']?.toString()),
                  ],
                ),
                Divider(height: 24, color: _kBorderColor.withValues(alpha: 0.6)),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _kNeonTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.solar_power_rounded, color: _kNeonTeal, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${product?['product_name'] ?? 'Unit Produk Solar'}',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _kTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Jumlah Pesanan: ${o['quantity']} Unit',
                            style: GoogleFonts.inter(color: _kTextMuted, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kCardBgElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kBorderColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Pembayaran',
                        style: GoogleFonts.inter(fontSize: 13, color: _kTextSecondary, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        AppConfig.formatRupiah(o['total_price']),
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: _kNeonTeal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: _kTextMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${o['shipping_address'] ?? 'Alamat instalasi belum ditentukan'}',
                        style: GoogleFonts.inter(fontSize: 12, color: _kTextSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ==========================================
          // 🚚 5-STAGE LOGISTICS & FULFILLMENT STEPPER
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _kNeonTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.local_shipping_outlined, color: _kNeonTeal, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pelacak Logistik & Instalasi',
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: _kTextPrimary,
                          ),
                        ),
                        Text(
                          'Tahapan pesanan s.d unit terpasang & aktif',
                          style: GoogleFonts.inter(fontSize: 11, color: _kTextMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                _stepperItem(
                  stage: 1,
                  title: 'Pesanan Diterima',
                  subtitle: 'Faktur pesanan terdaftar di sistem VoltTrack',
                  isCompleted: true,
                  isActive: false,
                ),
                _stepperItem(
                  stage: 2,
                  title: 'Verifikasi Pembayaran',
                  subtitle: isPending
                      ? (_uploadedPath != null ? 'Bukti bayar sedang diverifikasi finance' : 'Menunggu upload bukti transfer')
                      : 'Pembayaran telah lunas & tervalidasi bank',
                  isCompleted: !isPending,
                  isActive: isPending,
                ),
                _stepperItem(
                  stage: 3,
                  title: 'Alokasi Unit Inverter & QC Lab',
                  subtitle: isPending
                      ? 'Menunggu pelunasan pembayaran'
                      : 'Unit disiapkan di warehouse & nomor seri dialokasikan',
                  isCompleted: !isPending,
                  isActive: false,
                ),
                _stepperItem(
                  stage: 4,
                  title: 'Pengiriman Ekspedisi Khusus Solar',
                  subtitle: 'Pengiriman aman dengan packaging anti-getaran',
                  isCompleted: false,
                  isActive: !isPending,
                ),
                _stepperItem(
                  stage: 5,
                  title: 'Instalasi & Commissioning Teknisi',
                  subtitle: 'Teknisi memasang inverter & mengaktifkan E-Garansi',
                  isCompleted: false,
                  isActive: false,
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ==========================================
          // 💳 REKENING RESMI & BUKTI BAYAR
          // ==========================================
          if (isPending) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_rounded, color: Color(0xFF60A5FA), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Rekening Resmi Transfer Bank',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF93C5FD),
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Silakan transfer sesuai nominal total tagihan ke rekening perusahaan:',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFBFDBFE)),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _kCardBgElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bank BCA · 8820-9988-12',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: _kTextPrimary,
                              ),
                            ),
                            Text('a.n. PT VoltTrack Energi Indonesia', style: GoogleFonts.inter(color: _kTextMuted, fontSize: 11)),
                          ],
                        ),
                        IconButton(
                          onPressed: () => _copyToClipboard('8820998812', 'Nomor Rekening BCA'),
                          icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF60A5FA)),
                          tooltip: 'Salin Rekening',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card Upload Bukti Bayar
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
                    'Unggah Bukti Pembayaran',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pilih foto struk transfer dari galeri atau ambil foto langsung.',
                    style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted),
                  ),
                  const SizedBox(height: 16),

                  // Interactive Preview Card if available
                  if (_uploadedPath != null) ...[
                    GestureDetector(
                      onTap: () => _openReceiptZoom(_uploadedPath!),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.image_search_rounded, color: Color(0xFF34D399)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bukti Bayar Terlampir',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      color: const Color(0xFF34D399),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    'Klik untuk melihat bukti foto layar penuh',
                                    style: GoogleFonts.inter(fontSize: 11, color: _kTextMuted),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFF34D399)),
                          ],
                        ),
                      ),
                    ),
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _upload(ImageSource.gallery),
                          icon: Icon(Icons.photo_library_outlined, size: 18, color: _kNeonTeal),
                          label: Text(
                            'Pilih Galeri',
                            style: GoogleFonts.inter(
                              color: _kTextPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _kBorderColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _upload(ImageSource.camera),
                          icon: Icon(Icons.camera_alt_outlined, size: 18, color: _kNeonTeal),
                          label: Text(
                            'Ambil Foto',
                            style: GoogleFonts.inter(
                              color: _kTextPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _kBorderColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFF34D399), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pembayaran Terverifikasi',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: const Color(0xFF34D399),
                          ),
                        ),
                        Text(
                          'Pesanan telah lunas. Tim teknisi kami akan mengontak Anda untuk penjadwalan instalasi.',
                          style: GoogleFonts.inter(fontSize: 12, color: _kTextSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            ),

          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _message!.contains('berhasil')
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _message!.contains('berhasil')
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : const Color(0xFFEF4444).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _message!,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: _message!.contains('berhasil')
                        ? const Color(0xFF34D399)
                        : const Color(0xFFF87171),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          Builder(
            builder: (ctx) {
              final bottom = MediaQuery.paddingOf(ctx).bottom;
              return SizedBox(height: bottom > 0 ? bottom + 24 : 36);
            },
          ),
        ],
      ),
    );
  }

  Widget _stepperItem({
    required int stage,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isActive,
    bool isLast = false,
  }) {
    Color circleColor;
    Color iconColor;
    IconData icon;

    if (isCompleted) {
      circleColor = const Color(0xFF10B981);
      iconColor = Colors.white;
      icon = Icons.check_rounded;
    } else if (isActive) {
      circleColor = _kSolarAmber;
      iconColor = Colors.black;
      icon = Icons.hourglass_top_rounded;
    } else {
      circleColor = _kCardBgElevated;
      iconColor = _kTextMuted;
      icon = Icons.circle_outlined;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? _kSolarAmber : (isCompleted ? const Color(0xFF10B981) : _kBorderColor),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(icon, size: 14, color: iconColor),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: isCompleted ? const Color(0xFF10B981) : _kBorderColor.withValues(alpha: 0.5),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isCompleted || isActive ? FontWeight.w800 : FontWeight.w500,
                    color: isCompleted || isActive ? _kTextPrimary : _kTextMuted,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _kTextMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
