import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/theme_controller.dart';
import 'motion_helpers.dart';

/// Jenis nodus yang dapat diinspeksi pada Smart Solar House
enum SolarHouseNode {
  solar,
  inverter,
  home,
  battery,
  grid,
}

/// Widget 3D Smart Solar House (Rumah PLTS Isometrik Interaktif)
/// Menampilkan model arsitektur 3D rumah modern dengan atap panel surya,
/// unit inverter pintar di dinding luar, pencahayaan beban interior,
/// modul baterai LiFePO4 di garasi, dan tiang jaringan transmisi PLN.
class SmartSolarHouse3D extends StatefulWidget {
  final double solarWatt;
  final double loadWatt;
  final double batterySoc;
  final double batteryWatt;
  final double gridWatt;
  final VoidCallback? onSwitchToOrbit;
  final ValueChanged<SolarHouseNode>? onNodeSelected;

  const SmartSolarHouse3D({
    super.key,
    this.solarWatt = 3850,
    this.loadWatt = 1420,
    this.batterySoc = 88.0,
    this.batteryWatt = 600,
    this.gridWatt = -1830, // Negatif = Ekspor ke PLN
    this.onSwitchToOrbit,
    this.onNodeSelected,
  });

  @override
  State<SmartSolarHouse3D> createState() => _SmartSolarHouse3DState();
}

