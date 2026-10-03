import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/theme_controller.dart';
import 'motion_helpers.dart';

class VoltTrackNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isHero;

  const VoltTrackNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.isHero = false,
  });
}

class VoltTrackBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final List<VoltTrackNavItem> items;

  const VoltTrackBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final p = AppColors.of(context);
    final isDark = ThemeController.instance.isDark;

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        bottomPadding > 0 ? bottomPadding + 2 : 12,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.6)
                  : const Color(0xFF0F172A).withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              height: 68,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xE612141B) // 90% obsidian glass
                    : const Color(0xF2FFFFFF), // 95% frosted porcelain
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? const Color(0x24FFFFFF) // 14% white hairline
                      : const Color(0x18000000), // hairline gray
                  width: 0.8,
                ),
              ),
              child: Row(
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isSelected = selectedIndex == index;
                  final activeColor = isDark ? p.neonTeal : p.primaryTeal;

                  // Khusus tab hero (Live Monitor), berikan aksen energi yang lebih menonjol
                  final isHero = item.isHero;
                  final Color itemBg;
                  if (isSelected) {
                    if (isHero) {
                      itemBg = isDark
                          ? p.neonTeal.withValues(alpha: 0.20)
                          : p.primaryTeal.withValues(alpha: 0.14);
                    } else {
                      itemBg = isDark
                          ? const Color(0x1FFFFFFF)
                          : p.primaryTeal.withValues(alpha: 0.08);
                    }
                  } else {
                    itemBg = isHero
                        ? (isDark
                            ? p.neonTeal.withValues(alpha: 0.06)
                            : p.primaryTeal.withValues(alpha: 0.04))
                        : Colors.transparent;
                  }

                  return Expanded(
                    child: ScaleOnPress(
                      pressedScale: isHero ? 0.90 : 0.92,
                      onTap: () {
                        if (!isSelected) {
                          HapticFeedback.selectionClick();
                          onItemSelected(index);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: kEaseOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: itemBg,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: isSelected && isHero
                              ? [
                                  BoxShadow(
                                    color: p.neonTeal.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected ? item.activeIcon : item.icon,
                              size: isHero ? 22.5 : 20.5,
                              color: isSelected
                                  ? (isHero ? (isDark ? const Color(0xFF2DD4BF) : p.primaryTeal) : activeColor)
                                  : (isHero
                                      ? (isDark ? const Color(0xFF2DD4BF).withValues(alpha: 0.7) : p.primaryTeal.withValues(alpha: 0.7))
                                      : p.textMuted),
                            ),
                            const SizedBox(height: 2.5),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? (isDark ? Colors.white : p.textPrimary)
                                      : (isHero && isDark
                                          ? const Color(0xFF2DD4BF).withValues(alpha: 0.8)
                                          : p.textMuted),
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
