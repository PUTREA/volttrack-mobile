import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Modern Energy Ring:
/// Cincin visualisasi energi melingkar (ala Apple Fitness & Tesla Energy)
/// Menampilkan produksi surya & kapasitas baterai secara instan & ramah bagi pengguna awam.
class ModernEnergyRing extends StatefulWidget {
  final double solarWatt;
  final double loadWatt;
  final double batterySoc;
  final String status;
  final double peakCapacityWatt;

  const ModernEnergyRing({
    super.key,
    required this.solarWatt,
    required this.loadWatt,
    required this.batterySoc,
    this.status = 'Normal',
    this.peakCapacityWatt = 3500.0,
  });

  @override
  State<ModernEnergyRing> createState() => _ModernEnergyRingState();
}

class _ModernEnergyRingState extends State<ModernEnergyRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _animValue;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animValue = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutCubic,
    );
    _animCtrl.forward();
  }

  @override
  void didUpdateWidget(covariant ModernEnergyRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.solarWatt != widget.solarWatt ||
        oldWidget.batterySoc != widget.batterySoc) {
      _animCtrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Menghitung rasio produksi surya terhadap kapasitas panel (0.0 .. 1.0)
    final solarRatio = (widget.solarWatt / widget.peakCapacityWatt).clamp(0.05, 1.0);
    final batteryRatio = (widget.batterySoc / 100.0).clamp(0.05, 1.0);
    final solarKw = widget.solarWatt >= 1000
        ? (widget.solarWatt / 1000.0).toStringAsFixed(1)
        : widget.solarWatt.toInt().toString();
    final solarUnit = widget.solarWatt >= 1000 ? 'kW' : 'W';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Status Badge Ringkas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF059669)),
                    SizedBox(width: 5),
                    Text(
                      'VoltTrack Smart Inverter: Aktif',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Efisiensi 98.2%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Lingkaran Progres Cincin Energi
          AnimatedBuilder(
            animation: _animValue,
            builder: (context, child) {
              return SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(220, 220),
                      painter: _EnergyRingPainter(
                        solarSweep: solarRatio * _animValue.value,
                        batterySweep: batteryRatio * _animValue.value,
                      ),
                    ),
                    // Teks Tengah Ring
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.solar_power_rounded,
                          size: 26,
                          color: Color(0xFF059669),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              solarKw,
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: -1.0,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              solarUnit,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'DAYA SURYA AKTIF',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Baterai: ${widget.batterySoc.toInt()}%',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 22),

          // Indikator Legenda 3 Metrik Sederhana
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _metricPill(
                icon: Icons.wb_sunny_rounded,
                iconColor: const Color(0xFF10B981),
                label: 'Surya',
                value: '${widget.solarWatt.toInt()} W',
              ),
              Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
              _metricPill(
                icon: Icons.battery_charging_full_rounded,
                iconColor: const Color(0xFFF59E0B),
                label: 'Baterai',
                value: '${widget.batterySoc.toInt()}%',
              ),
              Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
              _metricPill(
                icon: Icons.home_rounded,
                iconColor: const Color(0xFF2563EB),
                label: 'Pemakaian',
                value: '${widget.loadWatt.toInt()} W',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricPill({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

/// CustomPainter untuk Cincin Ganda:
/// - Cincin Luar (Radius besar): Surya (Emerald gradient)
/// - Cincin Dalam (Radius sedang): Baterai (Amber gradient)
class _EnergyRingPainter extends CustomPainter {
  final double solarSweep;
  final double batterySweep;

  _EnergyRingPainter({
    required this.solarSweep,
    required this.batterySweep,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = (size.width / 2) - 12;
    final innerRadius = outerRadius - 16;
    const startAngle = -math.pi / 2; // Mulai dari atas (pukul 12)

    // 1. Lintasan Background (Track lembut)
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFF1F5F9);

    final bgInnerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFF8FAFC);

    canvas.drawCircle(center, outerRadius, bgPaint);
    canvas.drawCircle(center, innerRadius, bgInnerPaint);

    // 2. Cincin Luar: Surya (Gradient Emerald -> Cyan)
    final solarRect = Rect.fromCircle(center: center, radius: outerRadius);
    final solarGradient = const SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      colors: [
        Color(0xFF34D399),
        Color(0xFF059669),
        Color(0xFF0D9488),
      ],
      stops: [0.0, 0.7, 1.0],
      transform: GradientRotation(-math.pi / 2),
    );

    final solarPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..shader = solarGradient.createShader(solarRect);

    final sweepAngleSolar = (math.pi * 2) * solarSweep.clamp(0.02, 0.999);
    canvas.drawArc(
      solarRect,
      startAngle,
      sweepAngleSolar,
      false,
      solarPaint,
    );

    // 3. Cincin Dalam: Baterai (Gradient Amber -> Orange)
    final batteryRect = Rect.fromCircle(center: center, radius: innerRadius);
    final batteryGradient = const SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      colors: [
        Color(0xFFFBBF24),
        Color(0xFFF59E0B),
        Color(0xFFD97706),
      ],
      stops: [0.0, 0.6, 1.0],
      transform: GradientRotation(-math.pi / 2),
    );

    final batteryPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..shader = batteryGradient.createShader(batteryRect);

    final sweepAngleBattery = (math.pi * 2) * batterySweep.clamp(0.02, 0.999);
    canvas.drawArc(
      batteryRect,
      startAngle,
      sweepAngleBattery,
      false,
      batteryPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _EnergyRingPainter oldDelegate) {
    return oldDelegate.solarSweep != solarSweep ||
        oldDelegate.batterySweep != batterySweep;
  }
}
