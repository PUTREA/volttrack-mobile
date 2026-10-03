import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Empat kondisi hidup Living Orb
enum AuraState {
  idle, // Bernapas santai, partikel melayang tenang
  listening, // Bereaksi saat user mengetik, riak memancar
  thinking, // Pusaran kuantum berotasi cepat, cyan-amber vortex
  speaking, // Gelombang frekuensi dinamis teratur saat merespons
}

class AuraLivingOrb extends StatefulWidget {
  final double size;
  final AuraState state;
  final VoidCallback? onTap;
  final bool showParticles;

  /// Amplitudo suara real-time 0..1 (dari mic) untuk animasi listening reaktif
  /// ala Siri. 0 = diam. Hanya berpengaruh saat state == listening.
  final double amplitude;

  const AuraLivingOrb({
    super.key,
    this.size = 120,
    this.state = AuraState.idle,
    this.onTap,
    this.showParticles = true,
    this.amplitude = 0.0,
  });

  @override
  State<AuraLivingOrb> createState() => _AuraLivingOrbState();
}

class _AuraLivingOrbState extends State<AuraLivingOrb>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _rotateCtrl;
  late final AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    // 1. Controller denyut pernapasan (Breathing)
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // 2. Controller rotasi pusaran energi (Vortex)
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();

    // 3. Controller gelombang bicara/dengar (waveform) — cepat & kontinu.
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();

    _smoothAmp = widget.amplitude;
  }

  // Amplitudo yang dihaluskan agar gelombang tidak patah-patah.
  double _smoothAmp = 0.0;

  @override
  void didUpdateWidget(covariant AuraLivingOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Haluskan amplitudo (low-pass) tiap frame data baru.
    _smoothAmp = _smoothAmp + (widget.amplitude - _smoothAmp) * 0.35;
    if (oldWidget.state != widget.state) {
      switch (widget.state) {
        case AuraState.idle:
          _pulseCtrl.duration = const Duration(milliseconds: 2400);
          _rotateCtrl.duration = const Duration(milliseconds: 6000);
          _waveCtrl.duration = const Duration(milliseconds: 800);
          if (!_pulseCtrl.isAnimating) _pulseCtrl.repeat(reverse: true);
          break;
        case AuraState.listening:
          _pulseCtrl.duration = const Duration(milliseconds: 1200);
          _rotateCtrl.duration = const Duration(milliseconds: 3500);
          _waveCtrl.duration = const Duration(
            milliseconds: 600,
          ); // waveform lincah
          if (!_waveCtrl.isAnimating) _waveCtrl.repeat();
          break;
        case AuraState.thinking:
          _pulseCtrl.duration = const Duration(milliseconds: 800);
          _rotateCtrl.duration = const Duration(milliseconds: 1200); // Cepat
          break;
        case AuraState.speaking:
          _pulseCtrl.duration = const Duration(milliseconds: 1100);
          _rotateCtrl.duration = const Duration(milliseconds: 2800);
          _waveCtrl.duration = const Duration(milliseconds: 700);
          break;
      }
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseCtrl, _rotateCtrl, _waveCtrl]),
          builder: (context, _) {
            return CustomPaint(
              painter: _AuraOrbPainter(
                pulseVal: _pulseCtrl.value,
                rotateVal: _rotateCtrl.value,
                waveVal: _waveCtrl.value,
                amplitude: _smoothAmp,
                state: widget.state,
                showParticles: widget.showParticles,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AuraOrbPainter extends CustomPainter {
  final double pulseVal;
  final double rotateVal;
  final double waveVal;
  final double amplitude;
  final AuraState state;
  final bool showParticles;

  _AuraOrbPainter({
    required this.pulseVal,
    required this.rotateVal,
    required this.waveVal,
    required this.amplitude,
    required this.state,
    required this.showParticles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.30;

    // Palette warna energetik VoltTrack
    const primaryCyan = Color(0xFF00F5D4);
    const vibrantTeal = Color(0xFF14F0D0);
    const solarAmber = Color(0xFFFBBF24);
    const deepObsidian = Color(0xFF070B12);
    const quantumPurple = Color(0xFF8B5CF6);

    // Modifikasi radius berdasarkan state
    double radiusScale = 1.0;
    if (state == AuraState.idle) {
      radiusScale = 0.95 + pulseVal * 0.08;
    } else if (state == AuraState.listening) {
      // Inti ikut membesar sesuai amplitudo suara (reaktif ala Siri).
      radiusScale = 0.96 + pulseVal * 0.06 + amplitude * 0.22;
    } else if (state == AuraState.thinking) {
      radiusScale = 0.92 + math.sin(rotateVal * math.pi * 4) * 0.08;
    } else if (state == AuraState.speaking) {
      radiusScale = 0.96 + waveVal * 0.15;
    }

    final currentRadius = baseRadius * radiusScale;

    // 1. LAPISAN LUAR: Ambient Halo & Chromatic Glow
    final haloRadius = size.width * (0.42 + pulseVal * 0.06);
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (state == AuraState.thinking ? quantumPurple : primaryCyan)
              .withValues(alpha: 0.38),
          (state == AuraState.thinking ? vibrantTeal : solarAmber).withValues(
            alpha: 0.18,
          ),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: haloRadius));
    canvas.drawCircle(center, haloRadius, haloPaint);

    // 2. LAPISAN TENGAH: Harmonik Wave Rings (Pusaran & Riak)
    final ringCount = state == AuraState.thinking ? 4 : 3;
    for (int i = 0; i < ringCount; i++) {
      final ringPhase = (rotateVal * 2 * math.pi) + (i * math.pi / 2);
      final ringDist = currentRadius * (1.15 + (i * 0.16) + (pulseVal * 0.08));

      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = (i % 2 == 0 ? primaryCyan : solarAmber).withValues(
          alpha: 0.45 - (i * 0.12),
        );

      final path = Path();
      const points = 60;
      for (int p = 0; p <= points; p++) {
        final angle = (p / points) * 2 * math.pi;
        final waveOffset =
            math.sin(angle * 3 + ringPhase) * (currentRadius * 0.06);
        final r = ringDist + waveOffset;
        final x = center.dx + r * math.cos(angle);
        final y = center.dy + r * math.sin(angle);
        if (p == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, ringPaint);
    }

    // 3. LAPISAN INTI (Core Sphere): Iridescent Radial Gradient
    final coreGradient = RadialGradient(
      center: Alignment(
        math.cos(rotateVal * 2 * math.pi) * 0.35,
        math.sin(rotateVal * 2 * math.pi) * 0.35,
      ),
      colors: state == AuraState.thinking
          ? [
              const Color(0xFFF3E8FF),
              const Color(0xFFC084FC),
              quantumPurple,
              vibrantTeal,
              deepObsidian,
            ]
          : [
              Colors.white,
              primaryCyan,
              vibrantTeal,
              state == AuraState.speaking
                  ? solarAmber
                  : const Color(0xFF0F766E),
              deepObsidian,
            ],
      stops: const [0.0, 0.25, 0.55, 0.85, 1.0],
    );

    final corePaint = Paint()
      ..shader = coreGradient.createShader(
        Rect.fromCircle(center: center, radius: currentRadius),
      );

    canvas.drawCircle(center, currentRadius, corePaint);

    // 3b. SIRI-STYLE LISTENING WAVEFORM — gelombang cair reaktif saat mendengar.
    if (state == AuraState.listening) {
      // Amplitudo efektif: selalu ada denyut halus + dorongan dari suara nyata.
      final amp = 0.12 + amplitude * 0.88;
      final wavePhase = waveVal * 2 * math.pi;
      // Tiga lapis gelombang dengan frekuensi & arah berbeda (liquid feel).
      final layers = [
        [3.0, 1.0, primaryCyan, 0.55],
        [5.0, -1.6, vibrantTeal, 0.40],
        [2.0, 1.9, Colors.white, 0.30],
      ];
      for (final layer in layers) {
        final freq = layer[0] as double;
        final speed = layer[1] as double;
        final col = layer[2] as Color;
        final op = layer[3] as double;
        final wavePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = col.withValues(alpha: op * (0.5 + amp * 0.5));

        final path = Path();
        const points = 90;
        final baseR = currentRadius * 1.02;
        for (int p = 0; p <= points; p++) {
          final angle = (p / points) * 2 * math.pi;
          // Jumlah beberapa sinus → bentuk gelombang organik seperti Siri.
          final wobble =
              math.sin(angle * freq + wavePhase * speed) *
                  (currentRadius * 0.10 * amp) +
              math.sin(angle * (freq + 2) - wavePhase * speed * 0.7) *
                  (currentRadius * 0.05 * amp);
          final r = baseR + wobble;
          final x = center.dx + r * math.cos(angle);
          final y = center.dy + r * math.sin(angle);
          if (p == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, wavePaint);
      }
    }

    // 4. KILAU BIASAN CAHAYA (Specular Highlight Ring)
    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = LinearGradient(
        begin: Alignment(
          math.cos(rotateVal * 2 * math.pi),
          math.sin(rotateVal * 2 * math.pi),
        ),
        end: Alignment(
          -math.cos(rotateVal * 2 * math.pi),
          -math.sin(rotateVal * 2 * math.pi),
        ),
        colors: [
          Colors.white.withValues(alpha: 0.85),
          primaryCyan.withValues(alpha: 0.5),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: currentRadius));

    canvas.drawCircle(center, currentRadius - 1.0, highlightPaint);

    // 5. PARTIKEL FOTON (Orbiting Energy Sparks)
    if (showParticles) {
      final particleCount = state == AuraState.thinking ? 12 : 7;
      final particlePaint = Paint()..style = PaintingStyle.fill;

      for (int i = 0; i < particleCount; i++) {
        final pAngle =
            (rotateVal * 2 * math.pi * (i % 2 == 0 ? 1 : -1)) +
            (i * (2 * math.pi / particleCount));
        final pDist = currentRadius * (1.1 + (i % 3) * 0.18 + pulseVal * 0.1);
        final pX = center.dx + pDist * math.cos(pAngle);
        final pY = center.dy + pDist * math.sin(pAngle);
        final pSize = 1.4 + (i % 3) * 0.8;

        particlePaint.color = (i % 2 == 0 ? primaryCyan : solarAmber)
            .withValues(alpha: 0.75 - (i % 3) * 0.15);
        canvas.drawCircle(Offset(pX, pY), pSize, particlePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AuraOrbPainter oldDelegate) {
    return oldDelegate.pulseVal != pulseVal ||
        oldDelegate.rotateVal != rotateVal ||
        oldDelegate.waveVal != waveVal ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.state != state;
  }
}
