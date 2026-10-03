import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/data_service.dart';
import '../theme/theme_controller.dart';
import '../widgets/motion_helpers.dart';

// Dynamic design tokens reacting to Dark, Light, & Glass modes
VoltTrackPalette get _palette => ThemeController.instance.palette;
Color get _kCardBg => _palette.cardBg;
Color get _kCardBgElevated => _palette.cardElevated;
Color get _kBorderColor => _palette.borderColor;
Color get _kPrimaryTeal => _palette.primaryTeal;
Color get _kNeonTeal => _palette.neonTeal;
Color get _kSolarAmber => _palette.solarAmber;
Color get _kTextPrimary => _palette.textPrimary;
Color get _kTextSecondary => _palette.textSecondary;
Color get _kTextMuted => _palette.textMuted;

/// Layar Manajemen E-Garansi Digital 2.0 (Executive Edition)
/// Dilengkapi HUD Barcode Scanner, E-Passport Sertifikat Kriptografi,
/// dan 1-Tap Layanan Teknisi Resmi.
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
    ThemeController.instance.addListener(_onThemeChanged);
    _load();
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onThemeChanged);
    _serial.dispose();
    _location.dispose();
    _date.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: _kNeonTeal,
              onPrimary: Colors.black,
              surface: _kCardBgElevated,
              onSurface: _kTextPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _date.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _submit() async {
    if (_serial.text.trim().isEmpty) {
      setState(() => _message = 'Nomor seri perangkat wajib diisi.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    final err = await _data.activateWarranty(
      _serial.text.trim(),
      _location.text.trim(),
      _date.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = err ?? 'Aktivasi garansi unit berhasil diverifikasi!';
    });
    if (err == null) {
      HapticFeedback.heavyImpact();
      _serial.clear();
      _location.clear();
      _date.clear();
      _load();
    }
  }

  // ==========================================
  // 📷 MODAL HUD PEMINDAI BARCODE / QR SCANNER
  // ==========================================
  void _openBarcodeScannerModal() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BarcodeScannerSheet(
        onScanned: (code) {
          setState(() {
            _serial.text = code;
          });
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF064E3B),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Nomor seri $code berhasil dipindai!',
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // 📜 MODAL E-SERTIFIKAT DIGITAL KRIPTOGRAFI
  // ==========================================
  void _openCertificateModal(Map<String, dynamic> w) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => _DigitalWarrantyCertificateDialog(warranty: w),
    );
  }

  // ==========================================
  // 🛠️ MODAL PANGGIL TEKNISI / KLAIM GARANSI
  // ==========================================
  void _openServiceRequestModal(Map<String, dynamic> w) {
    HapticFeedback.lightImpact();
    final product = w['product'] as Map<String, dynamic>?;
    final model = product?['product_name'] ?? 'Inverter Solar VoltTrack';
    final sn = w['serial_number'] ?? '-';

    showModalBottomSheet(
      context: context,
      backgroundColor: _kCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: _kBorderColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _kNeonTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.support_agent_rounded, color: _kNeonTeal, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Panggilan Teknisi Resmi',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _kTextPrimary,
                          ),
                        ),
                        Text(
                          'Klaim garansi, maintenance preventif, & audit',
                          style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kCardBgElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kBorderColor),
                ),
                child: Column(
                  children: [
                    _specRow('Perangkat', model.toString()),
                    const SizedBox(height: 8),
                    _specRow('Nomor Seri (SN)', sn.toString()),
                    const SizedBox(height: 8),
                    _specRow('Lokasi Terpasang', (w['installation_location'] ?? 'Rumah').toString()),
                    const SizedBox(height: 8),
                    _specRow('SLA Respon', 'Maksimal 1 x 24 Jam Kerja (Prioritas)'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ScaleOnPress(
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF0F766E),
                      content: Text(
                        'Tiket klaim servis unit $sn telah dikirimkan ke Teknisi Area!',
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_kPrimaryTeal, const Color(0xFF0D9488)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _kPrimaryTeal.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Kirim Permintaan Teknisi',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _specRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: _kTextSecondary)),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: _kTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String? status) {
    final isActive = status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF10B981).withValues(alpha: 0.14)
            : const Color(0xFF64748B).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? const Color(0xFF10B981).withValues(alpha: 0.35)
              : const Color(0xFF64748B).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.verified_rounded : Icons.info_outline_rounded,
            size: 11,
            color: isActive ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'Garansi Aktif' : 'Expired',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isActive ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGlass = ThemeController.instance.isGlass;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: RefreshIndicator(
        onRefresh: () async => _load(),
        color: _kNeonTeal,
        backgroundColor: _kCardBg,
        child: ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
          // ==========================================
          // 📝 CARD FORM REGISTRASI GARANSI (2.0)
          // ==========================================
          StaggerItem(
            delay: const Duration(milliseconds: 0),
            child: Container(
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _kNeonTeal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.qr_code_scanner_rounded, color: _kNeonTeal, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Aktivasi E-Garansi Digital',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5,
                                color: _kTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Pindai barcode atau masukkan nomor seri inverter',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: _kTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Input Serial Number + Tombol Scanner Kamera
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _serial,
                          style: GoogleFonts.inter(
                            color: _kTextPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Nomor Seri Produk (SN)',
                            labelStyle: GoogleFonts.inter(color: _kTextMuted, fontSize: 12.5),
                            hintText: 'Contoh: SN-HYB-5KW-2026',
                            hintStyle: GoogleFonts.inter(color: _kTextMuted.withValues(alpha: 0.5), fontSize: 12),
                            prefixIcon: Icon(Icons.confirmation_number_outlined, size: 20, color: _kNeonTeal),
                            filled: true,
                            fillColor: _kCardBgElevated,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      ),
                      const SizedBox(width: 10),
                      ScaleOnPress(
                        onTap: _openBarcodeScannerModal,
                        child: Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: _kNeonTeal.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _kNeonTeal.withValues(alpha: 0.4)),
                          ),
                          child: Icon(Icons.camera_alt_rounded, color: _kNeonTeal, size: 22),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Input Lokasi Instalasi
                  TextField(
                    controller: _location,
                    style: GoogleFonts.inter(
                      color: _kTextPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Lokasi Instalasi',
                      labelStyle: GoogleFonts.inter(color: _kTextMuted, fontSize: 12.5),
                      hintText: 'Misal: Rooftop Hunian Utama / Workshop',
                      hintStyle: GoogleFonts.inter(color: _kTextMuted.withValues(alpha: 0.5), fontSize: 12),
                      prefixIcon: Icon(Icons.place_outlined, size: 20, color: _kNeonTeal),
                      filled: true,
                      fillColor: _kCardBgElevated,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  const SizedBox(height: 12),

                  // Input Tanggal Pemasangan
                  TextField(
                    controller: _date,
                    readOnly: true,
                    onTap: _pickDate,
                    style: GoogleFonts.inter(
                      color: _kTextPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Tanggal Pemasangan / Commissioning',
                      labelStyle: GoogleFonts.inter(color: _kTextMuted, fontSize: 12.5),
                      hintText: 'YYYY-MM-DD',
                      hintStyle: GoogleFonts.inter(color: _kTextMuted.withValues(alpha: 0.5), fontSize: 12),
                      prefixIcon: Icon(Icons.calendar_today_outlined, size: 20, color: _kNeonTeal),
                      suffixIcon: Icon(Icons.keyboard_arrow_down_rounded, color: _kTextMuted),
                      filled: true,
                      fillColor: _kCardBgElevated,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  const SizedBox(height: 16),

                  if (_message != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 14),
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
                      child: Row(
                        children: [
                          Icon(
                            _message!.contains('berhasil')
                                ? Icons.check_circle_rounded
                                : Icons.error_outline_rounded,
                            size: 16,
                            color: _message!.contains('berhasil')
                                ? const Color(0xFF34D399)
                                : const Color(0xFFF87171),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _message!,
                              style: GoogleFonts.inter(
                                color: _message!.contains('berhasil')
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFFF87171),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Tombol Submit Aktivasi
                  ScaleOnPress(
                    onTap: _busy ? null : _submit,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_kPrimaryTeal, const Color(0xFF0D9488)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
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
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.shield_rounded, size: 18, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Aktivasi & Terbitkan Sertifikat',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          // ==========================================
          // 📦 DAFTAR PERANGKAT TERDAFTAR (E-PASSPORT)
          // ==========================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Perangkat Aktif',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: _kTextPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kNeonTeal.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_warranties.length}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _kNeonTeal,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                'Klik kartu untuk lihat E-Sertifikat',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: _kTextMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _kNeonTeal.withValues(alpha: 0.8),
                  ),
                ),
              ),
            )
          else if (_warranties.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kBorderColor),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.shield_outlined, size: 48, color: _kTextMuted.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text(
                      'Belum ada perangkat yang didaftarkan.',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: _kTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gunakan form di atas atau pindai barcode unit untuk memulai.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: _kTextMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._warranties.asMap().entries.map((entry) {
              final idx = entry.key;
              final w = entry.value;
              final product = w['product'] as Map<String, dynamic>?;
              final certCode = w['certificate_code']?.toString();

              return StaggerItem(
                delay: Duration(milliseconds: 60 * idx),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: ScaleOnPress(
                    onTap: () => _openCertificateModal(w),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isGlass ? const Color(0xFF1E293B).withValues(alpha: 0.4) : _kCardBg,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: certCode != null
                              ? _kNeonTeal.withValues(alpha: 0.35)
                              : _kBorderColor,
                          width: certCode != null ? 1.0 : 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: ThemeController.instance.isDark ? 0.22 : 0.04),
                            blurRadius: 14,
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
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _kNeonTeal.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.solar_power_rounded, color: _kNeonTeal, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${product?['product_name'] ?? 'VoltTrack Hybrid Inverter'}',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                    color: _kTextPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStatusChip(w['status']?.toString()),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Nomor Seri SN
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _kCardBgElevated,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _kBorderColor),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'SN: ',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: _kTextMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${w['serial_number']}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color: _kNeonTeal,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Lokasi & Validitas
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.location_on_outlined, size: 14, color: _kTextMuted),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${w['installation_location'] ?? 'Lokasi Terpasang'}',
                                        style: GoogleFonts.inter(fontSize: 12, color: _kTextSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.shield_outlined, size: 13, color: _kSolarAmber),
                                  const SizedBox(width: 4),
                                  Text(
                                    's.d. ${(w['warranty_end_date'] ?? '-').toString().split('T').first}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: _kTextSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Action bar bawah kartu
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Badge Sertifikat Kriptografi
                              if (certCode != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                        const Color(0xFFD97706).withValues(alpha: 0.1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.verified_rounded, size: 13, color: Color(0xFFF59E0B)),
                                      const SizedBox(width: 5),
                                      Text(
                                        certCode,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFF59E0B),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                const SizedBox.shrink(),

                              // Tombol Panggil Teknisi
                              GestureDetector(
                                onTap: () => _openServiceRequestModal(w),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _kNeonTeal.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: _kNeonTeal.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.handyman_outlined, size: 13, color: _kNeonTeal),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Klaim Servis',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: _kNeonTeal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          Builder(
            builder: (ctx) {
              final bottom = MediaQuery.paddingOf(ctx).bottom;
              return SizedBox(height: bottom > 0 ? bottom + 80 : 96);
            },
          ),
        ],
      ),
    ));
  }
}

// ==========================================
// 📷 BOTTOM SHEET PEMINDAI BARCODE / QR CODE
// ==========================================
class _BarcodeScannerSheet extends StatefulWidget {
  final ValueChanged<String> onScanned;
  const _BarcodeScannerSheet({required this.onScanned});

  @override
  State<_BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<_BarcodeScannerSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _laserController;
  bool _torchOn = false;

  final List<String> _demoCodes = const [
    'SN-HYB-5KW-2026',
    'SN-000123-X9',
    'SN-GROWATT-98X',
    'SN-DEMO-550WP',
  ];

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Color(0xFF090A0F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 38,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pindai Stiker Nomor Seri',
                      style: GoogleFonts.inter(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Arahkan kamera ke barcode/QR inverter',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _torchOn = !_torchOn);
                  },
                  icon: Icon(
                    _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    color: _torchOn ? const Color(0xFFF59E0B) : Colors.white70,
                  ),
                  tooltip: 'Flashlight',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Kamera HUD Viewfinder dengan Laser Animasi
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background simulated camera preview gradient
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13151D),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF2DD4BF).withValues(alpha: 0.3),
                    ),
                  ),
                ),

                // Viewfinder frame
                Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF2DD4BF).withValues(alpha: 0.8),
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Sudut bracket viewfinder
                      ...List.generate(4, (i) {
                        final top = i < 2;
                        final left = i % 2 == 0;
                        return Positioned(
                          top: top ? 4 : null,
                          bottom: !top ? 4 : null,
                          left: left ? 4 : null,
                          right: !left ? 4 : null,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              border: Border(
                                top: top
                                    ? const BorderSide(color: Color(0xFF2DD4BF), width: 3.5)
                                    : BorderSide.none,
                                bottom: !top
                                    ? const BorderSide(color: Color(0xFF2DD4BF), width: 3.5)
                                    : BorderSide.none,
                                left: left
                                    ? const BorderSide(color: Color(0xFF2DD4BF), width: 3.5)
                                    : BorderSide.none,
                                right: !left
                                    ? const BorderSide(color: Color(0xFF2DD4BF), width: 3.5)
                                    : BorderSide.none,
                              ),
                            ),
                          ),
                        );
                      }),

                      // Laser scanning beam
                      AnimatedBuilder(
                        animation: _laserController,
                        builder: (context, _) {
                          return Positioned(
                            top: _laserController.value * 200 + 10,
                            left: 10,
                            right: 10,
                            child: Container(
                              height: 2.5,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2DD4BF),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2DD4BF).withValues(alpha: 0.8),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Opsi Pilihan Cepat Nomor Seri Demo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.touch_app_outlined, size: 14, color: Color(0xFF2DD4BF)),
                    const SizedBox(width: 6),
                    Text(
                      'Pilih Cepat Nomor Seri Demo (Simulasi Scan):',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _demoCodes.map((code) {
                    return ScaleOnPress(
                      onTap: () {
                        Navigator.pop(context);
                        widget.onScanned(code);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF2DD4BF).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          code,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF2DD4BF),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

// ==========================================
// 📜 DIALOG DIGITAL WARRANTY CERTIFICATE (APPLE WALLET STYLE)
// ==========================================
class _DigitalWarrantyCertificateDialog extends StatelessWidget {
  final Map<String, dynamic> warranty;
  const _DigitalWarrantyCertificateDialog({required this.warranty});

  @override
  Widget build(BuildContext context) {
    final product = warranty['product'] as Map<String, dynamic>?;
    final model = product?['product_name'] ?? 'VoltTrack Hybrid Inverter';
    final sn = warranty['serial_number'] ?? '-';
    final certCode = warranty['certificate_code'] ?? 'CERT-VOLT-2026-9810';
    final loc = warranty['installation_location'] ?? 'Hunian Tinggal';
    final startDate = (warranty['warranty_start_date'] ?? '2026-01-15').toString().split('T').first;
    final endDate = (warranty['warranty_end_date'] ?? '2051-01-15').toString().split('T').first;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.90,
          margin: const EdgeInsets.symmetric(vertical: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF090D16)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Golden Holographic Seal
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFB45309)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.verified_user_rounded, color: Colors.white, size: 32),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                'SERTIFIKAT E-GARANSI RESMI',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'VoltTrack Clean Energy Ecosystem',
                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 18),

              // Rincian Unit
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    _certRow('Tipe Unit', model.toString()),
                    const Divider(height: 16, color: Colors.white12),
                    _certRow('Nomor Seri (SN)', sn.toString(), isHighlight: true),
                    const Divider(height: 16, color: Colors.white12),
                    _certRow('Kode Sertifikat', certCode.toString(), isGold: true),
                    const Divider(height: 16, color: Colors.white12),
                    _certRow('Lokasi', loc.toString()),
                    const Divider(height: 16, color: Colors.white12),
                    _certRow('Masa Berlaku', '$startDate s.d $endDate'),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Status Verifikasi Publik
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF34D399)),
                    const SizedBox(width: 6),
                    Text(
                      'Tervalidasi Otentik via API Server VoltTrack',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF34D399),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tombol Tutup & Bagikan
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Tutup',
                        style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF0F766E),
                            content: Text(
                              'E-Sertifikat $certCode siap dibagikan!',
                              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.share_rounded, size: 16, color: Colors.black),
                      label: Text(
                        'Bagikan',
                        style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
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
      ),
    );
  }

  Widget _certRow(String label, String value, {bool isHighlight = false, bool isGold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8))),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isGold
                ? const Color(0xFFF59E0B)
                : (isHighlight ? const Color(0xFF2DD4BF) : Colors.white),
            letterSpacing: (isHighlight || isGold) ? 0.4 : 0,
          ),
        ),
      ],
    );
  }
}
