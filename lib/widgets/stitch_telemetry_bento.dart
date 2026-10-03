import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/theme_controller.dart';

/// 2x2 Telemetry Bento Grid Card
/// Dibuat presisi merujuk pada prototipe Google Stitch:
/// 1. Daily Yield (kWh + Sparkline + Persentase Naik)
/// 2. Monthly ROI (IDR + Target Progress Bar)
/// 3. Self-Reliance (% Autonomy + Circular Arc Indicator)
/// 4. CO₂ Offset (kg + Trees Saved Badge)
class StitchTelemetryBento extends StatelessWidget {
  final double dailyYieldKwh;
  final double yieldGrowthPercent;
  final int monthlyRoiIdr;
  final int monthlyTargetIdr;
  final double autonomyPercent;
  final double co2OffsetKg;
  final double treesEquivalent;
  final VoidCallback? onTap;

  const StitchTelemetryBento({
    super.key,
    this.dailyYieldKwh = 18.4,
    this.yieldGrowthPercent = 14.8,
    this.monthlyRoiIdr = 1450000,
    this.monthlyTargetIdr = 2000000,
    this.autonomyPercent = 92.0,
    this.co2OffsetKg = 14.2,
    this.treesEquivalent = 0.7,
    this.onTap,
  });

  String _formatIdrMillions(num idr) {
    if (idr >= 1000000) {
      final val = idr / 1000000.0;
      return '${val.toStringAsFixed(2).replaceAll('.00', '')}M';
    } else if (idr >= 1000) {
      final val = idr / 1000.0;
      return '${val.toStringAsFixed(0)}K';
    }
    return idr.toString();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final isDark = ThemeController.instance.isDark;

    return Column(
      children: [
        // Row 1: Daily Yield & Monthly ROI
        Row(
          children: [
            Expanded(
              child: _buildBentoCard(
                p: p,
                isDark: isDark,
                title: 'Daily Yield',
                valueText: dailyYieldKwh.toStringAsFixed(1),
                unitText: 'kWh',
                icon: Icons.wb_sunny_outlined,
                iconColor: p.solarAmber,
                footer: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Growth pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: p.neonTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.trending_up_rounded, size: 12, color: p.neonTeal),
                          const SizedBox(width: 3),
                          Text(
                            '+${yieldGrowthPercent.toStringAsFixed(1)}%',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: p.neonTeal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Mini sparkline graph
                    CustomPaint(
                      size: const Size(40, 16),
                      painter: _MiniSparklinePainter(color: p.solarAmber),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBentoCard(
                p: p,
                isDark: isDark,
                title: 'Monthly ROI',
                valueText: _formatIdrMillions(monthlyRoiIdr),
                unitText: 'IDR',
                icon: Icons.savings_outlined,
                iconColor: p.neonTeal,
                footer: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Target: ${_formatIdrMillions(monthlyTargetIdr)}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: p.textMuted,
                          ),
                        ),
                        Text(
                          '${((monthlyRoiIdr / (monthlyTargetIdr > 0 ? monthlyTargetIdr : 1)) * 100).clamp(0, 100).toInt()}%',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: p.neonTeal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (monthlyRoiIdr / (monthlyTargetIdr > 0 ? monthlyTargetIdr : 1)).clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: isDark ? const Color(0xFF232733) : p.borderColor,
                        valueColor: AlwaysStoppedAnimation<Color>(p.neonTeal),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 2: Self-Reliance & CO2 Offset
        Row(
          children: [
            Expanded(
              child: _buildBentoCard(
                p: p,
                isDark: isDark,
                title: 'Self-Reliance',
                valueText: '${autonomyPercent.toStringAsFixed(0)}%',
                unitText: 'Autonomy',
                icon: Icons.electric_bolt_rounded,
                iconColor: p.tertiaryCyan,
                footer: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Off-grid ready',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: p.textMuted,
                      ),
                    ),
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        value: (autonomyPercent / 100.0).clamp(0.0, 1.0),
                        strokeWidth: 3,
                        backgroundColor: isDark ? const Color(0xFF232733) : p.borderColor,
                        valueColor: AlwaysStoppedAnimation<Color>(p.tertiaryCyan),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBentoCard(
                p: p,
                isDark: isDark,
                title: 'CO₂ Offset',
                valueText: co2OffsetKg.toStringAsFixed(1),
                unitText: 'kg',
                icon: Icons.eco_outlined,
                iconColor: p.neonTeal,
                footer: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: p.neonTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: p.neonTeal.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.park_rounded, size: 12, color: p.neonTeal),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${treesEquivalent.toStringAsFixed(1)} Trees Saved',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: p.neonTeal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBentoCard({
    required VoltTrackPalette p,
    required bool isDark,
    required String title,
    required String valueText,
    required String unitText,
    required IconData icon,
    required Color iconColor,
    required Widget footer,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF12141B) : p.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.borderColor, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 14,
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
              Text(
                title,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: p.textSecondary,
                ),
              ),
              Icon(icon, size: 16, color: iconColor),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  valueText,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unitText,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: p.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          footer,
        ],
      ),
    );
  }
}

class _MiniSparklinePainter extends CustomPainter {
  final Color color;
  _MiniSparklinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.9,
      size.width * 0.5,
      size.height * 0.4,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.5,
      size.width,
      size.height * 0.1,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniSparklinePainter oldDelegate) => oldDelegate.color != color;
}
