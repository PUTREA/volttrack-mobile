import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/theme_controller.dart';
import 'motion_helpers.dart';

enum InverterOperationMode {
  selfPower,
  backup100,
  arbitrage,
}

/// Operational Strategy & Inverter Hardware Diagnostics Widget
/// Dirender langsung sesuai spesifikasi Stitch AI UI Design System:
/// - 3 Tactile Mode Selector Buttons (Self-Power, Backup 100%, Arbitrage)
/// - Thermal Mapping Status Bar (Core Temp 34°C, MPPT Efficiency 98.6%, Cooling Fan 18%)
/// - Interactive Grid Isolation Switch & Diagnostic Logs Modal
class StitchOperationalStrategy extends StatefulWidget {
  final double inverterTemp;
  final double mpptEfficiency;
  final int fanSpeedPercent;
  final ValueChanged<InverterOperationMode>? onModeChanged;

  const StitchOperationalStrategy({
    super.key,
    this.inverterTemp = 34.0,
    this.mpptEfficiency = 98.6,
    this.fanSpeedPercent = 18,
    this.onModeChanged,
  });

  @override
  State<StitchOperationalStrategy> createState() => _StitchOperationalStrategyState();
}

class _StitchOperationalStrategyState extends State<StitchOperationalStrategy> {
  InverterOperationMode _selectedMode = InverterOperationMode.selfPower;

  void _selectMode(InverterOperationMode mode) {
    if (_selectedMode == mode) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedMode = mode);
    widget.onModeChanged?.call(mode);
  }

  void _showDiagnosticsModal(BuildContext context, VoltTrackPalette p) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: p.isDark ? const Color(0xFF12141B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: p.borderColor, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: p.neonTeal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.shield_outlined, color: p.neonTeal, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Grid Isolation & Proteksi',
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: p.textPrimary,
                            ),
                          ),
                          Text(
                            'Status Relai & Hardware Interlock',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: p.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: p.neonTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: p.neonTeal.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        color: p.neonTeal,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDiagRow(p, 'Anti-Islanding Relay', 'Terkunci Aman (IEC 62116)', p.neonTeal),
              _buildDiagRow(p, 'Ground Fault Detection', '0.0 mA (Impedansi Normal)', p.neonTeal),
              _buildDiagRow(p, 'Surge Protection Device', 'SPD Tipe II - Status Hijau', p.neonTeal),
              _buildDiagRow(p, 'ESP32 MQTT Link', '18ms Ping · 100% QoS 1', p.tertiaryCyan),
              _buildDiagRow(p, 'Firmware Version', 'VoltOS v2.4.1-rc3 (Secure Boot)', p.textSecondary),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text('Tutup Diagnostik', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.neonTeal,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiagRow(VoltTrackPalette p, String label, String value, Color valColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12.5, color: p.textSecondary)),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: valColor),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final isDark = ThemeController.instance.isDark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF12141B) : p.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.borderColor, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Operational Strategy',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.02,
                  color: p.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: p.neonTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: p.neonTeal.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 11, color: p.neonTeal),
                    const SizedBox(width: 4),
                    Text(
                      'AI Optimized',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: p.neonTeal,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3-Mode Selector Row (Stitch Layout)
          Row(
            children: [
              Expanded(
                child: _buildModeCard(
                  p: p,
                  mode: InverterOperationMode.selfPower,
                  title: 'Self-Power',
                  subtitle: 'Max Savings',
                  icon: Icons.eco_rounded,
                  accentColor: p.neonTeal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModeCard(
                  p: p,
                  mode: InverterOperationMode.backup100,
                  title: 'Backup 100%',
                  subtitle: 'Storm Guard',
                  icon: Icons.security_rounded,
                  accentColor: p.tertiaryCyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModeCard(
                  p: p,
                  mode: InverterOperationMode.arbitrage,
                  title: 'Arbitrage',
                  subtitle: 'Sell Peak Rate',
                  icon: Icons.currency_exchange_rounded,
                  accentColor: p.solarAmber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Inverter Hardware Core Diagnostics Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181B24) : p.cardElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: p.borderColor.withValues(alpha: 0.8),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                // Inverter Icon with status badge
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: p.neonTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.neonTeal.withValues(alpha: 0.3), width: 0.8),
                  ),
                  child: Center(
                    child: Icon(Icons.memory_rounded, color: p.neonTeal, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INVERTER CORE',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: p.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${widget.inverterTemp.toStringAsFixed(0)}°C',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: p.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '• Optimal',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: p.neonTeal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // MPPT Efficiency Column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'MPPT EFFICIENCY',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: p.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.mpptEfficiency.toStringAsFixed(1)}%',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: p.neonTeal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                // Fan status Column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'COOLING FAN',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: p.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Silent (${widget.fanSpeedPercent}%)',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Grid Isolation Switch CTA (Bottom pill button)
          ScaleOnPress(
            onTap: () => _showDiagnosticsModal(context, p),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161820) : p.cardElevated.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.borderColor.withValues(alpha: 0.6), width: 0.8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined, size: 14, color: p.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Grid Isolation Switch & Diagnostic Logs',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: p.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 15, color: p.textMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required VoltTrackPalette p,
    required InverterOperationMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    final isSelected = _selectedMode == mode;

    return ScaleOnPress(
      onTap: () => _selectMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.12)
              : (p.isDark ? const Color(0xFF161820) : p.cardElevated),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? accentColor : p.borderColor.withValues(alpha: 0.6),
            width: isSelected ? 1.4 : 0.8,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? accentColor : p.textMuted,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? p.textPrimary : p.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: isSelected ? accentColor : p.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
