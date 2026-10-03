import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'aura_living_orb.dart';
import '../theme/theme_controller.dart';
import 'motion_helpers.dart';

class AuraFloatingButton extends StatefulWidget {
  final VoidCallback onTap;
  final String? proactiveTip;

  /// Keparahan insight tip: info|warning|critical → warna titik.
  final String severity;

  /// Dipanggil saat tip (bukan orb) diketuk. Jika null, memakai onTap.
  final VoidCallback? onTipTap;

  const AuraFloatingButton({
    super.key,
    required this.onTap,
    this.proactiveTip,
    this.severity = 'info',
    this.onTipTap,
  });

  Color get _dotColor {
    switch (severity) {
      case 'critical':
        return const Color(0xFFEF4444);
      case 'warning':
        return const Color(0xFFFBBF24);
      default:
        return const Color(0xFF00F5D4);
    }
  }

  @override
  State<AuraFloatingButton> createState() => _AuraFloatingButtonState();
}

class _AuraFloatingButtonState extends State<AuraFloatingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(
      begin: -3.0,
      end: 3.0,
    ).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDark;

    return AnimatedBuilder(
      animation: _floatAnim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnim.value),
          child: child,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Proactive speech bubble hint positioned neatly above orb
          if (widget.proactiveTip != null && widget.proactiveTip!.isNotEmpty)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                (widget.onTipTap ?? widget.onTap)();
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                constraints: const BoxConstraints(maxWidth: 240),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xE6101726) // 90% obsidian
                      : const Color(0xF2FFFFFF), // 95% porcelain
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget._dotColor.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget._dotColor.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: widget._dotColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: widget._dotColor, blurRadius: 5),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        widget.proactiveTip!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFF1F5F9)
                              : const Color(0xFF0F172A),
                          letterSpacing: 0.02,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Glowing Floating Living Orb Trigger
          ScaleOnPress(
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onTap();
            },
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFF0D1829), Color(0xFF070B12)],
                ),
                border: Border.all(
                  color: const Color(0xFF00F5D4).withValues(alpha: 0.6),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00F5D4).withValues(alpha: 0.45),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: AuraLivingOrb(
                  size: 46,
                  state: AuraState.idle,
                  showParticles: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
