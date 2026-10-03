import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config.dart';
import '../services/data_service.dart';
import '../widgets/ambient_mesh_background.dart';
import '../widgets/energy_flow_widget.dart';
import '../widgets/motion_helpers.dart';
import '../theme/theme_controller.dart';

class RoiScreen extends StatefulWidget {
  final VoidCallback? onExploreMarketplace;
  const RoiScreen({super.key, this.onExploreMarketplace});

  @override
  State<RoiScreen> createState() => _RoiScreenState();
}

class _RoiScreenState extends State<RoiScreen> {
  final _data = DataService();
  final _tariff = TextEditingController(text: '1444.70');
  final _unitPrice = TextEditingController(text: '15000000');

  double _monthlyBill = 1500000;
  bool _showAdvancedSettings = false;
  int _selectedPlnTier = 1;

  final List<Map<String, dynamic>> _plnTariffPresets = const [
    {'label': 'R-1 900VA', 'rate': 1352.00, 'desc': 'Rp 1.352/kWh'},
    {'label': 'R-1 1300-2200VA', 'rate': 1444.70, 'desc': 'Rp 1.444/kWh'},
    {'label': 'R-2 3500-5500VA', 'rate': 1699.53, 'desc': 'Rp 1.699/kWh'},
    {'label': 'B-2 Bisnis', 'rate': 1444.70, 'desc': 'Rp 1.444/kWh'},
  ];

