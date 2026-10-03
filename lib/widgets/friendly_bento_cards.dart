import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/theme_controller.dart';
import 'energy_flow_widget.dart';

/// Bento cards komprehensif telemetri energi kelas industri (Deye Cloud & Growatt ShinePhone).
/// Menampilkan detail lengkap:
/// 1. Penghematan PLN (Rupiah & kWh harian/bulanan/akumulasi dengan tarif resmi PLN)
/// 2. Neraca Energi & Kemandirian (Self-Sufficiency & Self-Consumption)
/// 3. String Solar PV (Growatt style: MPPT PV1 & PV2 Volt, Ampere, Watt)
/// 4. Diagnostik Grid PLN (Deye style: Tegangan 222V, Frekuensi 50Hz, Impor/Ekspor, Biaya Beli)
/// 5. Baterai ESS Storage (SoC, Voltase 51.8V, Arus, Suhu Sel, Pengisian & Pelepasan kWh)
enum BentoDisplayMode {
  all,
  summaryOnly,
  detailOnly,
}

/// Bento cards komprehensif telemetri energi kelas industri (Deye Cloud & Growatt ShinePhone).
/// Menampilkan detail lengkap:
/// 1. Penghematan PLN (Rupiah & kWh harian/bulanan/akumulasi dengan tarif resmi PLN)
/// 2. Neraca Energi & Kemandirian (Self-Sufficiency & Self-Consumption)
/// 3. String Solar PV (Growatt style: MPPT PV1 & PV2 Volt, Ampere, Watt)
/// 4. Diagnostik Grid PLN (Deye style: Tegangan 222V, Frekuensi 50Hz, Impor/Ekspor, Biaya Beli)
/// 5. Baterai ESS Storage (SoC, Voltase 51.8V, Arus, Suhu Sel, Pengisian & Pelepasan kWh)
/// 6. Inverter & ESG Lingkungan (Efisiensi 97.4%, Suhu Inverter, CO2 dihindari, Setara Pohon)
class FriendlyBentoCards extends StatelessWidget {
  final double solarWatt;
  final double loadWatt;
  final double batterySoc;
  final String? serialNumber;
  final String? modelName;
  final Map<String, dynamic>? reading;
  final BentoDisplayMode mode;
  final VoidCallback? onOpenDetail;

  const FriendlyBentoCards({
    super.key,
    required this.solarWatt,
    required this.loadWatt,
    required this.batterySoc,
    this.serialNumber = 'SN-DEMO-550WP',
    this.modelName = 'VoltTrack Smart Hybrid VT-5500',
    this.reading,
    this.mode = BentoDisplayMode.all,
    this.onOpenDetail,
  });

