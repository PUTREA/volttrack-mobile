import 'dart:ui';
import 'package:flutter/material.dart';

import '../theme/theme_controller.dart';

/// Background Ambient Mesh dengan aura pendaran surya & teal dinamis.
/// Memberikan efek kedalaman visual (visual depth) yang membuat kartu frosted glass
/// terlihat hidup dan memukau ala Apple VisionOS & Tesla Energy.
class AmbientMeshBackground extends StatelessWidget {
  final Widget child;

  const AmbientMeshBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final isGlass = ThemeController.instance.isGlass;

    if (!isGlass && !p.isDark) {
      // Light Mode: latar bersih dengan gradasi sangat halus
      return Container(
        color: p.bg,
        child: child,
      );
    }

    return Container(
      color: p.bg,
      child: Stack(
        children: [
          // 1. Solar Amber Ambient Aura (Kiri Atas)
          Positioned(
            top: -60,
            left: -40,
            child: IgnorePointer(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      isGlass
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.22)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Emerald Teal Inverter Ambient Aura (Kanan Tengah)
          Positioned(
            top: 220,
            right: -60,
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      isGlass
                          ? const Color(0xFF10B981).withValues(alpha: 0.20)
                          : const Color(0xFF10B981).withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Electric Blue Grid/ESS Aura (Kiri Bawah)
          Positioned(
            top: 520,
            left: -50,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      isGlass
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.16)
                          : const Color(0xFF3B82F6).withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Lapisan Utama Konten
          child,
        ],
      ),
    );
  }
}

/// Kartu Kaca Berkinerja Tinggi (High-Performance Frosted Glass Card)
/// Memiliki efek specular highlight border (memantulkan cahaya dari sudut atas),
/// semi-translucent tint, dan subtle drop shadow.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? glowColor;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 22,
    this.glowColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final isGlass = ThemeController.instance.isGlass;
    final isDark = ThemeController.instance.isDark;

    if (!isGlass) {
      // Solid Modern Card untuk Mode Dark & Light reguler
      return Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: p.cardBg,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: p.borderColor, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );
    }

    // FROSTED GLASS THEME (Apple VisionOS / Cyberpunk Clean Solar)
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(borderRadius),
            // Specular border gradient: memantulkan cahaya di sudut kiri atas
            border: Border.all(
              color: const Color(0xFFFFFFFF).withValues(alpha: 0.22),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: (glowColor ?? const Color(0xFF10B981)).withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