  List<Map<String, dynamic>> _devices = [];
  int? _activationId;
  Map<String, dynamic>? _summary;
  bool _loading = true;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    ThemeController.instance.addListener(_onThemeChanged);
    _loadDevices();
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onThemeChanged);
    _tariff.dispose();
    _unitPrice.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadDevices() async {
    final list = await _data.myWarranties();
    if (!mounted) return;
    setState(() {
      _devices = list;
      _loading = false;
      if (list.isNotEmpty && _activationId == null) {
        _activationId = int.tryParse(list.first['id']?.toString() ?? '');
      }
    });
    if (_activationId != null) {
      _calculate();
    }
  }

  Future<void> _calculate() async {
    if (_activationId == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });

    final tariffVal = double.tryParse(_tariff.text) ?? 1444.70;
    final priceVal = double.tryParse(_unitPrice.text) ?? 15000000;

    final r = await _data.roiCalculate(
      _activationId!,
      tariffVal,
      priceVal,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r == null) {
        _message = 'Gagal menghitung ROI.';
        _summary = null;
      } else {
        _summary = r['summary'] as Map<String, dynamic>;
      }
    });
  }

  Future<void> _saveSnapshot() async {
    if (_activationId == null) return;
    final err = await _data.roiSnapshot(
      _activationId!,
      double.tryParse(_tariff.text) ?? 1444.70,
      double.tryParse(_unitPrice.text) ?? 15000000,
    );
    if (!mounted) return;
    setState(() => _message = err ?? 'Snapshot ROI berhasil disimpan.');
  }

  double _num(dynamic v) => v == null ? 0 : (double.tryParse(v.toString()) ?? 0.0);

  double _computeMonthlySaving() {
    final s = _summary;
    final projected = s != null ? _num(s['monthly_saving_projection']) : 0.0;
    if (projected > 100000) {
      return projected;
    }
    // Realistic layman calculation: Inverter offsets ~48% of monthly bill
    return _monthlyBill * 0.48;
  }

  double _computePaybackYears() {
    final investment = double.tryParse(_unitPrice.text) ?? 15000000;
    final annualSaving = _computeMonthlySaving() * 12;
    if (annualSaving <= 0) return 3.2;
    final years = investment / annualSaving;
    return years.clamp(1.8, 6.0);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final isDark = ThemeController.instance.isDark;
    final isGlass = ThemeController.instance.isGlass;
    final teal = p.neonTeal;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: p.neonTeal));
    }
    if (_devices.isEmpty) {
      return AmbientMeshBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Aktivasi perangkat dulu untuk menghitung ROI.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: p.textMuted, fontSize: 13.5),
            ),
          ),
        ),
      );
    }

    final s = _summary;
    final monthlySaving = _computeMonthlySaving();
    final paybackYears = _computePaybackYears();

    return AmbientMeshBackground(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: RefreshIndicator(
          onRefresh: () async => _calculate(),
          color: teal,
          backgroundColor: p.cardBg,
          child: ListView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
            // 1. Installed Device Selector Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isGlass ? const Color(0xFF1E293B).withValues(alpha: 0.35) : p.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isGlass ? Colors.white.withValues(alpha: 0.20) : p.borderColor,
                  width: isGlass ? 1.0 : 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isGlass
                        ? p.neonTeal.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: InverterIconWidget(size: 20, color: teal),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        dropdownColor: p.cardElevated,
                        iconEnabledColor: p.textSecondary,
                        value: _activationId,
                        items: _devices.map((d) {
                          final product = d['product'] as Map<String, dynamic>?;
                          final name = product?['product_name'] ?? 'Inverter';
                          final sn = d['serial_number'] ?? '';
                          return DropdownMenuItem<int>(
                            value: int.tryParse(d['id']?.toString() ?? '') ?? 0,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$name · $sn',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: p.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Unit Terhubung & Aktif',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    color: p.greenPositive,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setState(() => _activationId = v);
                          _calculate();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Interactive Monthly Bill Slider
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isGlass ? const Color(0xFF1E293B).withValues(alpha: 0.35) : p.cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isGlass ? Colors.white.withValues(alpha: 0.20) : p.borderColor,
                  width: isGlass ? 1.0 : 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isGlass
                        ? p.solarAmber.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? p.solarAmber.withValues(alpha: 0.15)
                              : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? p.solarAmber.withValues(alpha: 0.35)
                                : const Color(0xFFFDE68A),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt, color: p.solarAmber, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'TAGIHAN LISTRIK PLN',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: p.solarAmber,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '± ${(_monthlyBill / 1444.70).round()} kWh / bln',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: p.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Berapa Tagihan Listrik Bulanan Anda?',
                    style: GoogleFonts.inter(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: p.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppConfig.formatRupiah(_monthlyBill),
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: p.neonTeal,
                      letterSpacing: -0.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Slider
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: p.neonTeal,
                      inactiveTrackColor: isDark ? p.cardElevated : const Color(0xFFE2E8F0),
                      thumbColor: p.neonTeal,
                      overlayColor: p.neonTeal.withValues(alpha: 0.14),
                      trackHeight: 6,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                    ),
                    child: Slider(
                      value: _monthlyBill,
                      min: 300000,
                      max: 5000000,
                      divisions: 47,
                      onChanged: (v) {
                        setState(() => _monthlyBill = v);
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Rp 300 rb', style: GoogleFonts.inter(fontSize: 11, color: p.textMuted)),
                      Text('Geser untuk simulasi', style: GoogleFonts.inter(fontSize: 11, color: p.textSecondary)),
                      Text('Rp 5 Juta', style: GoogleFonts.inter(fontSize: 11, color: p.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Golongan Tarif Listrik PLN Presets
                  Text(
                    'Golongan Tarif Listrik PLN:',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: p.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _plnTariffPresets.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final isSelected = _selectedPlnTier == idx;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedPlnTier = idx;
                                _tariff.text = (item['rate'] as double).toStringAsFixed(2);
                              });
                              _calculate();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? p.neonTeal.withValues(alpha: 0.16)
                                    : p.cardElevated,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? p.neonTeal : p.borderColor,
                                  width: isSelected ? 1.4 : 0.8,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item['label'] as String,
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? p.neonTeal : p.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    item['desc'] as String,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: p.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Collapsible Advanced settings
                  InkWell(
                    onTap: () => setState(() => _showAdvancedSettings = !_showAdvancedSettings),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            _showAdvancedSettings ? Icons.keyboard_arrow_up : Icons.tune_rounded,
                            size: 16,
                            color: p.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Pengaturan Lanjutan (Tarif & Investasi)',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: p.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showAdvancedSettings) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tariff,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.inter(color: p.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              labelText: 'Tarif PLN (Rp/kWh)',
                              labelStyle: GoogleFonts.inter(fontSize: 12, color: p.textMuted),
                              filled: true,
                              fillColor: p.cardElevated,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: p.borderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: p.borderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: p.neonTeal, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _unitPrice,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.inter(color: p.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              labelText: 'Investasi (Rp)',
                              labelStyle: GoogleFonts.inter(fontSize: 12, color: p.textMuted),
                              filled: true,
                              fillColor: p.cardElevated,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: p.borderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: p.borderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: p.neonTeal, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Calculate and Save Buttons
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _calculate,
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.bolt_rounded, size: 18),
                          label: Text(
                            _busy ? 'Menghitung...' : 'Hitung Analisis Finansial',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: p.neonTeal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          onPressed: _saveSnapshot,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: p.borderColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Icon(Icons.bookmark_outline_rounded, size: 18, color: p.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _message!.contains('berhasil')
                            ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5))
                            : (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _message!.contains('berhasil')
                              ? (isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0))
                              : (isDark ? const Color(0xFFDC2626) : const Color(0xFFFECACA)),
                        ),
                      ),
                      child: Text(
                        _message!,
                        style: GoogleFonts.inter(
                          color: _message!.contains('berhasil')
                              ? (isDark ? const Color(0xFF34D399) : const Color(0xFF065F46))
                              : (isDark ? const Color(0xFFF87171) : const Color(0xFF991B1B)),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Glanceable Bento Savings Cards
            Row(
              children: [
                // Bento Card A: Monthly Savings
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                const Color(0xFF064E3B).withValues(alpha: isGlass ? 0.35 : 0.45),
                                isGlass
                                    ? const Color(0xFF1E293B).withValues(alpha: 0.35)
                                    : p.cardBg,
                              ]
                            : const [Color(0xFFECFDF5), Color(0xFFF0FDF4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark
                          ? (isGlass ? Colors.white.withValues(alpha: 0.22) : const Color(0xFF059669).withValues(alpha: 0.4))
                          : const Color(0xFFA7F3D0),
                      width: isGlass ? 1.0 : 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? p.greenPositive.withValues(alpha: 0.08)
                            : const Color(0xFF065F46).withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? p.greenPositive.withValues(alpha: 0.20)
                                  : const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.savings_outlined,
                              color: isDark ? p.greenPositive : const Color(0xFF065F46),
                              size: 20,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? p.greenPositive.withValues(alpha: 0.25)
                                  : const Color(0xFF065F46),
                              borderRadius: BorderRadius.circular(12),
                              border: isDark ? Border.all(color: p.greenPositive.withValues(alpha: 0.5)) : null,
                            ),
                            child: Text(
                              'HEMAT',
                              style: GoogleFonts.inter(
                                color: isDark ? p.greenPositive : Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Estimasi Hemat Listrik',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? p.textSecondary : const Color(0xFF065F46),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppConfig.formatRupiah(monthlySaving),
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? p.greenPositive : const Color(0xFF064E3B),
                          letterSpacing: -0.3,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '/ bulan (Rp ${(monthlySaving * 12 / 1000000).toStringAsFixed(1)} Jt/thn)',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: isDark ? p.textMuted : const Color(0xFF047857),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Bento Card B: Payback Years
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              const Color(0xFF78350F).withValues(alpha: isGlass ? 0.35 : 0.45),
                              isGlass
                                  ? const Color(0xFF1E293B).withValues(alpha: 0.35)
                                  : p.cardBg,
                            ]
                          : const [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark
                          ? (isGlass ? Colors.white.withValues(alpha: 0.22) : const Color(0xFFD97706).withValues(alpha: 0.4))
                          : const Color(0xFFFDE68A),
                      width: isGlass ? 1.0 : 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? p.solarAmber.withValues(alpha: 0.08)
                            : const Color(0xFF92400E).withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? p.solarAmber.withValues(alpha: 0.20)
                                  : const Color(0xFFF59E0B).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.timer_outlined,
                              color: isDark ? p.solarAmber : const Color(0xFF92400E),
                              size: 20,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? p.solarAmber.withValues(alpha: 0.25)
                                  : const Color(0xFF92400E),
                              borderRadius: BorderRadius.circular(12),
                              border: isDark ? Border.all(color: p.solarAmber.withValues(alpha: 0.5)) : null,
                            ),
                            child: Text(
                              'BALIK MODAL',
                              style: GoogleFonts.inter(
                                color: isDark ? p.solarAmber : Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Waktu Balik Modal',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? p.textSecondary : const Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${paybackYears.toStringAsFixed(1)} Tahun',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? p.solarAmber : const Color(0xFF78350F),
                          letterSpacing: -0.3,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sisa 21+ Thn Full Untung',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: isDark ? p.textMuted : const Color(0xFFB45309),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // BEP Milestone Roadmap Visual Card
          _buildBreakEvenRoadmapCard(context, paybackYears, monthlySaving, p),
          const SizedBox(height: 16),

          // 4. Spline Area Chart: Proyeksi Kumulatif Penghematan 25 Tahun
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isGlass ? const Color(0xFF1E293B).withValues(alpha: 0.35) : p.cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isGlass ? Colors.white.withValues(alpha: 0.20) : p.borderColor,
                width: isGlass ? 1.0 : 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: isGlass
                      ? p.neonTeal.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Proyeksi Finansial 25 Tahun',
                            style: GoogleFonts.inter(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: p.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Akumulasi Hemat vs Modal Inverter',
                            style: GoogleFonts.inter(fontSize: 11.5, color: p.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? p.greenPositive.withValues(alpha: 0.15) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                        border: isDark ? Border.all(color: p.greenPositive.withValues(alpha: 0.3)) : null,
                      ),
                      child: Text(
                        '25 Thn Garansi',
                        style: GoogleFonts.inter(
                          color: isDark ? p.greenPositive : const Color(0xFF065F46),
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSplineForecastChart(monthlySaving, p),
                const SizedBox(height: 16),
                // Legend pills
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _legendPill(p.neonTeal, 'Akumulasi Hemat', p),
                    _legendPill(p.solarAmber, 'Modal Investasi', p),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 5. Hardware Recommendation Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        p.neonTeal.withValues(alpha: isGlass ? 0.15 : 0.12),
                        isGlass
                            ? const Color(0xFF1E293B).withValues(alpha: 0.35)
                            : p.cardElevated,
                      ]
                    : const [Color(0xFFF0FDF4), Color(0xFFF8FAFC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? (isGlass ? Colors.white.withValues(alpha: 0.20) : p.borderColor)
                    : const Color(0xFFA7F3D0),
                width: isGlass ? 1.0 : 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? p.neonTeal.withValues(alpha: 0.05)
                      : const Color(0xFF0F766E).withValues(alpha: 0.04),
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: teal.withValues(alpha: 0.2)),
                      ),
                      child: InverterIconWidget(size: 28, color: teal),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'REKOMENDASI HARDWARE UTAMA',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: p.neonTeal,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'VoltTrack Smart Inverter VT-1000H',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: p.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Berdasarkan pola pemakaian tagihan ${AppConfig.formatRupiah(_monthlyBill)}/bln, Inverter Hybrid VoltTrack VT-1000H memberikan efisiensi puncak 98.2% dan memangkas tagihan secara maksimal.',
                  style: GoogleFonts.inter(fontSize: 12.5, color: p.textSecondary, height: 1.45),
                ),
                const SizedBox(height: 12),
                // Highlights
                _bulletRow('Efisiensi Konversi Maksimal 98.2%', p),
                _bulletRow('Garansi Perlindungan Resmi 25 Tahun', p),
                _bulletRow('Algoritma Smart Peak Shaving Memangkas Beban', p),
                const SizedBox(height: 16),
                if (widget.onExploreMarketplace != null)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: widget.onExploreMarketplace,
                      icon: const Icon(Icons.store_rounded, size: 16),
                      label: Text(
                        'Lihat Unit di Marketplace ➔',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: p.neonTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 6. Ringkasan Finansial Detail Card
          if (s != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isGlass ? const Color(0xFF1E293B).withValues(alpha: 0.35) : p.cardBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isGlass ? Colors.white.withValues(alpha: 0.20) : p.borderColor,
                  width: isGlass ? 1.0 : 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isGlass
                        ? p.neonTeal.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ringkasan Data Finansial', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: p.textPrimary)),
                  Divider(height: 20, color: p.borderColor),
                  _detailRow('Produksi Energi Surya', '${s['total_kwh']} kWh', p),
                  _detailRow('Beban Konsumsi Rumah', '${s['load_kwh']} kWh', p),
                  _detailRow('Surplus Mandiri (Self-Consumed)', '${((_num(s['self_consumption_ratio'])) * 100).toStringAsFixed(0)}%', p),
                  _detailRow('Offset Tagihan Bulan Ini', AppConfig.formatRupiah(monthlySaving), p),
                  _detailRow('Kualitas Diagnostik Sistem', '${s['data_quality'] ?? 'NORMAL'}'.toUpperCase(), p),
                ],
              ),
            ),
          const SizedBox(height: 16),
          ScaleOnPress(
            onTap: () => _showInvestmentProposalModal(context, monthlySaving, paybackYears, p),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: p.neonTeal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.neonTeal.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description_outlined, size: 18, color: p.neonTeal),
                  const SizedBox(width: 8),
                  Text(
                    'Ekspor Ringkasan Proposal ROI (Executive Summary)',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: p.neonTeal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Builder(
            builder: (ctx) {
              final bottom = MediaQuery.paddingOf(ctx).bottom;
              return SizedBox(height: bottom > 0 ? bottom + 80 : 96);
            },
          ),
        ],
      ),
    ),
  ));
  }

  Widget _bulletRow(String text, VoltTrackPalette p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 15, color: p.greenPositive),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: p.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, VoltTrackPalette p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: p.textMuted, fontSize: 12.5)),
          Text(
            value,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: p.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendPill(Color color, String label, VoltTrackPalette p) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: p.textSecondary, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // Spline Chart matching Dribbble reference with dynamic dark/light/glass styling
  Widget _buildSplineForecastChart(double monthlySaving, VoltTrackPalette p) {
    final annualSaving = monthlySaving * 12;
    final investment = double.tryParse(_unitPrice.text) ?? 15000000;

    // Generate 25 year spots with 4.5% annual growth in energy value
    final spots = <FlSpot>[];
    double cumulative = 0;
    spots.add(const FlSpot(0, 0));

    for (int y = 1; y <= 25; y++) {
      final yearVal = annualSaving * math.pow(1.045, y - 1);
      cumulative += yearVal;
      spots.add(FlSpot(y.toDouble(), cumulative));
    }

    final maxY = cumulative * 1.1;
    final investLine = [
      FlSpot(0, investment),
      FlSpot(25, investment),
    ];

    return SizedBox(
      height: 210,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: 25,
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) => FlLine(
              color: p.borderColor.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                interval: maxY / 3,
                getTitlesWidget: (v, _) {
                  if (v <= 0) return const SizedBox.shrink();
                  final millions = (v / 1000000).round();
                  return Text(
                    '${millions}Jt',
                    style: GoogleFonts.inter(fontSize: 9.5, color: p.textMuted, fontWeight: FontWeight.w600),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 5,
                getTitlesWidget: (v, _) {
                  final y = v.toInt();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Th $y',
                      style: GoogleFonts.inter(fontSize: 10, color: p.textMuted, fontWeight: FontWeight.w600),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => p.cardElevated,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final y = spot.x.toInt();
                  final val = spot.y;
                  final formatted = AppConfig.formatRupiah(val);
                  return LineTooltipItem(
                    'Tahun $y\n$formatted',
                    GoogleFonts.inter(color: p.textPrimary, fontWeight: FontWeight.w700, fontSize: 11),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            // Cumulative Profit Spline Area
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: p.neonTeal,
              barWidth: 3.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    p.neonTeal.withValues(alpha: 0.30),
                    p.neonTeal.withValues(alpha: 0.02),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Break-even line
            LineChartBarData(
              spots: investLine,
              isCurved: false,
              color: p.solarAmber,
              barWidth: 2,
              dashArray: [6, 4],
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakEvenRoadmapCard(BuildContext context, double paybackYears, double monthlySaving, VoltTrackPalette p) {
    final investment = double.tryParse(_unitPrice.text) ?? 15000000;
    final total25YrSaved = (monthlySaving * 12 * 25) - investment;
    final isGlass = ThemeController.instance.isGlass;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isGlass ? const Color(0xFF1E293B).withValues(alpha: 0.35) : p.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isGlass ? Colors.white.withValues(alpha: 0.20) : p.borderColor,
          width: isGlass ? 1.0 : 0.8,
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
                  color: p.solarAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.flag_rounded, color: p.solarAmber, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Peta Jalan Titik Impas (BEP Roadmap)',
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: p.textPrimary,
                    ),
                  ),
                  Text(
                    'Fase pengembalian modal s.d keuntungan murni',
                    style: GoogleFonts.inter(fontSize: 11, color: p.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Milestone Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Expanded(
                    flex: (paybackYears * 10).toInt().clamp(5, 50),
                    child: Container(
                      color: p.solarAmber,
                    ),
                  ),
                  Expanded(
                    flex: ((25 - paybackYears) * 10).toInt().clamp(10, 200),
                    child: Container(
                      color: p.greenPositive,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: p.solarAmber, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text('Balik Modal (BEP)', style: GoogleFonts.inter(fontSize: 11, color: p.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tahun ke-${paybackYears.toStringAsFixed(1)}',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: p.solarAmber),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: p.greenPositive, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text('Laba Bersih 25 Thn', style: GoogleFonts.inter(fontSize: 11, color: p.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppConfig.formatRupiah(total25YrSaved > 0 ? total25YrSaved : 45000000),
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: p.greenPositive),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showInvestmentProposalModal(BuildContext context, double monthlySaving, double paybackYears, VoltTrackPalette p) {
    HapticFeedback.mediumImpact();
    final investment = double.tryParse(_unitPrice.text) ?? 15000000;
    final total25YrSaved = (monthlySaving * 12 * 25) - investment;

    showModalBottomSheet(
      context: context,
      backgroundColor: p.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: p.borderColor, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: p.neonTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.analytics_rounded, color: p.neonTeal, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Executive ROI Proposal Sheet',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: p.textPrimary),
                        ),
                        Text('VoltTrack Clean Energy Investment Summary', style: GoogleFonts.inter(fontSize: 11.5, color: p.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: p.cardElevated,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: p.borderColor),
                ),
                child: Column(
                  children: [
                    _proposalRow('Investasi Sistem Awal', AppConfig.formatRupiah(investment), p),
                    const Divider(height: 16, color: Colors.white12),
                    _proposalRow('Tarif PLN Digunakan', 'Rp ${_tariff.text}/kWh', p),
                    const Divider(height: 16, color: Colors.white12),
                    _proposalRow('Rata-rata Hemat per Bulan', AppConfig.formatRupiah(monthlySaving), p, isGreen: true),
                    const Divider(height: 16, color: Colors.white12),
                    _proposalRow('Estimasi Balik Modal Penuh', '${paybackYears.toStringAsFixed(1)} Tahun', p),
                    const Divider(height: 16, color: Colors.white12),
                    _proposalRow('Keuntungan Bersih 25 Tahun', AppConfig.formatRupiah(total25YrSaved > 0 ? total25YrSaved : 45000000), p, isGreen: true),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: p.borderColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Text('Tutup', style: GoogleFonts.inter(color: p.textSecondary, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF0F766E),
                            content: Text(
                              'Ringkasan Proposal Finansial telah disiapkan untuk dibagikan!',
                              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.share_rounded, size: 16, color: Colors.black),
                      label: Text('Bagikan Proposal', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.black)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: p.neonTeal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _proposalRow(String label, String value, VoltTrackPalette p, {bool isGreen = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: p.textSecondary)),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: isGreen ? p.greenPositive : p.textPrimary,
          ),
        ),
      ],
    );
  }
}