  String _formatIdr(num amount) {
    return amount.round().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final isDark = ThemeController.instance.isDark;

    const emerald = Color(0xFF10B981);
    const amber = Color(0xFFF59E0B);
    const blue = Color(0xFF3B82F6);
    const teal = Color(0xFF0D9488);

    final r = reading;
    final pv = r?['pv'] as Map<String, dynamic>?;
    final grid = r?['grid'] as Map<String, dynamic>?;
    final bat = r?['battery'] as Map<String, dynamic>?;
    final inv = r?['inverter'] as Map<String, dynamic>?;
    final energy = r?['energy_accumulated'] as Map<String, dynamic>?;
    final savings = r?['savings'] as Map<String, dynamic>?;

    // 1. Daya Utama
    final curSolar = double.tryParse(r?['power_watt']?.toString() ?? '') ?? solarWatt;
    final curLoad = double.tryParse(r?['load_watt']?.toString() ?? '') ?? loadWatt;
    final curSoc = double.tryParse(r?['battery_soc']?.toString() ?? '') ?? batterySoc;

    // 2. PV Strings (Growatt ShinePhone)
    final pv1V = double.tryParse(pv?['pv1_voltage']?.toString() ?? '') ?? (curSolar > 0 ? 342.1 : 0.0);
    final pv1A = double.tryParse(pv?['pv1_current']?.toString() ?? '') ?? (curSolar > 0 ? ((curSolar * 0.52) / (pv1V > 0 ? pv1V : 1)) : 0.0);
    final pv1W = double.tryParse(pv?['pv1_power']?.toString() ?? '') ?? (curSolar * 0.52);

    final pv2V = double.tryParse(pv?['pv2_voltage']?.toString() ?? '') ?? (curSolar > 0 ? 339.8 : 0.0);
    final pv2A = double.tryParse(pv?['pv2_current']?.toString() ?? '') ?? (curSolar > 0 ? ((curSolar * 0.48) / (pv2V > 0 ? pv2V : 1)) : 0.0);
    final pv2W = double.tryParse(pv?['pv2_power']?.toString() ?? '') ?? (curSolar * 0.48);

    // 3. PLN Grid (Deye Cloud)
    final gridW = double.tryParse(grid?['power_watt']?.toString() ?? '') ?? (curSolar > curLoad ? 0.0 : (curLoad - curSolar));
    final gridV = double.tryParse(grid?['voltage']?.toString() ?? '') ?? 222.4;
    final gridFreq = double.tryParse(grid?['frequency']?.toString() ?? '') ?? 50.02;
    final gridMode = (grid?['mode'] ?? (curSolar > curLoad ? 'export' : 'import')).toString();
    final gridPurchasedTodayKwh = double.tryParse(grid?['energy_purchased_today_kwh']?.toString() ?? '') ?? 1.8;
    final gridPurchasedCostIdr = (gridPurchasedTodayKwh * 1444.70).round();

    // 4. Battery ESS
    final batW = double.tryParse(bat?['power_watt']?.toString() ?? '') ?? (curSolar - curLoad).abs();
    final batV = double.tryParse(bat?['voltage']?.toString() ?? '') ?? 51.8;
    final batA = double.tryParse(bat?['current']?.toString() ?? '') ?? (batW / (batV > 0 ? batV : 51.8));
    final batStatus = (bat?['status'] ?? (curSolar > curLoad ? 'Charging' : 'Discharging')).toString();
    final batTemp = double.tryParse(bat?['temperature']?.toString() ?? '') ?? 28.5;
    final batChargeTodayKwh = double.tryParse(bat?['daily_charging_kwh']?.toString() ?? '') ?? 6.4;
    final batDischargeTodayKwh = double.tryParse(bat?['daily_discharging_kwh']?.toString() ?? '') ?? 4.8;

    // 5. Inverter
    final invEfficiency = double.tryParse(inv?['efficiency']?.toString() ?? '') ?? 97.4;
    final invTemp = double.tryParse(inv?['temperature']?.toString() ?? '') ?? 38.5;

    // 6. Energy Accumulations & Financial Savings
    final todaySolarKwh = double.tryParse(energy?['today_solar_kwh']?.toString() ?? '') ?? ((curSolar * 4.8) / 1000.0);
    final todayLoadKwh = double.tryParse(energy?['today_load_kwh']?.toString() ?? '') ?? 14.2;
    final selfSufficiency = double.tryParse(energy?['self_sufficiency_rate']?.toString() ?? '') ??
        (curLoad > 0 ? ((curSolar / curLoad) * 100).clamp(0, 100).toDouble() : 100.0);
    final selfConsumption = double.tryParse(energy?['self_consumption_rate']?.toString() ?? '') ?? 98.1;

    final todaySavedIdr = int.tryParse(savings?['today_saved_idr']?.toString() ?? '') ?? (todaySolarKwh * 1444.70).round();
    final monthSavedIdr = int.tryParse(savings?['month_saved_idr']?.toString() ?? '') ?? (todaySavedIdr * 30);
    final lifetimeSavedIdr = int.tryParse(savings?['lifetime_saved_idr']?.toString() ?? '') ?? 7820000;
    final co2AvoidedKg = double.tryParse(savings?['co2_avoided_kg']?.toString() ?? '') ?? (todaySolarKwh * 30 * 0.85);
    final treesEquivalent = int.tryParse(savings?['trees_equivalent']?.toString() ?? '') ?? (co2AvoidedKg / 1.7).round();

    final showSummary = mode == BentoDisplayMode.all || mode == BentoDisplayMode.summaryOnly;
    final showDetail = mode == BentoDisplayMode.all || mode == BentoDisplayMode.detailOnly;

    return Column(
      children: [
        if (showSummary) ...[
          // ==============================================================
          // CARD 1: PENGHEMATAN BIAYA PLN (DEYE & GROWATT METRIC)
          // ==============================================================
          _BentoCard(
          p: p,
          glowColor: emerald,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: emerald.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.savings_rounded, size: 20, color: emerald),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EFISIENSI & PENGHEMATAN PLN',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: emerald,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'Tarif Resmi PLN: Rp 1.444,70 / kWh',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: p.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: emerald.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      'R-1/TR 1.300-5.500VA',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: emerald,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Estimasi Hemat Hari Ini',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: p.textSecondary),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'Rp ${_formatIdr(todaySavedIdr)}',
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: emerald,
                      letterSpacing: -0.6,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${todaySolarKwh.toStringAsFixed(1)} kWh mandiri)',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: p.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Sub-metrics row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: p.cardElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.borderColor, width: 0.8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bulan Ini', style: GoogleFonts.inter(fontSize: 10.5, color: p.textMuted)),
                          const SizedBox(height: 2),
                          Text(
                            'Rp ${_formatIdr(monthSavedIdr)}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: p.textPrimary,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 28, color: p.borderColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Akumulasi Total', style: GoogleFonts.inter(fontSize: 10.5, color: p.textMuted)),
                          const SizedBox(height: 2),
                          Text(
                            'Rp ${_formatIdr(lifetimeSavedIdr)}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: p.textPrimary,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ==============================================================
        // CARD 2: KEMANDIRIAN ENERGI & NERACA BEBAN (SELF-SUFFICIENCY)
        // ==============================================================
        _BentoCard(
          p: p,
          glowColor: teal,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.pie_chart_outline_rounded, size: 18, color: teal),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'KEMANDIRIAN ENERGI (AUTONOMY)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: teal,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${selfSufficiency.toStringAsFixed(1)}%',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: emerald,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Segmented progress visual bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 9,
                  child: Row(
                    children: [
                      Expanded(
                        flex: selfSufficiency.clamp(5, 95).toInt(),
                        child: Container(color: emerald),
                      ),
                      Expanded(
                        flex: (100 - selfSufficiency).clamp(5, 95).toInt(),
                        child: Container(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: emerald, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'Mandiri: ${selfSufficiency.toStringAsFixed(1)}%',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: p.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'Konsumsi: ${selfConsumption.toStringAsFixed(1)}%',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: p.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // 3 Mini badges: Produksi, Beban, Beli PLN
              Row(
                children: [
                  Expanded(
                    child: _buildMiniStat(
                      p: p,
                      label: 'Produksi Surya',
                      value: '${todaySolarKwh.toStringAsFixed(1)} kWh',
                      accent: amber,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniStat(
                      p: p,
                      label: 'Konsumsi Beban',
                      value: '${todayLoadKwh.toStringAsFixed(1)} kWh',
                      accent: emerald,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniStat(
                      p: p,
                      label: 'Impor PLN',
                      value: '${gridPurchasedTodayKwh.toStringAsFixed(1)} kWh',
                      accent: blue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (mode == BentoDisplayMode.summaryOnly && onOpenDetail != null) ...[
          const SizedBox(height: 14),
          _BentoCard(
            p: p,
            glowColor: const Color(0xFF06B6D4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: InkWell(
              onTap: onOpenDetail,
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.biotech_rounded, color: Color(0xFF06B6D4), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Diagnostik Hardware & Grid PLN',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: p.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'MPPT PV1/PV2, sinyal PLN 50Hz, & BMS 16S',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: p.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Detail',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF06B6D4),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF06B6D4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
      if (showSummary && showDetail) const SizedBox(height: 14),
      if (showDetail) ...[
        // ==============================================================
        // CARD 3 & 4 (ROW): SOLAR STRINGS (GROWATT) & PLN GRID (DEYE)
        // ==============================================================
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KARTU 3: STRING SOLAR PV (GROWATT SHINEPHONE STYLE)
            Expanded(
              child: _BentoCard(
                p: p,
                glowColor: amber,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.solar_power_rounded, size: 16, color: amber),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '2 MPPT',
                            style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w800, color: amber),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'String Solar PV',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: p.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    _buildTelemetryRow(p: p, label: 'PV1 Daya', value: '${pv1W.toInt()} W', bold: true),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (pv1W / 3000.0).clamp(0.06, 1.0),
                        minHeight: 4,
                        backgroundColor: p.cardElevated,
                        valueColor: const AlwaysStoppedAnimation<Color>(amber),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildTelemetryRow(p: p, label: 'PV1 V/I', value: '${pv1V.toStringAsFixed(1)}V · ${pv1A.toStringAsFixed(1)}A'),
                    const Divider(height: 12, thickness: 0.6),
                    _buildTelemetryRow(p: p, label: 'PV2 Daya', value: '${pv2W.toInt()} W', bold: true),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (pv2W / 3000.0).clamp(0.06, 1.0),
                        minHeight: 4,
                        backgroundColor: p.cardElevated,
                        valueColor: const AlwaysStoppedAnimation<Color>(amber),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildTelemetryRow(p: p, label: 'PV2 V/I', value: '${pv2V.toStringAsFixed(1)}V · ${pv2A.toStringAsFixed(1)}A'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // KARTU 4: DIAGNOSTIK JARINGAN PLN (DEYE CLOUD STYLE + SINE WAVE)
            Expanded(
              child: _BentoCard(
                p: p,
                glowColor: blue,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.electric_meter_rounded, size: 16, color: blue),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            gridMode.toUpperCase(),
                            style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w800, color: blue),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Jaringan PLN',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: p.textPrimary),
                        ),
                        // Mini AC Sine Wave badge (50Hz)
                        SizedBox(
                          width: 32,
                          height: 14,
                          child: CustomPaint(painter: _MiniSineWavePainter(color: blue)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildTelemetryRow(p: p, label: 'Daya Grid', value: '${gridW.toInt()} W', bold: true),
                    const SizedBox(height: 3),
                    _buildTelemetryRow(p: p, label: 'Tegangan', value: '${gridV.toStringAsFixed(1)} V'),
                    const Divider(height: 12, thickness: 0.6),
                    _buildTelemetryRow(p: p, label: 'Frekuensi', value: '${gridFreq.toStringAsFixed(1)} Hz'),
                    const SizedBox(height: 3),
                    _buildTelemetryRow(p: p, label: 'Beli Hari Ini', value: 'Rp ${_formatIdr(gridPurchasedCostIdr)}'),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ==============================================================
        // CARD 5: BATERAI ESS STORAGE & BMS TELEMETRI (MULTI-CELL SEGMENT)
        // ==============================================================
        _BentoCard(
          p: p,
          glowColor: teal,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.battery_charging_full_rounded, size: 18, color: teal),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'BATERAI ESS & BMS TELEMETRY',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: teal,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'LiFePO4 16S',
                      style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: teal),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 5-Cell Visual Battery Meter
              Row(
                children: List.generate(5, (index) {
                  final filled = curSoc >= ((index + 1) * 20);
                  return Expanded(
                    child: Container(
                      height: 6,
                      margin: EdgeInsets.only(right: index < 4 ? 4 : 0),
                      decoration: BoxDecoration(
                        color: filled ? teal : (isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: filled
                            ? [BoxShadow(color: teal.withValues(alpha: 0.4), blurRadius: 4)]
                            : null,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Status Daya', style: GoogleFonts.inter(fontSize: 10.5, color: p.textMuted)),
                        const SizedBox(height: 2),
                        Text(
                          '$batStatus ${batW.toInt()} W',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: p.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tegangan Pack', style: GoogleFonts.inter(fontSize: 10.5, color: p.textMuted)),
                        const SizedBox(height: 2),
                        Text(
                          '${batV.toStringAsFixed(1)} V · ${batA.toStringAsFixed(1)} A',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: p.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Suhu BMS', style: GoogleFonts.inter(fontSize: 10.5, color: p.textMuted)),
                        const SizedBox(height: 2),
                        Text(
                          '${batTemp.toStringAsFixed(1)} °C',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: emerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: p.cardElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: p.borderColor, width: 0.8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Siklus Hari Ini: Isi ${batChargeTodayKwh.toStringAsFixed(1)} kWh · Buang ${batDischargeTodayKwh.toStringAsFixed(1)} kWh',
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: p.textSecondary),
                    ),
                    Text(
                      'SoC ${curSoc.toInt()}%',
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: teal),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ==============================================================
        // CARD 6: HARDWARE INVERTER & DAMPAK LINGKUNGAN ESG
        // ==============================================================
        _BentoCard(
          p: p,
          glowColor: emerald,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: emerald.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: InverterIconWidget(size: 20, color: emerald),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            modelName ?? 'VoltTrack Smart Hybrid VT-5500',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: p.textPrimary,
                            ),
                          ),
                          Text(
                            'SN: $serialNumber · Garansi 25 Thn',
                            style: GoogleFonts.inter(fontSize: 10.5, color: p.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: emerald.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Efisiensi ${invEfficiency.toStringAsFixed(1)}% · ${invTemp.toStringAsFixed(0)}°C',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: emerald),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.cardElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.borderColor, width: 0.8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: emerald.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(child: Icon(Icons.park_rounded, color: emerald, size: 20)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dampak Lingkungan Hijau (ESG)',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: p.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Menghemat ${co2AvoidedKg.toStringAsFixed(0)} kg CO₂ · Setara $treesEquivalent pohon diselamatkan',
                            style: GoogleFonts.inter(fontSize: 10.5, color: emerald, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );
  }

  Widget _buildMiniStat({
    required VoltTrackPalette p,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: p.cardElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.borderColor, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 9.5, color: p.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: accent,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryRow({
    required VoltTrackPalette p,
    required String label,
    required String value,
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: p.textMuted)),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: p.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Internal reusable tactile card with subtle hairline borders.
class _BentoCard extends StatelessWidget {
  final Widget child;
  final VoltTrackPalette p;
  final Color? glowColor;
  final EdgeInsetsGeometry padding;

  const _BentoCard({
    required this.child,
    required this.p,
    this.glowColor,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDark;
    final isGlass = ThemeController.instance.isGlass;

    if (isGlass) {
      return Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: (glowColor ?? const Color(0xFF10B981)).withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );
    }

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: p.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.borderColor, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Mini AC Sine Wave Painter (50Hz AC electricity visualizer)
class _MiniSineWavePainter extends CustomPainter {
  final Color color;
  _MiniSineWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (double x = 0; x <= size.width; x += 1) {
      final y = size.height / 2 + math.sin((x / size.width) * 4 * math.pi) * (size.height * 0.38);
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniSineWavePainter oldDelegate) =>
      oldDelegate.color != color;
}
