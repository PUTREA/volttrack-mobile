import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/theme_controller.dart';

/// Screen 2 Stitch Widget: Live Telemetry & MPPT Diagnostics
/// Mengimplementasikan tampilan teknis presisi tinggi:
/// 1. Grid AC Phase L1 (Tegangan, Frekuensi, Arus, Power Factor cos φ, Sine Wave)
/// 2. Dual-Channel MPPT Solar Array (PV1 & PV2 String V/A/kW + Peak MPPT Rating)
/// 3. LiFePO4 Storage Diagnostics (SOC Ring, Bus Voltage, Inflow Current, 16 Cell Balance)
/// 4. Hardware Core Thermal Mapping (Core, Transformer, MOSFET, Fan RPM)
class StitchMpptDiagnostics extends StatelessWidget {
  final double gridVoltage;
  final double gridFreq;
  final double gridCurrent;
  final double gridCosPhi;
  final double pv1Voltage;
  final double pv1Current;
  final double pv2Voltage;
  final double pv2Current;
  final double batterySoc;
  final double batteryVoltage;
  final double batteryCurrent;
  final double coreTemp;
  final double transformerTemp;
  final double mosfetTemp;
  final int fanSpeedPercent;

  const StitchMpptDiagnostics({
    super.key,
    this.gridVoltage = 228.4,
    this.gridFreq = 50.02,
    this.gridCurrent = 7.8,
    this.gridCosPhi = 0.99,
    this.pv1Voltage = 380.0,
    this.pv1Current = 8.2,
    this.pv2Voltage = 375.0,
    this.pv2Current = 8.1,
    this.batterySoc = 88.0,
    this.batteryVoltage = 52.4,
    this.batteryCurrent = 24.2,
    this.coreTemp = 34.0,
    this.transformerTemp = 41.0,
    this.mosfetTemp = 38.0,
    this.fanSpeedPercent = 18,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final isDark = ThemeController.instance.isDark;

    final pv1Kw = (pv1Voltage * pv1Current) / 1000.0;
    final pv2Kw = (pv2Voltage * pv2Current) / 1000.0;
    final totalPvKw = pv1Kw + pv2Kw;

    return Column(
      children: [
        // ─────────────────────────────────────────────────────────────
        // 1. GRID AC PHASE L1 CARD
        // ─────────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF12141B) : p.cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: p.borderColor, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                blurRadius: 16,
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: p.tertiaryCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.electrical_services_rounded, color: p.tertiaryCyan, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AC INGRESS',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: p.textMuted,
                            ),
                          ),
                          Text(
                            'Grid AC Phase L1',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: p.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: p.tertiaryCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: p.tertiaryCyan.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      '${gridFreq.toStringAsFixed(2)} Hz',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: p.tertiaryCyan,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    gridVoltage.toStringAsFixed(1),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'V',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: p.tertiaryCyan,
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('CURRENT', style: GoogleFonts.spaceGrotesk(fontSize: 8.5, fontWeight: FontWeight.w700, color: p.textMuted)),
                      Text('${gridCurrent.toStringAsFixed(1)} A', style: GoogleFonts.spaceGrotesk(fontSize: 13.5, fontWeight: FontWeight.w700, color: p.textPrimary)),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('COS φ', style: GoogleFonts.spaceGrotesk(fontSize: 8.5, fontWeight: FontWeight.w700, color: p.textMuted)),
                      Text(gridCosPhi.toStringAsFixed(2), style: GoogleFonts.spaceGrotesk(fontSize: 13.5, fontWeight: FontWeight.w700, color: p.neonTeal)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('THD: 1.2% Normal', style: GoogleFonts.inter(fontSize: 11, color: p.textMuted)),
                  CustomPaint(
                    size: const Size(90, 16),
                    painter: _SineWavePainter(color: p.tertiaryCyan),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ─────────────────────────────────────────────────────────────
        // 2. DUAL-CHANNEL SOLAR MPPT STRINGS CARD
        // ─────────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF12141B) : p.cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: p.borderColor, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                blurRadius: 16,
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: p.solarAmber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.wb_sunny_rounded, color: p.solarAmber, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DUAL-CHANNEL MPPT',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: p.solarAmber,
                            ),
                          ),
                          Text(
                            'Solar Array Strings',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: p.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${totalPvKw.toStringAsFixed(2)} kW',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: p.solarAmber,
                        ),
                      ),
                      Text(
                        '98.8% MPPT Peak',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: p.neonTeal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildStringBox(
                      p: p,
                      isDark: isDark,
                      label: 'PV STRING 1',
                      kw: pv1Kw,
                      voltage: pv1Voltage,
                      current: pv1Current,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStringBox(
                      p: p,
                      isDark: isDark,
                      label: 'PV STRING 2',
                      kw: pv2Kw,
                      voltage: pv2Voltage,
                      current: pv2Current,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ─────────────────────────────────────────────────────────────
        // 3. LIFEPO4 STORAGE DIAGNOSTICS CARD
        // ─────────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF12141B) : p.cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: p.borderColor, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                blurRadius: 16,
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: p.neonTeal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.battery_charging_full_rounded, color: p.neonTeal, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'STORAGE TELEMETRY',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: p.neonTeal,
                            ),
                          ),
                          Text(
                            'LiFePO4 Pack Diagnostics',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: p.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: p.neonTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: p.neonTeal.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      'Charging',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: p.neonTeal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  // Circular Radial SOC Indicator
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: CircularProgressIndicator(
                          value: (batterySoc / 100.0).clamp(0.0, 1.0),
                          strokeWidth: 6,
                          backgroundColor: isDark ? const Color(0xFF232733) : p.borderColor,
                          valueColor: AlwaysStoppedAnimation<Color>(p.neonTeal),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${batterySoc.toInt()}%',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: p.textPrimary,
                            ),
                          ),
                          Text(
                            'SOC',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: p.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  // Metrics column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMetricRow('BUS VOLTAGE', '${batteryVoltage.toStringAsFixed(1)} V', p),
                        const SizedBox(height: 6),
                        _buildMetricRow('INFLOW CURRENT', '+${batteryCurrent.toStringAsFixed(1)} A', p, valColor: p.neonTeal),
                        const SizedBox(height: 6),
                        _buildMetricRow('PACK TEMP', '27.5 °C', p),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // 16-cell balance status pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161820) : p.cardElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: p.borderColor.withValues(alpha: 0.6), width: 0.8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '16 Cell Balance: All Nominal',
                      style: GoogleFonts.inter(fontSize: 11, color: p.textSecondary),
                    ),
                    Text(
                      'Δ 12mV (Balanced)',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: p.neonTeal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ─────────────────────────────────────────────────────────────
        // 4. HARDWARE CORE THERMAL MAPPING CARD
        // ─────────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF12141B) : p.cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: p.borderColor, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                blurRadius: 16,
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: p.neonTeal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.thermostat_rounded, color: p.neonTeal, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Hardware Core Thermal Mapping',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: p.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: p.neonTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('4 SENSORS', style: GoogleFonts.spaceGrotesk(fontSize: 8.5, fontWeight: FontWeight.w700, color: p.neonTeal)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 4 sensor 2x2 grid
              Row(
                children: [
                  Expanded(
                    child: _buildThermalTile(p, isDark, 'INVERTER CORE', '${coreTemp.toInt()}°C', 'Normal', p.neonTeal),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildThermalTile(p, isDark, 'HF TRANSFORMER', '${transformerTemp.toInt()}°C', 'Optimal', p.solarAmber),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildThermalTile(p, isDark, 'MOSFET ARRAY', '${mosfetTemp.toInt()}°C', 'Good', p.neonTeal),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildThermalTile(p, isDark, 'COOLING FAN', '$fanSpeedPercent%', '~620 RPM', p.tertiaryCyan),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Threshold bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Thermal Ceiling Load', style: GoogleFonts.inter(fontSize: 10.5, color: p.textMuted)),
                      Text('Max 75°C Threshold', style: GoogleFonts.spaceGrotesk(fontSize: 10.5, fontWeight: FontWeight.w600, color: p.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (coreTemp / 75.0).clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: isDark ? const Color(0xFF232733) : p.borderColor,
                      valueColor: AlwaysStoppedAnimation<Color>(p.neonTeal),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value, VoltTrackPalette p, {Color? valColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(fontSize: 9.5, fontWeight: FontWeight.w600, color: p.textMuted),
        ),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valColor ?? p.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildStringBox({
    required VoltTrackPalette p,
    required bool isDark,
    required String label,
    required double kw,
    required double voltage,
    required double current,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161820) : p.cardElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.borderColor.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 9.5, fontWeight: FontWeight.w700, color: p.solarAmber)),
              Icon(Icons.bolt, size: 12, color: p.solarAmber),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${kw.toStringAsFixed(2)} kW',
            style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700, color: p.textPrimary),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${voltage.toInt()} V', style: GoogleFonts.inter(fontSize: 10.5, color: p.textMuted)),
              Text('${current.toStringAsFixed(1)} A', style: GoogleFonts.inter(fontSize: 10.5, color: p.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThermalTile(
    VoltTrackPalette p,
    bool isDark,
    String label,
    String value,
    String status,
    Color statusColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161820) : p.cardElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.borderColor.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(fontSize: 8.5, fontWeight: FontWeight.w700, color: p.textMuted),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: p.textPrimary),
              ),
              Text(
                status,
                style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: statusColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SineWavePainter extends CustomPainter {
  final Color color;
  _SineWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
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
  bool shouldRepaint(covariant _SineWavePainter oldDelegate) => oldDelegate.color != color;
}