class _SmartSolarHouse3DState extends State<SmartSolarHouse3D>
    with TickerProviderStateMixin {
  late AnimationController _flowController;
  late AnimationController _pulseController;
  SolarHouseNode? _selectedNode;

  @override
  void initState() {
    super.initState();
    // Animasi partikel konduit energi mengalir terus-menerus
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // Animasi denyut halus radiasi matahari dan status LED inverter
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _flowController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleNodeTap(SolarHouseNode node) {
    HapticFeedback.selectionClick();
    setState(() => _selectedNode = node);
    widget.onNodeSelected?.call(node);
    _showNodeDetailsModal(node);
  }

  void _showNodeDetailsModal(SolarHouseNode node) {
    final p = AppColors.of(context);
    final isDark = ThemeController.instance.isDark;

    String title;
    String badge;
    Color accentColor;
    IconData icon;
    List<Map<String, String>> metrics;

    switch (node) {
      case SolarHouseNode.solar:
        title = 'Atap Surya Monokristalin';
        badge = 'PHOTOVOLTAIC ARRAY';
        accentColor = const Color(0xFFF59E0B);
        icon = Icons.solar_power_rounded;
        metrics = [
          {'label': 'Daya Real-time', 'val': '${(widget.solarWatt / 1000).toStringAsFixed(2)} kW'},
          {'label': 'Iradiasi Surya', 'val': '842 W/m²'},
          {'label': 'String PV 1', 'val': '380V • 5.1A'},
          {'label': 'String PV 2', 'val': '375V • 5.0A'},
          {'label': 'Suhu Modul', 'val': '42.8°C'},
          {'label': 'Efisiensi Sel', 'val': '22.6% Tier-1'},
        ];
        break;
      case SolarHouseNode.inverter:
        title = 'VoltTrack Hybrid Inverter';
        badge = 'POWER CONVERSION CORE';
        accentColor = const Color(0xFF10B981);
        icon = Icons.memory_rounded;
        metrics = [
          {'label': 'Status Operasi', 'val': 'Online • Grid Tie'},
          {'label': 'Efisiensi MPPT', 'val': '98.8% Dual'},
          {'label': 'Suhu Heat Sink', 'val': '34.2°C (Optimal)'},
          {'label': 'Protokol IoT', 'val': 'ESP32 MQTT/TLS'},
          {'label': 'Kecepatan Fan', 'val': '18% Silent'},
          {'label': 'Total Harmonik (THD)', 'val': '1.2% Pure Sine'},
        ];
        break;
      case SolarHouseNode.home:
        title = 'Beban Konsumsi Rumah';
        badge = 'ACTIVE HOUSEHOLD LOAD';
        accentColor = const Color(0xFF8B5CF6);
        icon = Icons.home_rounded;
        metrics = [
          {'label': 'Beban Saat Ini', 'val': '${(widget.loadWatt / 1000).toStringAsFixed(2)} kW'},
          {'label': 'Beban Puncak Hari Ini', 'val': '2.65 kW'},
          {'label': 'Tegangan AC Rumah', 'val': '228.4 V'},
          {'label': 'Frekuensi AC', 'val': '50.02 Hz'},
          {'label': 'Kontribusi Surya', 'val': '100% Mandiri'},
          {'label': 'Peralatan Prioritas', 'val': 'HVAC & Refrigerator'},
        ];
        break;
      case SolarHouseNode.battery:
        title = 'Baterai Penyimpan LiFePO4';
        badge = 'ENERGY STORAGE SYSTEM';
        accentColor = const Color(0xFF06B6D4);
        icon = Icons.battery_charging_full_rounded;
        metrics = [
          {'label': 'State of Charge (SOC)', 'val': '${widget.batterySoc.toStringAsFixed(1)}%'},
          {'label': 'Status Pengisian', 'val': '+${widget.batteryWatt.toStringAsFixed(0)} W (Charging)'},
          {'label': 'Tegangan Bus Pack', 'val': '52.4 V'},
          {'label': 'Arus Charging', 'val': '+24.2 A'},
          {'label': 'Kapasitas Tersisa', 'val': '11.8 kWh / 13.5 kWh'},
          {'label': 'Kesehatan Baterai (SOH)', 'val': '99.4% (16-Cell Bal)'},
        ];
        break;
      case SolarHouseNode.grid:
        final isExport = widget.gridWatt <= 0;
        title = 'Jaringan Distribusi PLN';
        badge = 'GRID INTERCONNECTION';
        accentColor = isExport ? const Color(0xFF10B981) : const Color(0xFFEF4444);
        icon = Icons.electrical_services_rounded;
        metrics = [
          {'label': 'Aliran Daya PLN', 'val': isExport ? '${(widget.gridWatt.abs() / 1000).toStringAsFixed(2)} kW (Ekspor)' : '${(widget.gridWatt / 1000).toStringAsFixed(2)} kW (Impor)'},
          {'label': 'Tipe Meteran', 'val': 'Net Metering EXIM'},
          {'label': 'Tarif Resmi', 'val': 'Rp 1.444,70 / kWh'},
          {'label': 'Kredit Ekspor Hari Ini', 'val': 'Rp 26.400,-'},
          {'label': 'Status Grid Interlock', 'val': 'Tersinkronisasi'},
          {'label': 'Faktor Daya (cos φ)', 'val': '0.99 Lead'},
        ];
        break;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13151D) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: p.borderColor, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
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
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(icon, color: accentColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        badge,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: p.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: Icon(Icons.close_rounded, size: 20, color: p.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Grid 2 kolom data teknis
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.3,
              ),
              itemCount: metrics.length,
              itemBuilder: (ctx, i) {
                final m = metrics[i];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF191D28) : p.cardElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.borderColor, width: 0.6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        m['label']!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: p.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        m['val']!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: p.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final isDark = ThemeController.instance.isDark;
    final isGlass = ThemeController.instance.isGlass;

    Widget cardBody = Container(
      decoration: BoxDecoration(
        color: isGlass
            ? Colors.white.withValues(alpha: 0.05)
            : (isDark ? const Color(0xFF10131E) : Colors.white),
        borderRadius: BorderRadius.circular(24),
        border: null, // Tanpa border sesuai permintaan pengguna
        boxShadow: [
          if (isDark && !isGlass)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 26,
              offset: const Offset(0, 8),
            )
          else if (!isDark) ...[
            BoxShadow(
              color: const Color(0xFF64748B).withValues(alpha: 0.08),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: const Color(0xFFE2E8F0).withValues(alpha: 0.50),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] else // isGlass
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Card & Mode Switcher ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: p.solarAmber.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.home_work_rounded, color: p.solarAmber, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SMART SOLAR RESIDENCE',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: p.solarAmber,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Aliran Energi Rumah 3D',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: p.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Toggle pill to Live Orbit
                ScaleOnPress(
                  onTap: widget.onSwitchToOrbit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isGlass
                          ? Colors.white.withValues(alpha: 0.08)
                          : (isDark ? const Color(0xFF1B2030) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(999),
                      border: null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.hub_outlined, size: 12, color: p.neonTeal),
                        const SizedBox(width: 4),
                        Text(
                          'Orbit Mode',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: p.neonTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Canvas Visualisasi 3D Rumah PLTS ─────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: null, // Tanpa border pada viewport 3D
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isGlass
                      ? [
                          Colors.white.withValues(alpha: 0.05),
                          Colors.white.withValues(alpha: 0.02),
                        ]
                      : (isDark
                          ? const [
                              Color(0xFF090B12),
                              Color(0xFF0E111C),
                            ]
                          : const [
                              Color(0xFFF0F9FF),
                              Color(0xFFF1F5F9),
                            ]),
                ),
              ),
              child: Stack(
                children: [
                  // Animated Custom Painter
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_flowController, _pulseController]),
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _SmartSolarHousePainter(
                            flowProgress: _flowController.value,
                            pulseValue: _pulseController.value,
                            isDark: isDark, // Responsif terhadap Mode Terang / Gelap
                            solarWatt: widget.solarWatt,
                            loadWatt: widget.loadWatt,
                            batterySoc: widget.batterySoc,
                            gridWatt: widget.gridWatt,
                            selectedNode: _selectedNode,
                          ),
                        );
                      },
                    ),
                  ),

                  // Floating Interactive Node Badges (Tappable hot-spots)
                  // 1. Atap Surya (Top Center Left)
                  Positioned(
                    top: 22,
                    left: 32,
                    child: _buildNodeBadge(
                      label: 'PLTS ${(widget.solarWatt / 1000).toStringAsFixed(1)} kW',
                      icon: Icons.solar_power_rounded,
                      color: p.solarAmber,
                      node: SolarHouseNode.solar,
                      isDark: isDark,
                      isGlass: isGlass,
                    ),
                  ),

                  // 2. Inverter Pintar (Center Wallmount)
                  Positioned(
                    top: 104,
                    left: 14,
                    child: _buildNodeBadge(
                      label: 'Inverter 98.8%',
                      icon: Icons.memory_rounded,
                      color: p.neonTeal,
                      node: SolarHouseNode.inverter,
                      isDark: isDark,
                      isGlass: isGlass,
                    ),
                  ),

                  // 3. Beban Rumah (Center Interior)
                  Positioned(
                    top: 100,
                    right: 36,
                    child: _buildNodeBadge(
                      label: 'Rumah ${(widget.loadWatt / 1000).toStringAsFixed(1)} kW',
                      icon: Icons.home_rounded,
                      color: const Color(0xFF8B5CF6),
                      node: SolarHouseNode.home,
                      isDark: isDark,
                      isGlass: isGlass,
                    ),
                  ),

                  // 4. Baterai LiFePO4 (Bottom Left Utility Bay)
                  Positioned(
                    bottom: 18,
                    left: 24,
                    child: _buildNodeBadge(
                      label: 'LiFePO4 ${widget.batterySoc.toStringAsFixed(0)}%',
                      icon: Icons.battery_charging_full_rounded,
                      color: const Color(0xFF06B6D4),
                      node: SolarHouseNode.battery,
                      isDark: isDark,
                      isGlass: isGlass,
                    ),
                  ),

                  // 5. Tiang Grid PLN (Right Outdoor)
                  Positioned(
                    bottom: 22,
                    right: 16,
                    child: _buildNodeBadge(
                      label: widget.gridWatt <= 0
                          ? 'Ekspor ${(widget.gridWatt.abs() / 1000).toStringAsFixed(1)} kW'
                          : 'Impor ${(widget.gridWatt / 1000).toStringAsFixed(1)} kW',
                      icon: Icons.electrical_services_rounded,
                      color: widget.gridWatt <= 0 ? p.neonTeal : const Color(0xFFEF4444),
                      node: SolarHouseNode.grid,
                      isDark: isDark,
                      isGlass: isGlass,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Quick Summary Strip di Bawah Rumah ────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isGlass
                    ? Colors.white.withValues(alpha: 0.05)
                    : (isDark ? const Color(0xFF161925) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(14),
                border: null, // Tanpa border pada strip ringkasan
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: p.neonTeal,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: p.neonTeal.withValues(alpha: 0.8),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Kemandirian: 92% • Surplus Daya',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: p.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Ketuk elemen untuk info',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: p.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (isGlass) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: cardBody,
        ),
      );
    }

    return cardBody;
  }

  Widget _buildNodeBadge({
    required String label,
    required IconData icon,
    required Color color,
    required SolarHouseNode node,
    required bool isDark,
    required bool isGlass,
  }) {
    final isSelected = _selectedNode == node;

    // Menyesuaikan warna latar & teks badge berdasarkan mode tema
    final Color badgeBg;
    final Color badgeTextColor;
    if (isGlass) {
      badgeBg = const Color(0xFF0B101E).withValues(alpha: 0.70);
      badgeTextColor = Colors.white;
    } else if (isDark) {
      badgeBg = Colors.black.withValues(alpha: 0.75);
      badgeTextColor = Colors.white;
    } else {
      // Mode Terang: pill putih bersih dengan kontras tinggi & bayangan lembut
      badgeBg = Colors.white.withValues(alpha: 0.94);
      badgeTextColor = const Color(0xFF0F172A);
    }

    return ScaleOnPress(
      onTap: () => _handleNodeTap(node),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: badgeBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: isDark ? 0.5 : 0.4),
            width: isSelected ? 1.5 : 0.8,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            BoxShadow(
              color: color.withValues(alpha: isSelected ? 0.45 : 0.15),
              blurRadius: isSelected ? 10 : 5,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: badgeTextColor,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom Painter yang menggambar arsitektur 3D Rumah Pintar Isometrik
/// lengkap dengan panel surya, inverter, jendela beriluminasi, tiang PLN,
/// dan partikel konduit energi yang mengalir dinamis.
class _SmartSolarHousePainter extends CustomPainter {
  final double flowProgress;
  final double pulseValue;
  final bool isDark;
  final double solarWatt;
  final double loadWatt;
  final double batterySoc;
  final double gridWatt;
  final SolarHouseNode? selectedNode;

  _SmartSolarHousePainter({
    required this.flowProgress,
    required this.pulseValue,
    required this.isDark,
    required this.solarWatt,
    required this.loadWatt,
    required this.batterySoc,
    required this.gridWatt,
    this.selectedNode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Titik pusat isometrik rumah
    final centerX = w * 0.48;
    final centerY = h * 0.58;

    // ── 0. Latar Belakang Lingkungan & Matahari ──────────────────
    _drawSun(canvas, Offset(w * 0.18, h * 0.18));

    // ── 1. Landasan Tanah Isometrik (Base Yard) ───────────────────
    _drawIsometricGround(canvas, centerX, centerY, w, h);

    // ── 2. Struktur Dinding Rumah 3D ──────────────────────────────
    _drawHouseWalls(canvas, centerX, centerY);

    // ── 3. Jendela Berpendar (Smart Home Lighting) ───────────────
    _drawIlluminatedWindows(canvas, centerX, centerY);

    // ── 4. Atap Arsitektur Bersudut 30° ──────────────────────────
    _drawRoof(canvas, centerX, centerY);

    // ── 5. Grid Modul Panel Surya Safir di Atap ──────────────────
    _drawSolarPanels(canvas, centerX, centerY);

    // ── 6. Hybrid Inverter Pintar di Dinding Samping ─────────────
    _drawWallmountInverter(canvas, centerX, centerY);

    // ── 7. Unit Baterai LiFePO4 di Garasi/Utilitas ───────────────
    _drawBatteryPack(canvas, centerX, centerY);

    // ── 8. Tiang Listrik & Kabel Grid PLN ────────────────────────
    _drawPowerGridPole(canvas, w * 0.88, centerY + 30);

    // ── 9. Konduit Aliran Energi & Partikel Elektron ─────────────
    _drawEnergyConduits(canvas, centerX, centerY, w, h);
  }

  void _drawSun(Canvas canvas, Offset sunCenter) {
    final sunRadius = 18.0 + (pulseValue * 2.5);
    final auraRadius = 45.0 + (pulseValue * 8.0);

    // Aura cahaya matahari
    final auraPaint = Paint()
      ..shader = ui.Gradient.radial(
        sunCenter,
        auraRadius,
        [
          const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.35 : 0.25),
          const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.08 : 0.05),
          Colors.transparent,
        ],
        const [0.0, 0.45, 1.0],
      );
    canvas.drawCircle(sunCenter, auraRadius, auraPaint);

    // Bola matahari
    final sunPaint = Paint()
      ..shader = ui.Gradient.radial(
        sunCenter,
        sunRadius,
        [
          const Color(0xFFFFFBEB),
          const Color(0xFFFDE047),
          const Color(0xFFF59E0B),
        ],
        const [0.0, 0.5, 1.0],
      );
    canvas.drawCircle(sunCenter, sunRadius, sunPaint);

    // Berkas sinar matahari jatuh ke atap
    final rayPaint = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: (isDark ? 0.15 : 0.28) + (pulseValue * 0.1))
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      sunCenter + const Offset(12, 12),
      sunCenter + const Offset(45, 40),
      rayPaint,
    );
    canvas.drawLine(
      sunCenter + const Offset(16, 6),
      sunCenter + const Offset(55, 25),
      rayPaint,
    );
  }

  void _drawIsometricGround(Canvas canvas, double cx, double cy, double w, double h) {
    final groundPath = Path()
      ..moveTo(cx, cy + 62)
      ..lineTo(cx + 140, cy - 8)
      ..lineTo(cx, cy - 78)
      ..lineTo(cx - 140, cy - 8)
      ..close();

    final groundPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx - 140, cy),
        Offset(cx + 140, cy),
        [
          isDark ? const Color(0xFF0F121B) : const Color(0xFFE2E8F0),
          isDark ? const Color(0xFF141724) : const Color(0xFFF1F5F9),
        ],
      );
    canvas.drawPath(groundPath, groundPaint);

    final edgePaint = Paint()
      ..color = isDark ? const Color(0xFF1E2436) : const Color(0xFFCBD5E1)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(groundPath, edgePaint);
  }

  void _drawHouseWalls(Canvas canvas, double cx, double cy) {
    // Dimensi isometrik rumah
    const double houseH = 68.0;

    // Dinding Samping Kiri (Bay Utilitas & Inverter)
    final leftWall = Path()
      ..moveTo(cx - 95, cy - 10)
      ..lineTo(cx, cy + 38)
      ..lineTo(cx, cy + 38 - houseH)
      ..lineTo(cx - 95, cy - 10 - houseH)
      ..close();

    final leftPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx - 95, cy),
        Offset(cx, cy),
        [
          isDark ? const Color(0xFF181B26) : const Color(0xFFE2E8F0),
          isDark ? const Color(0xFF222738) : const Color(0xFFCBD5E1),
        ],
      );
    canvas.drawPath(leftWall, leftPaint);

    // Dinding Depan Kanan (Pintu & Ruang Tamu)
    final rightWall = Path()
      ..moveTo(cx, cy + 38)
      ..lineTo(cx + 105, cy - 14)
      ..lineTo(cx + 105, cy - 14 - houseH)
      ..lineTo(cx, cy + 38 - houseH)
      ..close();

    final rightPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx, cy),
        Offset(cx + 105, cy),
        [
          isDark ? const Color(0xFF262C3F) : const Color(0xFFCBD5E1),
          isDark ? const Color(0xFF191D2A) : const Color(0xFFE2E8F0),
        ],
      );
    canvas.drawPath(rightWall, rightPaint);

    // Garis sudut arsitektur
    final linePaint = Paint()
      ..color = isDark ? const Color(0xFF333B54) : const Color(0xFF94A3B8)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(cx, cy + 38), Offset(cx, cy + 38 - houseH), linePaint);
  }

  void _drawIlluminatedWindows(Canvas canvas, double cx, double cy) {
    // Jendela Dinding Kanan (Interior Home Load - Kuning / Ungu Hangat)
    final win1 = Path()
      ..moveTo(cx + 25, cy + 16 - 32)
      ..lineTo(cx + 55, cy + 1 - 32)
      ..lineTo(cx + 55, cy + 1 - 12)
      ..lineTo(cx + 25, cy + 16 - 12)
      ..close();

    final winGlowPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx + 25, cy - 25),
        Offset(cx + 55, cy - 25),
        [
          const Color(0xFFFDE047).withValues(alpha: 0.85),
          const Color(0xFFCA8A04).withValues(alpha: 0.85),
        ],
      );
    canvas.drawPath(win1, winGlowPaint);

    // Efek pendaran kaca jendela
    final winBorder = Paint()
      ..color = const Color(0xFFFEF08A)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(win1, winBorder);

    // Pintu Modern di Kanan
    final door = Path()
      ..moveTo(cx + 68, cy - 6 - 2)
      ..lineTo(cx + 90, cy - 17 - 2)
      ..lineTo(cx + 90, cy - 17 + 34)
      ..lineTo(cx + 68, cy - 6 + 34)
      ..close();

    final doorPaint = Paint()
      ..color = isDark ? const Color(0xFF12141C) : const Color(0xFF64748B);
    canvas.drawPath(door, doorPaint);
  }

  void _drawRoof(Canvas canvas, double cx, double cy) {
    const double houseH = 68.0;

    // Atap Isometrik Miring (Facing Sun)
    final roofBase = Path()
      ..moveTo(cx - 105, cy - 10 - houseH - 2)
      ..lineTo(cx + 8, cy + 44 - houseH - 2)
      ..lineTo(cx + 115, cy - 12 - houseH - 2)
      ..lineTo(cx + 5, cy - 66 - houseH - 2)
      ..close();

    final roofPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx - 105, cy - houseH),
        Offset(cx + 115, cy - houseH),
        [
          isDark ? const Color(0xFF1A1F2C) : const Color(0xFF94A3B8),
          isDark ? const Color(0xFF11141C) : const Color(0xFF64748B),
        ],
      );
    canvas.drawPath(roofBase, roofPaint);
  }

  void _drawSolarPanels(Canvas canvas, double cx, double cy) {
    const double houseH = 68.0;

    // Bidang Panel Surya Safir pada sisi atap miring
    final pvArray = Path()
      ..moveTo(cx - 85, cy - 10 - houseH + 2)
      ..lineTo(cx + 2, cy + 34 - houseH + 2)
      ..lineTo(cx + 95, cy - 14 - houseH + 2)
      ..lineTo(cx + 8, cy - 58 - houseH + 2)
      ..close();

    final pvShader = ui.Gradient.linear(
      Offset(cx - 85, cy - 60),
      Offset(cx + 95, cy + 20),
      [
        const Color(0xFF1E3A8A), // Deep Sapphire Blue
        const Color(0xFF0284C7), // Vibrant Solar Sky
        const Color(0xFF0369A1),
      ],
      const [0.0, 0.6, 1.0],
    );

    final pvPaint = Paint()
      ..shader = pvShader
      ..style = PaintingStyle.fill;
    canvas.drawPath(pvArray, pvPaint);

    // Frame tepi panel perak
    final pvBorder = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.6)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(pvArray, pvBorder);

    // Grid Busbar Pembagi Sel Silikon
    final gridLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // 2 Garis diagonal pembagi sel
    canvas.drawLine(
      Offset(cx - 40, cy + 12 - houseH),
      Offset(cx + 52, cy - 36 - houseH),
      gridLinePaint,
    );
    canvas.drawLine(
      Offset(cx - 42, cy - 34 - houseH),
      Offset(cx + 48, cy + 10 - houseH),
      gridLinePaint,
    );

    // Kilau spekular pantulan sinar matahari (Gleam)
    final gleamProgress = (flowProgress * 2.0) % 2.0;
    if (gleamProgress <= 1.0) {
      final gleamX = cx - 50 + (gleamProgress * 100);
      final gleamY = cy - 20 - houseH + (gleamProgress * 20);

      final gleamPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.4 * (1.0 - gleamProgress))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(gleamX, gleamY), 10, gleamPaint);
    }
  }

  void _drawWallmountInverter(Canvas canvas, double cx, double cy) {
    // Inverter terpasang di dinding kiri rumah
    final invX = cx - 62.0;
    final invY = cy + 2.0;

    final invRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(invX, invY), width: 22, height: 32),
      const Radius.circular(5),
    );

    // Chassis Inverter
    final invPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(invX - 11, invY - 16),
        Offset(invX + 11, invY + 16),
        [
          const Color(0xFF334155),
          const Color(0xFF0F172A),
        ],
      );
    canvas.drawRRect(invRect, invPaint);

    final invBorder = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.7)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(invRect, invBorder);

    // LCD Mini Display
    final lcdRect = Rect.fromCenter(center: Offset(invX, invY - 6), width: 14, height: 8);
    canvas.drawRect(lcdRect, Paint()..color = const Color(0xFF022C22));

    // LED Status berkedip hijau emerald
    final ledPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.0 + (pulseValue * 2.0));
    canvas.drawCircle(Offset(invX, invY + 6), 2.2, ledPaint);
  }

  void _drawBatteryPack(Canvas canvas, double cx, double cy) {
    // Baterai LiFePO4 di area utilitas tanah sebelah kiri
    final batX = cx - 96.0;
    final batY = cy + 22.0;

    final batRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(batX, batY), width: 18, height: 28),
      const Radius.circular(4),
    );

    final batPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(batX - 9, batY - 14),
        Offset(batX + 9, batY + 14),
        [
          const Color(0xFF1E293B),
          const Color(0xFF090D16),
        ],
      );
    canvas.drawRRect(batRect, batPaint);

    // Indikator bar pengisian daya vertikal
    for (int i = 0; i < 4; i++) {
      final barPaint = Paint()
        ..color = const Color(0xFF06B6D4).withValues(alpha: i < 3 ? 0.9 : 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(batX - 5, batY + 6 - (i * 5), 10, 3),
          const Radius.circular(1.5),
        ),
        barPaint,
      );
    }
  }

  void _drawPowerGridPole(Canvas canvas, double poleX, double poleY) {
    // Tiang Listrik Beton PLN
    final polePaint = Paint()
      ..color = isDark ? const Color(0xFF475569) : const Color(0xFF64748B)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(poleX, poleY), Offset(poleX, poleY - 75), polePaint);

    // Cross-arm tiang
    final armPaint = Paint()
      ..color = isDark ? const Color(0xFF64748B) : const Color(0xFF475569)
      ..strokeWidth = 2.4;
    canvas.drawLine(Offset(poleX - 18, poleY - 65), Offset(poleX + 18, poleY - 65), armPaint);

    // Isolator Keramik PLN
    final isolatorPaint = Paint()..color = const Color(0xFF06B6D4);
    canvas.drawCircle(Offset(poleX - 16, poleY - 66), 2.5, isolatorPaint);
    canvas.drawCircle(Offset(poleX + 16, poleY - 66), 2.5, isolatorPaint);

    // Kabel Transmisi Melengkung Katenari dari Tiang ke Atap Rumah
    final wirePath = Path()
      ..moveTo(poleX - 16, poleY - 66)
      ..quadraticBezierTo(
        (poleX + 70) / 2,
        poleY - 45,
        poleX - 70,
        poleY - 70,
      );

    final wirePaint = Paint()
      ..color = isDark ? const Color(0xFF64748B).withValues(alpha: 0.6) : const Color(0xFF94A3B8)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(wirePath, wirePaint);
  }

  void _drawEnergyConduits(Canvas canvas, double cx, double cy, double w, double h) {
    // Jalur 1: Panel Surya Atap -> Inverter Dinding
    final p1Start = Offset(cx - 30, cy - 80);
    final p1End = Offset(cx - 62, cy - 14);
    _drawAnimatedConduit(
      canvas: canvas,
      start: p1Start,
      end: p1End,
      color: const Color(0xFFF59E0B), // Solar Amber
      isForward: true,
      particleSpeedMultiplier: 1.0,
    );

    // Jalur 2: Inverter -> Baterai LiFePO4
    final p2Start = Offset(cx - 62, cy + 16);
    final p2End = Offset(cx - 96, cy + 14);
    _drawAnimatedConduit(
      canvas: canvas,
      start: p2Start,
      end: p2End,
      color: const Color(0xFF06B6D4), // Cyan
      isForward: true, // Charging
      particleSpeedMultiplier: 0.8,
    );

    // Jalur 3: Inverter -> Interior Rumah (Beban Beban Listrik)
    final p3Start = Offset(cx - 50, cy + 10);
    final p3End = Offset(cx + 38, cy - 2);
    _drawAnimatedConduit(
      canvas: canvas,
      start: p3Start,
      end: p3End,
      color: const Color(0xFF8B5CF6), // Purple
      isForward: true,
      particleSpeedMultiplier: 1.2,
    );

    // Jalur 4: Inverter -> Grid PLN
    final p4Start = Offset(cx - 50, cy + 24);
    final p4End = Offset(w * 0.88 - 16, cy + 30 - 66);
    final isExport = gridWatt <= 0;
    _drawAnimatedConduit(
      canvas: canvas,
      start: p4Start,
      end: p4End,
      color: isExport ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      isForward: isExport,
      particleSpeedMultiplier: 1.1,
    );
  }

  void _drawAnimatedConduit({
    required Canvas canvas,
    required Offset start,
    required Offset end,
    required Color color,
    required bool isForward,
    required double particleSpeedMultiplier,
  }) {
    // Garis dasar konduit berpendar lembut
    final linePaint = Paint()
      ..color = color.withValues(alpha: isDark ? 0.25 : 0.40)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, end, linePaint);

    // Partikel elektron bergerak di sepanjang garis
    final progress = (flowProgress * particleSpeedMultiplier) % 1.0;
    final effectiveProgress = isForward ? progress : (1.0 - progress);

    final currentPos = Offset.lerp(start, end, effectiveProgress)!;

    // Glow partikel
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(currentPos, 3.2, glowPaint);

    // Inti partikel
    final corePaint = Paint()..color = Colors.white;
    canvas.drawCircle(currentPos, 1.6, corePaint);
  }

  @override
  bool shouldRepaint(covariant _SmartSolarHousePainter old) {
    return old.flowProgress != flowProgress ||
        old.pulseValue != pulseValue ||
        old.isDark != isDark ||
        old.selectedNode != selectedNode ||
        old.solarWatt != solarWatt ||
        old.loadWatt != loadWatt ||
        old.gridWatt != gridWatt;
  }
}
