import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/theme_controller.dart';

/// Ikon Hardware Inverter Pintar (Chassis, Display LCD, Simbol Konversi Daya, & Terminal)
class InverterIconWidget extends StatelessWidget {
  final double size;
  final Color color;

  const InverterIconWidget({
    super.key,
    this.size = 28,
    this.color = const Color(0xFF0F766E),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _InverterIconPainter(color: color),
    );
  }
}

class _InverterIconPainter extends CustomPainter {
  final Color color;
  _InverterIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.08).clamp(1.5, 2.5)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 1. Chassis Inverter (Bodi persegi melengkung)
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.16, h * 0.10, w * 0.68, h * 0.76),
      Radius.circular(w * 0.18),
    );
    canvas.drawRRect(bodyRect, strokePaint);

    // 2. Layar LCD / IoT Monitor (Bagian atas)
    final lcdRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.30, h * 0.20, w * 0.40, h * 0.18),
      Radius.circular(w * 0.08),
    );
    canvas.drawRRect(lcdRect, fillPaint);

    // 3. Simbol Konversi Petir Arus Pintar
    final boltPath = Path()
      ..moveTo(w * 0.52, h * 0.44)
      ..lineTo(w * 0.42, h * 0.58)
      ..lineTo(w * 0.50, h * 0.58)
      ..lineTo(w * 0.46, h * 0.72)
      ..lineTo(w * 0.60, h * 0.54)
      ..lineTo(w * 0.52, h * 0.54)
      ..close();
    canvas.drawPath(boltPath, fillPaint);

    // 4. Terminal DC/AC di bagian bawah
    final terminalY1 = h * 0.86;
    final terminalY2 = h * 0.96;
    canvas.drawLine(Offset(w * 0.34, terminalY1), Offset(w * 0.34, terminalY2), strokePaint);
    canvas.drawLine(Offset(w * 0.50, terminalY1), Offset(w * 0.50, terminalY2), strokePaint);
    canvas.drawLine(Offset(w * 0.66, terminalY1), Offset(w * 0.66, terminalY2), strokePaint);
  }

  @override
  bool shouldRepaint(covariant _InverterIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Diagram Alir Energi Hidup (Live Energy Flow Hub)
/// Terinspirasi dari Dribbble, Tesla Energy, & EcoFlow Smart Home.
/// Menampilkan Inverter di pusat energi dengan 4 pod satelit taktil & kurva konduit bercahaya.
class EnergyFlowWidget extends StatefulWidget {
  final double solarWatt;
  final double loadWatt;
  final double batterySoc;
  final double gridWatt;
  final String status;
  final Map<String, dynamic>? reading;

  const EnergyFlowWidget({
    super.key,
    required this.solarWatt,
    required this.loadWatt,
    required this.batterySoc,
    this.gridWatt = 0.0,
    this.status = 'Normal',
    this.reading,
  });

  @override
  State<EnergyFlowWidget> createState() => _EnergyFlowWidgetState();
}

class _EnergyFlowWidgetState extends State<EnergyFlowWidget>
    with TickerProviderStateMixin {
  late AnimationController _flowAnim;
  late AnimationController _pulseAnim;

  @override
  void initState() {
    super.initState();
    // Animasi partikel mengalir di sepanjang pipa
    _flowAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    // Animasi denyut halus (breathing aura) pada inverter pusat
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _flowAnim.dispose();
    _pulseAnim.dispose();
    super.dispose();
  }

  String _formatKw(double watt) {
    if (watt >= 1000) {
      return '${(watt / 1000).toStringAsFixed(1)} kW';
    }
    return '${watt.toStringAsFixed(0)} W';
  }

  @override
  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final isDark = ThemeController.instance.isDark;

    const emerald = Color(0xFF10B981);
    const amber = Color(0xFFF59E0B);
    const blue = Color(0xFF3B82F6);
    const teal = Color(0xFF0D9488);

    final r = widget.reading;
    final pv = r?['pv'] as Map<String, dynamic>?;
    final grid = r?['grid'] as Map<String, dynamic>?;
    final bat = r?['battery'] as Map<String, dynamic>?;
    final inv = r?['inverter'] as Map<String, dynamic>?;
    final energy = r?['energy_accumulated'] as Map<String, dynamic>?;
    final savings = r?['savings'] as Map<String, dynamic>?;

    final solarWatt = double.tryParse(r?['power_watt']?.toString() ?? '') ?? widget.solarWatt;
    final loadWatt = double.tryParse(r?['load_watt']?.toString() ?? '') ?? widget.loadWatt;
    final batterySoc = double.tryParse(r?['battery_soc']?.toString() ?? '') ?? widget.batterySoc;

    final gridWatt = double.tryParse(grid?['power_watt']?.toString() ?? '') ?? widget.gridWatt;
    final gridMode = (grid?['mode'] ?? (solarWatt > loadWatt ? 'export' : 'import')).toString();
    final gridV = double.tryParse(grid?['voltage']?.toString() ?? '') ?? 222.4;
    final gridFreq = double.tryParse(grid?['frequency']?.toString() ?? '') ?? 50.0;

    final batWatt = double.tryParse(bat?['power_watt']?.toString() ?? '') ?? (solarWatt - loadWatt).abs();
    final batStatus = (bat?['status'] ?? (solarWatt > loadWatt ? 'Charging' : 'Discharging')).toString();
    final batV = double.tryParse(bat?['voltage']?.toString() ?? '') ?? 51.8;

    final invEfficiency = double.tryParse(inv?['efficiency']?.toString() ?? '') ?? 97.4;
    final invTemp = double.tryParse(inv?['temperature']?.toString() ?? '') ?? 38.5;

    final selfSufficiency = double.tryParse(energy?['self_sufficiency_rate']?.toString() ?? '') ??
        (loadWatt > 0 ? ((solarWatt / loadWatt) * 100).clamp(0, 100).toDouble() : 100.0);

    final todaySavedIdr = int.tryParse(savings?['today_saved_idr']?.toString() ?? '') ?? 21382;
    final isExporting = gridMode == 'export' || (solarWatt > loadWatt && gridMode != 'import');

    final pv1W = double.tryParse(pv?['pv1_power']?.toString() ?? '') ?? (solarWatt * 0.52);
    final pv2W = double.tryParse(pv?['pv2_power']?.toString() ?? '') ?? (solarWatt * 0.48);

    final solarKw = _formatKw(solarWatt);
    final loadKw = _formatKw(loadWatt);
    final gridKw = _formatKw(gridWatt.abs());
    final batKw = _formatKw(batWatt.abs());
    final autonomyPct = selfSufficiency.toStringAsFixed(1);
    final gridDelta = gridWatt.abs();

    final isGlass = ThemeController.instance.isGlass;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isGlass ? const Color(0xFF1E293B).withValues(alpha: 0.35) : p.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isGlass ? Colors.white.withValues(alpha: 0.22) : p.borderColor,
          width: isGlass ? 1.0 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.4) : const Color(0x060F172A),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
          if (isGlass)
            BoxShadow(
              color: emerald.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          // ==============================================================
          // 1. BANNER STATUS RAMAH AWAM (DEYE / GROWATT STYLE)
          // ==============================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: emerald,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: emerald.withValues(alpha: 0.5), blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Sistem Hybrid Berjalan Optimal',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: p.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isExporting
                ? 'Surplus ${gridWatt.toInt()}W diekspor ke PLN · Baterai $batStatus'
                : (gridWatt > 20
                    ? 'Beban disuplai Surya (${solarWatt.toInt()} W) + PLN (${gridWatt.toInt()} W)'
                    : 'Beban rumah 100% mandiri disuplai dari surya & baterai'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: p.textMuted,
            ),
          ),
          const SizedBox(height: 18),

          // ==============================================================
          // 2. KANVAS DIAGRAM ENERGI 5-SIMPUL (TINGGI 310PX LAPANG)
          // ==============================================================
          SizedBox(
            height: 310,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Lapisan Bawah: Canvas Jalur Konduit Cubic Bezier & Partikel Glowing
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _flowAnim,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _HubFlowCurvesPainter(
                          progress: _flowAnim.value,
                          isExporting: isExporting,
                          solarActive: solarWatt > 50,
                          batteryActive: batWatt > 10,
                          gridActive: gridDelta > 20,
                          isDark: isDark,
                        ),
                      );
                    },
                  ),
                ),

                // Pod 1: Matahari (Kiri Atas) - Growatt String PV1/PV2
                Positioned(
                  left: 2,
                  top: 6,
                  child: _buildEnergyPod(
                    context: context,
                    icon: Icons.wb_sunny_rounded,
                    label: 'Produksi Surya',
                    value: solarKw,
                    accentColor: amber,
                    iconBgColor: isDark ? const Color(0xFF2E2413) : const Color(0xFFFEF3C7),
                    borderColor: isDark ? const Color(0xFF785516) : const Color(0xFFFDE68A),
                    subtext: 'PV1 ${pv1W.toInt()}W · PV2 ${pv2W.toInt()}W',
                  ),
                ),

                // Pod 2: Beban Rumah (Kanan Atas)
                Positioned(
                  right: 2,
                  top: 6,
                  child: _buildEnergyPod(
                    context: context,
                    icon: Icons.home_rounded,
                    label: 'Beban Rumah',
                    value: loadKw,
                    accentColor: emerald,
                    iconBgColor: isDark ? const Color(0xFF13281E) : const Color(0xFFECFDF5),
                    borderColor: isDark ? const Color(0xFF195537) : const Color(0xFFA7F3D0),
                    alignRight: true,
                    subtext: 'Mandiri: $autonomyPct%',
                  ),
                ),

                // Pod 3: PUSAT HERO HARDWARE — VOLTTRACK SMART INVERTER
                Positioned(
                  left: 0,
                  right: 0,
                  top: 104,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (context, child) {
                        final pulse = _pulseAnim.value;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: p.cardElevated,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? emerald.withValues(alpha: 0.6) : emerald,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: emerald.withValues(alpha: isDark ? 0.15 : 0.08),
                                blurRadius: 12 + (6 * pulse),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: emerald.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: InverterIconWidget(
                                  size: 24,
                                  color: isDark ? Colors.white : emerald,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'VoltTrack Hybrid',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: p.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Efisiensi ${invEfficiency.toStringAsFixed(1)}% · ${invTemp.toStringAsFixed(0)}°C',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: emerald,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Pod 4: Baterai Cadangan (Kiri Bawah) - Deye BMS specs
                Positioned(
                  left: 2,
                  bottom: 6,
                  child: _buildEnergyPod(
                    context: context,
                    icon: Icons.battery_charging_full_rounded,
                    label: 'Baterai ESS',
                    value: '${batterySoc.toInt()}% · $batKw',
                    accentColor: teal,
                    iconBgColor: isDark ? const Color(0xFF132826) : const Color(0xFFF0FDFA),
                    borderColor: isDark ? const Color(0xFF185750) : const Color(0xFF99F6E4),
                    subtext: '${batV.toStringAsFixed(1)}V · $batStatus',
                  ),
                ),

                // Pod 5: Grid PLN (Kanan Bawah) - Import/Export with Voltage & Frequency
                Positioned(
                  right: 2,
                  bottom: 6,
                  child: _buildEnergyPod(
                    context: context,
                    icon: Icons.electric_bolt_rounded,
                    label: isExporting ? 'Ekspor ke PLN' : 'Impor PLN',
                    value: isExporting ? '+$gridKw' : gridKw,
                    accentColor: blue,
                    iconBgColor: isDark ? const Color(0xFF152238) : const Color(0xFFEFF6FF),
                    borderColor: isDark ? const Color(0xFF1C4278) : const Color(0xFFBFDBFE),
                    alignRight: true,
                    subtext: '${gridV.toStringAsFixed(0)}V · ${gridFreq.toStringAsFixed(0)}Hz',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ==============================================================
          // 3. FOOTER STRIP INFORMASI CEPAT (RAMAH AWAM & HEMAT PLN)
          // ==============================================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: p.cardElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.borderColor, width: 0.8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_rounded, size: 15, color: Color(0xFF10B981)),
                    const SizedBox(width: 5),
                    Text(
                      'Kemandirian: $autonomyPct%',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(width: 1, height: 16, color: p.borderColor),
                Row(
                  children: [
                    const Icon(Icons.savings_rounded, size: 15, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Text(
                      'Hemat: Rp ${_formatIdr(todaySavedIdr)}',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatIdr(int amount) {
    return amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  /// Membangun Kapsul Pod Energi Taktil (Rounded Modern Card)
  Widget _buildEnergyPod({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
    required Color iconBgColor,
    required Color borderColor,
    String? subtext,
    bool alignRight = false,
  }) {
    final p = AppColors.of(context);

    final podContent = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!alignRight) ...[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Center(
              child: Icon(icon, color: accentColor, size: 18),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Column(
          crossAxisAlignment:
              alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: p.textMuted,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            if (subtext != null) ...[
              Text(
                subtext,
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ],
          ],
        ),
        if (alignRight) ...[
          const SizedBox(width: 8),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Center(
              child: Icon(icon, color: accentColor, size: 18),
            ),
          ),
        ],
      ],
    );

    final isGlass = ThemeController.instance.isGlass;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isGlass ? Colors.white.withValues(alpha: 0.08) : p.cardElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGlass ? Colors.white.withValues(alpha: 0.25) : p.borderColor,
          width: isGlass ? 1.0 : 0.8,
        ),
        boxShadow: isGlass
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: podContent,
    );
  }
}

/// Custom Painter yang menggambar pipa konduit Cubic Bezier & Partikel Glowing
class _HubFlowCurvesPainter extends CustomPainter {
  final double progress;
  final bool isExporting;
  final bool solarActive;
  final bool batteryActive;
  final bool gridActive;
  final bool isDark;

  _HubFlowCurvesPainter({
    required this.progress,
    required this.isExporting,
    required this.solarActive,
    required this.batteryActive,
    required this.gridActive,
    this.isDark = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Titik Sambungan Port Pod Satelit
    final pSun = Offset(w * 0.28, h * 0.12);
    final pHome = Offset(w * 0.72, h * 0.12);
    final pBattery = Offset(w * 0.28, h * 0.88);
    final pGrid = Offset(w * 0.72, h * 0.88);

    // Titik Sambungan Port Inverter Pusat
    final pInvTL = Offset(w * 0.40, h * 0.44);
    final pInvTR = Offset(w * 0.60, h * 0.44);
    final pInvBL = Offset(w * 0.40, h * 0.56);
    final pInvBR = Offset(w * 0.60, h * 0.56);

    // Cat Lintasan Dasar (Pipa Halus)
    final trackPaint = Paint()
      ..color = isDark ? const Color(0xFF1E222D) : const Color(0xFFF1F5F9)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Cat Lintasan Aktif Tipis
    final activeLinePaint = Paint()
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // -------------------------------------------------------------
    // 1. Surya -> Inverter (Warm Amber)
    // -------------------------------------------------------------
    final pathSun = Path()
      ..moveTo(pSun.dx, pSun.dy)
      ..cubicTo(
        pSun.dx + (w * 0.08),
        pSun.dy + (h * 0.06),
        pInvTL.dx - (w * 0.06),
        pInvTL.dy - (h * 0.08),
        pInvTL.dx,
        pInvTL.dy,
      );
    canvas.drawPath(pathSun, trackPaint);
    if (solarActive) {
      activeLinePaint.color = const Color(0xFFFDE68A);
      canvas.drawPath(pathSun, activeLinePaint);
      _drawGlowingComet(
        canvas,
        pathSun,
        headColor: const Color(0xFFD97706),
        glowColor: const Color(0xFFF59E0B),
        t: progress,
        reverse: false,
      );
    }

    // -------------------------------------------------------------
    // 2. Inverter -> Rumah (Fresh Emerald)
    // -------------------------------------------------------------
    final pathHome = Path()
      ..moveTo(pInvTR.dx, pInvTR.dy)
      ..cubicTo(
        pInvTR.dx + (w * 0.06),
        pInvTR.dy - (h * 0.08),
        pHome.dx - (w * 0.08),
        pHome.dy + (h * 0.06),
        pHome.dx,
        pHome.dy,
      );
    canvas.drawPath(pathHome, trackPaint);
    activeLinePaint.color = const Color(0xFFA7F3D0);
    canvas.drawPath(pathHome, activeLinePaint);
    _drawGlowingComet(
      canvas,
      pathHome,
      headColor: const Color(0xFF059669),
      glowColor: const Color(0xFF10B981),
      t: progress,
      reverse: false,
    );

    // -------------------------------------------------------------
    // 3. Inverter <-> Baterai (Teal Cyan)
    // -------------------------------------------------------------
    final pathBattery = Path()
      ..moveTo(pInvBL.dx, pInvBL.dy)
      ..cubicTo(
        pInvBL.dx - (w * 0.06),
        pInvBL.dy + (h * 0.08),
        pBattery.dx + (w * 0.08),
        pBattery.dy - (h * 0.06),
        pBattery.dx,
        pBattery.dy,
      );
    canvas.drawPath(pathBattery, trackPaint);
    if (batteryActive) {
      activeLinePaint.color = const Color(0xFF99F6E4);
      canvas.drawPath(pathBattery, activeLinePaint);
      _drawGlowingComet(
        canvas,
        pathBattery,
        headColor: const Color(0xFF0F766E),
        glowColor: const Color(0xFF14B8A6),
        t: progress,
        reverse: false,
      );
    }

    // -------------------------------------------------------------
    // 4. Inverter <-> Grid PLN (Electric Blue)
    // -------------------------------------------------------------
    final pathGrid = Path()
      ..moveTo(pInvBR.dx, pInvBR.dy)
      ..cubicTo(
        pInvBR.dx + (w * 0.06),
        pInvBR.dy + (h * 0.08),
        pGrid.dx - (w * 0.08),
        pGrid.dy - (h * 0.06),
        pGrid.dx,
        pGrid.dy,
      );
    canvas.drawPath(pathGrid, trackPaint);
    if (gridActive) {
      activeLinePaint.color = const Color(0xFFBFDBFE);
      canvas.drawPath(pathGrid, activeLinePaint);
      _drawGlowingComet(
        canvas,
        pathGrid,
        headColor: const Color(0xFF1D4ED8),
        glowColor: const Color(0xFF3B82F6),
        t: progress,
        reverse: !isExporting, // Membalik arah jika impor dari PLN
      );
    }
  }

  /// Menggambar partikel energi bercahaya (Glowing Pulse)
  void _drawGlowingComet(
    Canvas canvas,
    Path path, {
    required Color headColor,
    required Color glowColor,
    required double t,
    bool reverse = false,
  }) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final len = metric.length;

    // 2 butir partikel mengalir bergantian per lintasan
    for (int i = 0; i < 2; i++) {
      double normT = (t + (i * 0.5)) % 1.0;
      if (reverse) normT = 1.0 - normT;

      final dist = normT * len;
      final tangent = metric.getTangentForOffset(dist);
      if (tangent == null) continue;

      final pos = tangent.position;

      // Pendaran luar (Glow halo)
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 7.0, glowPaint);

      // Inti partikel (Solid core)
      final corePaint = Paint()
        ..color = headColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 3.8, corePaint);
    }
  }

  @override
  bool shouldRepaint(_HubFlowCurvesPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.isExporting != isExporting ||
      oldDelegate.solarActive != solarActive;
}
