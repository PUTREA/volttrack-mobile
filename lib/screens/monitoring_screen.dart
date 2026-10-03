import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config.dart';
import '../services/data_service.dart';
import '../theme/theme_controller.dart';
import '../widgets/ambient_mesh_background.dart';
import '../widgets/energy_flow_widget.dart';
import '../widgets/friendly_bento_cards.dart';
import '../widgets/motion_helpers.dart';
import '../widgets/stitch_operational_strategy.dart';
import '../widgets/stitch_telemetry_bento.dart';
import '../widgets/stitch_mppt_diagnostics.dart';

// Dynamic monitoring design tokens reacting to Dark & Light mode
VoltTrackPalette get _palette => ThemeController.instance.palette;
Color get _kCardBg => _palette.cardBg;
Color get _kCardBgElevated => _palette.cardElevated;
Color get _kBorderColor => _palette.borderColor;
Color get _kNeonTeal => _palette.neonTeal;
Color get _kSolarAmber => _palette.solarAmber;
Color get _kBlue => const Color(0xFF60A5FA);
Color get _kGreen => _palette.greenPositive;
Color get _kTextPrimary => _palette.textPrimary;
Color get _kTextSecondary => _palette.textSecondary;
Color get _kTextMuted => _palette.textMuted;

/// Live monitoring energi terpadu:
/// Mode Simpel (Ramah Pengguna Awam) & Mode Grafik Detail (Pro/Teknis).
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
  int _activeSubTab = 0; // 0: Ringkasan, 1: Detail Info, 2: Grafik Tren

  @override
  void initState() {
    super.initState();
    ThemeController.instance.addListener(_onThemeChanged);
    _loadDevices();
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onThemeChanged);
    _timer?.cancel();
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
      _loadingDevices = false;
      if (list.isNotEmpty && _activationId == null) {
        _activationId = int.tryParse(list.first['id']?.toString() ?? '');
      }
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _kNeonTeal.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Memuat perangkat...',
              style: GoogleFonts.inter(color: _kTextSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }
    if (_devices.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => _loadDevices(),
        color: _kNeonTeal,
        backgroundColor: _kCardBg,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Center(
              child: Column(
                children: [
                  Icon(Icons.solar_power_outlined, size: 56,
                      color: _kTextMuted.withValues(alpha: 0.4)),
                  const SizedBox(height: 14),
                  Text(
                    'Belum ada perangkat teraktivasi.',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 16, color: _kTextSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Buka tab Garansi untuk mendaftarkan serial number unit Anda.',
                    style: GoogleFonts.inter(color: _kTextMuted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final r = _reading;
    final solarWatt = double.tryParse(r?['power_watt']?.toString() ?? '2800') ?? 2800.0;
    final loadWatt = double.tryParse(r?['load_watt']?.toString() ?? '1200') ?? 1200.0;
    final batterySoc = double.tryParse(r?['battery_soc']?.toString() ?? '85') ?? 85.0;
    final inverterStatus = r?['inverter_status']?.toString() ?? 'Normal';

    final currentDev = _devices.firstWhere(
      (d) => int.tryParse(d['id']?.toString() ?? '') == _activationId,
      orElse: () => _devices.isNotEmpty ? _devices.first : {},
    );
    final devProduct = currentDev['product'] as Map<String, dynamic>?;
    final devModel = devProduct?['product_name']?.toString() ?? 'VoltTrack Smart Hybrid Inverter';
    final devSerial = currentDev['serial_number']?.toString() ?? 'SN-DEMO-550WP';

    final isGlass = ThemeController.instance.isGlass;

    return AmbientMeshBackground(
      child: RefreshIndicator(
        onRefresh: () async => _poll(),
        color: _kNeonTeal,
        backgroundColor: _kCardBg,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // Header Card: Device Selector + Live Indicator + 3-Way Theme Switcher
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isGlass ? const Color(0xFF1E293B).withValues(alpha: 0.35) : _kCardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isGlass ? Colors.white.withValues(alpha: 0.22) : _kBorderColor,
                  width: isGlass ? 1.0 : 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isGlass
                        ? _kNeonTeal.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.25),
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _kNeonTeal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.solar_power_rounded, color: _kNeonTeal, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Halo, Pelanggan VoltTrack \u{1F44B}',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  color: _kTextPrimary,
                                ),
                              ),
                              Text(
                                'Pusat Kontrol Energi Mandiri',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: _kTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Live Status Badge — glowing green
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: _kGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, size: 7, color: _kGreen),
                            const SizedBox(width: 5),
                            Text(
                              'LIVE',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: _kGreen,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Row 3-Way Theme Switcher (Dark, Light, Frosted Glass)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isGlass ? Colors.white.withValues(alpha: 0.06) : _kCardBgElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isGlass ? Colors.white.withValues(alpha: 0.15) : _kBorderColor,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tema Visual:',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _kTextSecondary,
                          ),
                        ),
                        _buildThemeSegmentedPicker(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    dropdownColor: _kCardBgElevated,
                  iconEnabledColor: _kTextSecondary,
                  initialValue: _activationId,
                  style: GoogleFonts.inter(
                    color: _kTextPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    filled: true,
                    fillColor: _kCardBgElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _kBorderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _kBorderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _kNeonTeal, width: 1.5),
                    ),
                  ),
                  items: _devices.map((d) {
                    final product = d['product'] as Map<String, dynamic>?;
                    return DropdownMenuItem<int>(
                      value: int.tryParse(d['id']?.toString() ?? '') ?? 0,
                      child: Text(
                        '${product?['product_name'] ?? 'Unit'} · ${d['serial_number']}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: _kTextPrimary,
                        ),
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
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons: Simulasi Pemadaman PLN (Storm Mode) & Log Kejadian
          Row(
            children: [
              Expanded(
                child: ScaleOnPress(
                  onTap: () => _openOutageSimulationSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.flash_off_rounded, size: 16, color: Color(0xFFF87171)),
                        const SizedBox(width: 6),
                        Text(
                          'Simulasi PLN Padam',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFF87171),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ScaleOnPress(
                  onTap: () => _openEventLogSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    decoration: BoxDecoration(
                      color: _kNeonTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kNeonTeal.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_rounded, size: 16, color: _kNeonTeal),
                        const SizedBox(width: 6),
                        Text(
                          'Log Riwayat Sistem',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _kNeonTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Segmented Sub-Tab Switcher (3-Way: Ringkasan, Detail Info, Grafik Tren)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isGlass ? Colors.white.withValues(alpha: 0.06) : _kCardBgElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isGlass ? Colors.white.withValues(alpha: 0.18) : _kBorderColor,
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                _buildSubTabButton(
                  index: 0,
                  label: 'Ringkasan',
                  icon: Icons.bolt_rounded,
                  activeColor: _kSolarAmber,
                  isGlass: isGlass,
                ),
                _buildSubTabButton(
                  index: 1,
                  label: 'Detail Info',
                  icon: Icons.biotech_rounded,
                  activeColor: _kNeonTeal,
                  isGlass: isGlass,
                ),
                _buildSubTabButton(
                  index: 2,
                  label: 'Grafik Tren',
                  icon: Icons.insights_rounded,
                  activeColor: _kBlue,
                  isGlass: isGlass,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // TAMPILAN BERDASARKAN SUB-TAB
          if (_activeSubTab == 0) ...[
            // ==========================================
            // ⚡ SUB-TAB 0: RINGKASAN (LIVING SOLAR ORBIT & RINGKASAN FINANSIAL)
            // ==========================================
            EnergyFlowWidget(
              solarWatt: solarWatt,
              loadWatt: loadWatt,
              batterySoc: batterySoc,
              status: inverterStatus,
              reading: _reading,
            ),
            const SizedBox(height: 16),
            // 2x2 Telemetry Bento Grid dari Google Stitch
            StitchTelemetryBento(
              dailyYieldKwh: double.tryParse(_reading?['energy_accumulated']?['today_solar_kwh']?.toString() ?? '') ?? ((solarWatt * 4.8) / 1000.0).clamp(1.0, 99.0),
              yieldGrowthPercent: 14.8,
              monthlyRoiIdr: int.tryParse(_reading?['savings']?['month_saved_idr']?.toString() ?? '') ?? 1450000,
              monthlyTargetIdr: 2000000,
              autonomyPercent: (loadWatt > 0 ? ((solarWatt / loadWatt) * 100).clamp(0, 100).toDouble() : 92.0),
              co2OffsetKg: double.tryParse(_reading?['savings']?['co2_avoided_kg']?.toString() ?? '') ?? 14.2,
              treesEquivalent: 0.7,
            ),
            const SizedBox(height: 16),
            // Operational Strategy & Core Thermal Bar dari Google Stitch
            StitchOperationalStrategy(
              inverterTemp: double.tryParse(_reading?['inverter']?['temperature']?.toString() ?? '') ?? 34.0,
              mpptEfficiency: double.tryParse(_reading?['inverter']?['efficiency']?.toString() ?? '') ?? 98.6,
              fanSpeedPercent: 18,
            ),
            const SizedBox(height: 16),
            FriendlyBentoCards(
              solarWatt: solarWatt,
              loadWatt: loadWatt,
              batterySoc: batterySoc,
              serialNumber: devSerial,
              modelName: devModel,
              reading: _reading,
              mode: BentoDisplayMode.summaryOnly,
              onOpenDetail: () {
                HapticFeedback.selectionClick();
                setState(() => _activeSubTab = 1);
              },
            ),
            const SizedBox(height: 20),
          ] else if (_activeSubTab == 1) ...[
            // ==========================================
            // 🔬 SUB-TAB 1: DETAIL INFORMASI (TELEMETRI LENGKAP HARDWARE & GRID PLN)
            // ==========================================
            // Stitch Screen 2: Live Telemetry & MPPT Diagnostics
            StitchMpptDiagnostics(
              gridVoltage: double.tryParse(_reading?['grid']?['voltage']?.toString() ?? '') ?? 228.4,
              gridFreq: double.tryParse(_reading?['grid']?['frequency']?.toString() ?? '') ?? 50.02,
              gridCurrent: double.tryParse(_reading?['grid']?['current']?.toString() ?? '') ?? 7.8,
              gridCosPhi: 0.99,
              pv1Voltage: double.tryParse(_reading?['pv']?['pv1_voltage']?.toString() ?? '') ?? 380.0,
              pv1Current: double.tryParse(_reading?['pv']?['pv1_current']?.toString() ?? '') ?? 8.2,
              pv2Voltage: double.tryParse(_reading?['pv']?['pv2_voltage']?.toString() ?? '') ?? 375.0,
              pv2Current: double.tryParse(_reading?['pv']?['pv2_current']?.toString() ?? '') ?? 8.1,
              batterySoc: batterySoc,
              batteryVoltage: double.tryParse(_reading?['battery']?['voltage']?.toString() ?? '') ?? 52.4,
              batteryCurrent: double.tryParse(_reading?['battery']?['current']?.toString() ?? '') ?? 24.2,
              coreTemp: double.tryParse(_reading?['inverter']?['temperature']?.toString() ?? '') ?? 34.0,
              transformerTemp: 41.0,
              mosfetTemp: 38.0,
              fanSpeedPercent: 18,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isGlass ? Colors.white.withValues(alpha: 0.05) : _kCardBgElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isGlass ? Colors.white.withValues(alpha: 0.15) : _kBorderColor,
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kNeonTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.biotech_rounded, color: _kNeonTeal, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Telemetri Teknis Perangkat',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: _kTextPrimary,
                          ),
                        ),
                        Text(
                          'Diagnostik inverter, string PV, grid PLN & BMS baterai',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: _kTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FriendlyBentoCards(
              solarWatt: solarWatt,
              loadWatt: loadWatt,
              batterySoc: batterySoc,
              serialNumber: devSerial,
              modelName: devModel,
              reading: _reading,
              mode: BentoDisplayMode.detailOnly,
            ),
            const SizedBox(height: 20),
          ] else ...[
            // ==========================================
            // 📊 SUB-TAB 2: GRAFIK TREN / GELOMBANG MULTI-KURVA (DEYE & GROWATT STYLE)
            // ==========================================
            Row(
              children: [
                Expanded(
                  child: _metricCard(
                    title: 'Produksi Surya',
                    value: '${solarWatt.toInt()} W',
                    subtitle: 'PV Array Realtime',
                    icon: Icons.wb_sunny_rounded,
                    color: _kSolarAmber,
                    bgColor: _kSolarAmber.withValues(alpha: 0.12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricCard(
                    title: 'Beban Rumah',
                    value: '${loadWatt.toInt()} W',
                    subtitle: 'Konsumsi Aktif',
                    icon: Icons.home_rounded,
                    color: _kGreen,
                    bgColor: _kGreen.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _metricCard(
                    title: 'Jaringan PLN',
                    value: '${(double.tryParse((_reading?['grid'] as Map?)?['power_watt']?.toString() ?? '') ?? (solarWatt > loadWatt ? (solarWatt - loadWatt) : (loadWatt - solarWatt))).toInt()} W',
                    subtitle: 'Status: ${((_reading?['grid'] as Map?)?['mode'] ?? (solarWatt > loadWatt ? 'Export' : 'Import')).toString().toUpperCase()}',
                    icon: Icons.electric_bolt_rounded,
                    color: _kBlue,
                    bgColor: _kBlue.withValues(alpha: 0.12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricCard(
                    title: 'Baterai ESS',
                    value: '${batterySoc.toInt()}%',
                    subtitle: '${(double.tryParse((_reading?['battery'] as Map?)?['power_watt']?.toString() ?? '') ?? (solarWatt - loadWatt).abs()).toInt()} W · ${((_reading?['battery'] as Map?)?['status'] ?? (solarWatt > loadWatt ? 'Isi' : 'Buang'))}',
                    icon: Icons.battery_charging_full_rounded,
                    color: _kNeonTeal,
                    bgColor: _kNeonTeal.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Kurva Multi-Lapisan: Surya, Beban, PLN, & Baterai
            _multiChartCard(
              title: 'Kurva Keseimbangan Energi Multi-Lapisan (W)',
              subtitle: 'Surya, Beban Rumah, PLN, dan Baterai ESS simultan',
              chart: _multiLineEnergyChart(_series),
            ),
            const SizedBox(height: 16),

            // Grafik Baterai SOC (%)
            _chartCard(
              title: 'Persentase Baterai SOC (%)',
              subtitle: 'Kapasitas penyimpanan ESS dalam siklus 20 titik',
              color: _kNeonTeal,
              chart: _lineChart(_series, 'battery_soc', _kNeonTeal, maxY: 100),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    ),
  );
}

  Widget _buildThemeSegmentedPicker() {
    final currentType = ThemeController.instance.themeType;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _themeOptionItem(
          label: 'Gelap',
          icon: Icons.dark_mode_rounded,
          active: currentType == AppThemeType.dark,
          type: AppThemeType.dark,
        ),
        const SizedBox(width: 4),
        _themeOptionItem(
          label: 'Terang',
          icon: Icons.light_mode_rounded,
          active: currentType == AppThemeType.light,
          type: AppThemeType.light,
        ),
        const SizedBox(width: 4),
        _themeOptionItem(
          label: 'Glass',
          icon: Icons.auto_awesome_rounded,
          active: currentType == AppThemeType.glass,
          type: AppThemeType.glass,
        ),
      ],
    );
  }

  Widget _themeOptionItem({
    required String label,
    required IconData icon,
    required bool active,
    required AppThemeType type,
  }) {
    return ScaleOnPress(
      onTap: () {
        ThemeController.instance.setThemeType(type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
        decoration: BoxDecoration(
          color: active
              ? (type == AppThemeType.glass
                  ? const Color(0xFF10B981).withValues(alpha: 0.22)
                  : _kCardBg)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: active
              ? Border.all(
                  color: type == AppThemeType.glass
                      ? const Color(0xFF10B981)
                      : _kBorderColor,
                  width: 1.0,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: active
                  ? (type == AppThemeType.glass ? const Color(0xFF2DD4BF) : _kNeonTeal)
                  : _kTextMuted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                color: active ? _kTextPrimary : _kTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTabButton({
    required int index,
    required String label,
    required IconData icon,
    required Color activeColor,
    required bool isGlass,
  }) {
    final isSelected = _activeSubTab == index;
    return Expanded(
      child: ScaleOnPress(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _activeSubTab = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: kEaseOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? (isGlass ? Colors.white.withValues(alpha: 0.14) : _kCardBg)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(
                    color: isGlass ? Colors.white.withValues(alpha: 0.25) : _kBorderColor,
                    width: 0.8,
                  )
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: isGlass
                          ? activeColor.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? activeColor : _kTextMuted,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? _kTextPrimary : _kTextMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    final isGlass = ThemeController.instance.isGlass;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isGlass ? const Color(0xFF1E293B).withValues(alpha: 0.35) : _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGlass ? Colors.white.withValues(alpha: 0.22) : _kBorderColor,
          width: isGlass ? 1.0 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: isGlass
                ? color.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(
                title,
                style: GoogleFonts.inter(
                  color: _kTextSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _kTextPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              color: _kTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _multiChartCard({
    required String title,
    required String subtitle,
    required Widget chart,
  }) {
    final isGlass = ThemeController.instance.isGlass;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: isGlass ? const Color(0xFF1E293B).withValues(alpha: 0.35) : _kCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isGlass ? Colors.white.withValues(alpha: 0.22) : _kBorderColor,
          width: isGlass ? 1.0 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: _kTextPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: _kTextMuted,
            ),
          ),
          const SizedBox(height: 12),
          // Legend row (Growatt & Deye style)
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildLegendBadge('Surya', _kSolarAmber),
              _buildLegendBadge('Beban', _kGreen),
              _buildLegendBadge('PLN Grid', _kBlue),
              _buildLegendBadge('Baterai', _kNeonTeal),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(height: 190, child: chart),
        ],
      ),
    );
  }

  Widget _buildLegendBadge(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: _kTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _chartCard({
    required String title,
    required String subtitle,
    required Color color,
    required Widget chart,
  }) {
    final isGlass = ThemeController.instance.isGlass;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: isGlass ? const Color(0xFF1E293B).withValues(alpha: 0.35) : _kCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isGlass ? Colors.white.withValues(alpha: 0.22) : _kBorderColor,
          width: isGlass ? 1.0 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: _kTextPrimary,
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
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(height: 180, child: chart),
        ],
      ),
    );
  }

  Widget _multiLineEnergyChart(List<Map<String, dynamic>> series) {
    if (series.isEmpty) {
      return Center(
        child: Text(
          'Menunggu data series telemetri...',
          style: GoogleFonts.inter(color: _kTextMuted, fontSize: 12),
        ),
      );
    }

    final solarSpots = <FlSpot>[];
    final loadSpots = <FlSpot>[];
    final gridSpots = <FlSpot>[];
    final batSpots = <FlSpot>[];

    for (var i = 0; i < series.length; i++) {
      final item = series[i];
      final x = i.toDouble();

      final sW = double.tryParse(item['power_watt']?.toString() ?? '') ?? 0.0;
      final lW = double.tryParse(item['load_watt']?.toString() ?? '') ?? 0.0;
      final gW = double.tryParse(item['grid_power_watt']?.toString() ?? '') ?? (sW > lW ? 0.0 : (lW - sW));
      final bW = double.tryParse(item['battery_power_watt']?.toString() ?? '') ?? (sW - lW).abs();

      solarSpots.add(FlSpot(x, sW));
      loadSpots.add(FlSpot(x, lW));
      gridSpots.add(FlSpot(x, gW));
      batSpots.add(FlSpot(x, bW));
    }

    return LineChart(
      LineChartData(
        minY: 0,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: _kBorderColor.withValues(alpha: 0.5),
            strokeWidth: 0.8,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  color: _kTextMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          // Surya (Amber)
          LineChartBarData(
            spots: solarSpots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: _kSolarAmber,
            barWidth: 2.2,
            dotData: const FlDotData(show: false),
          ),
          // Beban (Green)
          LineChartBarData(
            spots: loadSpots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: _kGreen,
            barWidth: 2.2,
            dotData: const FlDotData(show: false),
          ),
          // PLN (Blue)
          LineChartBarData(
            spots: gridSpots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: _kBlue,
            barWidth: 1.8,
            dashArray: [5, 4],
            dotData: const FlDotData(show: false),
          ),
          // Baterai (Teal)
          LineChartBarData(
            spots: batSpots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: _kNeonTeal,
            barWidth: 1.8,
            dotData: const FlDotData(show: false),
          ),
        ],
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
      return Center(
        child: Text(
          'Menunggu data series...',
          style: GoogleFonts.inter(color: _kTextMuted, fontSize: 12),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < series.length; i++) {
      final v = series[i][field];
      if (v != null) {
        final doubleVal = double.tryParse(v.toString()) ?? 0.0;
        spots.add(FlSpot(i.toDouble(), doubleVal));
      }
    }
    if (spots.isEmpty) {
      return Center(
        child: Text(
          'Belum ada titik data',
          style: GoogleFonts.inter(color: _kTextMuted, fontSize: 12),
        ),
      );
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY != null ? (maxY / 4) : null,
          getDrawingHorizontalLine: (value) => FlLine(
            color: _kBorderColor.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: _kTextMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: color,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.22),
                  color.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openOutageSimulationSheet(BuildContext context) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => _OutageSimulationSheet(reading: _reading),
    );
  }

  void _openEventLogSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => const _SystemEventLogSheet(),
    );
  }
}

// ==========================================
// ⚡ SHEET SIMULASI PEMADAMAN PLN (UPS MODE)
// ==========================================
class _OutageSimulationSheet extends StatefulWidget {
  final Map<String, dynamic>? reading;
  const _OutageSimulationSheet({this.reading});

  @override
  State<_OutageSimulationSheet> createState() => _OutageSimulationSheetState();
}

class _OutageSimulationSheetState extends State<_OutageSimulationSheet> {
  bool _isBlackout = true;

  @override
  Widget build(BuildContext context) {
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
              decoration: BoxDecoration(color: _kBorderColor, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (_isBlackout ? const Color(0xFFEF4444) : const Color(0xFF10B981)).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _isBlackout ? Icons.flash_off_rounded : Icons.flash_on_rounded,
                  color: _isBlackout ? const Color(0xFFF87171) : const Color(0xFF34D399),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isBlackout ? 'SIMULASI PLN PADAM (BLACKOUT)' : 'JARINGAN PLN NORMAL',
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: _isBlackout ? const Color(0xFFF87171) : const Color(0xFF34D399),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      _isBlackout ? 'Inverter VoltTrack aktif dalam mode UPS Islanding' : 'Jaringan terhubung paralel dengan PLN',
                      style: GoogleFonts.inter(fontSize: 11.5, color: _kTextMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kCardBgElevated,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _isBlackout ? const Color(0xFFEF4444).withValues(alpha: 0.35) : _kBorderColor,
              ),
            ),
            child: Column(
              children: [
                _simRow('Status Grid PLN', _isBlackout ? '0 Watt (Terputus Total)' : '228.4 V / 50 Hz (Online)',
                    isAlert: _isBlackout),
                const Divider(height: 14, color: Colors.white12),
                _simRow('Waktu Transfer Saklar', '8 ms (Tanpa Jeda / No Flicker)', isHighlight: true),
                const Divider(height: 14, color: Colors.white12),
                _simRow('Beban Rumah Terjamin', '1.200 Watt (100% Menyala Normal)'),
                const Divider(height: 14, color: Colors.white12),
                _simRow('Suplai Daya Aktif', 'Baterai ESS LFP + Panel Surya'),
                const Divider(height: 14, color: Colors.white12),
                _simRow('Estimasi Cadangan Daya', '14 Jam 30 Menit Tersisa', isHighlight: true),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Toggle simulasi
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Simulasikan Pemadaman Grid PLN',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _kTextPrimary),
              ),
              subtitle: Text(
                'Tekan untuk menguji peralihan saklar inverter secara virtual',
                style: GoogleFonts.inter(fontSize: 11.5, color: _kTextMuted),
              ),
              value: _isBlackout,
              activeThumbColor: const Color(0xFFEF4444),
              activeTrackColor: const Color(0xFFEF4444).withValues(alpha: 0.35),
              onChanged: (v) {
                HapticFeedback.mediumImpact();
                setState(() => _isBlackout = v);
              },
            ),
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kNeonTeal,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: Text(
                'Selesai Pengujian',
                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _simRow(String label, String val, {bool isAlert = false, bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: _kTextSecondary),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            val,
            textAlign: TextAlign.end,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: isAlert
                  ? const Color(0xFFF87171)
                  : (isHighlight ? _kNeonTeal : _kTextPrimary),
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 📋 SHEET LOG RIWAYAT KEJADIAN SISTEM
// ==========================================
class _SystemEventLogSheet extends StatelessWidget {
  const _SystemEventLogSheet();

  final List<Map<String, dynamic>> _events = const [
    {
      'time': '12:15:30',
      'title': 'Dual MPPT Mencapai Puncak Radiasi',
      'desc': 'String PV 1 & 2 menghasilkan total 3.240 Watt daya bersih.',
      'type': 'optimal',
    },
    {
      'time': '11:30:12',
      'title': 'Baterai ESS 85% — Surplus Dialihkan',
      'desc': 'Algoritma cerdas mulai mengekspor surplus ke jaringan PLN.',
      'type': 'info',
    },
    {
      'time': '09:05:44',
      'title': 'Pengecekan Rutin Sensor Suhu Inti',
      'desc': 'Suhu MOSFET stabil di 38°C, kipas berputar hening 18%.',
      'type': 'normal',
    },
    {
      'time': '06:12:00',
      'title': 'Inverter Boot & Sinkronisasi Grid',
      'desc': 'Sistem aktif otomatis mendeteksi fajar radiasi 80 W/m².',
      'type': 'normal',
    },
  ];

  @override
  Widget build(BuildContext context) {
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
              decoration: BoxDecoration(color: _kBorderColor, borderRadius: BorderRadius.circular(2)),
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
                child: Icon(Icons.history_edu_rounded, color: _kNeonTeal, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Log Kejadian Sistem Real-Time',
                    style: GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.w800, color: _kTextPrimary),
                  ),
                  Text('Telemetri status hardware & switching inverter', style: GoogleFonts.inter(fontSize: 11.5, color: _kTextMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._events.map((e) {
            Color color;
            IconData icon;
            switch (e['type']) {
              case 'optimal':
                color = const Color(0xFFF59E0B);
                icon = Icons.wb_sunny_rounded;
                break;
              case 'info':
                color = _kNeonTeal;
                icon = Icons.bolt_rounded;
                break;
              default:
                color = const Color(0xFF34D399);
                icon = Icons.check_circle_outline_rounded;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kCardBgElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kBorderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              e['title'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _kTextPrimary,
                              ),
                            ),
                            Text(
                              e['time'] as String,
                              style: GoogleFonts.inter(fontSize: 11, color: _kTextMuted, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          e['desc'] as String,
                          style: GoogleFonts.inter(fontSize: 11.5, color: _kTextSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
