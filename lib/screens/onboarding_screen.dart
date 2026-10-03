import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/motion_helpers.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final bool isTourOnly;
  const OnboardingScreen({super.key, this.isTourOnly = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  static const _storage = FlutterSecureStorage();
  static const _keyOnboarding = 'has_seen_onboarding';
  int _currentPage = 0;

  final List<_OnboardingItem> _pages = const [
    _OnboardingItem(
      badge: 'HARDWARE REVOLUTION',
      title: 'Generasi Baru\nInverter Surya Cerdas',
      subtitle:
          'Dilengkapi modul IoT ESP32 & arsitektur konversi daya 98.8%. Pantau efisiensi energi secara instan dalam genggaman.',
      icon: Icons.memory_rounded,
      accentColor: Color(0xFF10B981), // Emerald
      chips: ['Dual MPPT 98.8%', 'IoT ESP32 MQTT', 'Silent Cooling'],
      illustrationType: _IllustrationType.inverter,
    ),
    _OnboardingItem(
      badge: 'FINANCIAL TRANSPARENCY',
      title: 'Kemandirian Energi\n& Nol Emisi Karbon',
      subtitle:
          'Otomatisasi ekspor surplus daya ke jaringan PLN. Hitung titik impas (ROI) dan nikmati pemangkasan tagihan hingga 92%.',
      icon: Icons.energy_savings_leaf_rounded,
      accentColor: Color(0xFFF59E0B), // Solar Amber
      chips: ['92% Otonomi', 'Net Metering PLN', 'ROI Real-Time'],
      illustrationType: _IllustrationType.energy,
    ),
    _OnboardingItem(
      badge: 'SECURITY & TRUST',
      title: 'E-Garansi Digital\nAnti-Pemalsuan Unit',
      subtitle:
          'Tidak ada lagi kartu garansi kertas yang hilang. Sertifikat kriptografi QR Code terikat permanen dengan serial number hardware.',
      icon: Icons.verified_user_rounded,
      accentColor: Color(0xFF06B6D4), // Cyan Electric
      chips: ['QR Kriptografi', '25 Tahun Garansi', '1-Tap Service'],
      illustrationType: _IllustrationType.warranty,
    ),
  ];

  Future<void> _finishOnboarding() async {
    HapticFeedback.mediumImpact();
    await _storage.write(key: _keyOnboarding, value: 'true');

    if (!mounted) return;

    if (widget.isTourOnly) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, animation, secondaryAnimation) => const LoginScreen(),
          transitionsBuilder: (_, animation, secondaryAnimation, child) => FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: kEaseOutStrong),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  void _nextPage() {
    HapticFeedback.selectionClick();
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF090A0E);
    final currentItem = _pages[_currentPage];

    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          // ── Background Glow Auras ──────────────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
            top: _currentPage == 0 ? -60 : (_currentPage == 1 ? 40 : -20),
            left: _currentPage == 0 ? -40 : (_currentPage == 1 ? 100 : 20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    currentItem.accentColor.withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF10B981).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Main Page Content ──────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Top Bar: Brand Logo & Skip button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFF12141B),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF242836), width: 0.8),
                            ),
                            child: const Center(
                              child: Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 22),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'VoltTrack',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      ScaleOnPress(
                        onTap: _finishOnboarding,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.8),
                          ),
                          child: Text(
                            'Lewati',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // PageView with 3 slides
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (idx) {
                      setState(() => _currentPage = idx);
                    },
                    itemBuilder: (context, index) {
                      final item = _pages[index];
                      return _buildSlideContent(item);
                    },
                  ),
                ),

                // Bottom Control Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: Column(
                    children: [
                      // Expanding Capsule Indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages.length, (idx) {
                          final isActive = idx == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 6,
                            width: isActive ? 28 : 7,
                            decoration: BoxDecoration(
                              color: isActive ? currentItem.accentColor : Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: currentItem.accentColor.withValues(alpha: 0.6),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 28),

                      // Next / Get Started Action Button
                      ScaleOnPress(
                        onTap: _nextPage,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _currentPage == _pages.length - 1
                                  ? [const Color(0xFF10B981), const Color(0xFF059669)]
                                  : [currentItem.accentColor, currentItem.accentColor.withValues(alpha: 0.85)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: (_currentPage == _pages.length - 1
                                        ? const Color(0xFF10B981)
                                        : currentItem.accentColor)
                                    .withValues(alpha: 0.38),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _currentPage == _pages.length - 1 ? 'Mulai Sekarang' : 'Lanjut',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  _currentPage == _pages.length - 1
                                      ? Icons.bolt_rounded
                                      : Icons.arrow_forward_rounded,
                                  color: Colors.black,
                                  size: 19,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlideContent(_OnboardingItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration / Visual Hero Unit
          _buildIllustration(item),
          const SizedBox(height: 36),

          // Category Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: item.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: item.accentColor.withValues(alpha: 0.3), width: 0.8),
            ),
            child: Text(
              item.badge,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: item.accentColor,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Main Title
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 27,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              height: 1.18,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),

          // Subtitle
          Text(
            item.subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
              height: 1.5,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 22),

          // Feature Badges Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: item.chips.map((c) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF141720),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF242836), width: 0.7),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 12, color: item.accentColor),
                    const SizedBox(width: 5),
                    Text(
                      c,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFCBD5E1),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildIllustration(_OnboardingItem item) {
    return Container(
      width: 210,
      height: 210,
      decoration: BoxDecoration(
        color: const Color(0xFF12141B),
        shape: BoxShape.circle,
        border: Border.all(color: item.accentColor.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: item.accentColor.withValues(alpha: 0.25),
            blurRadius: 36,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Orbital dotted rings
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: item.accentColor.withValues(alpha: 0.18),
                width: 1.0,
              ),
            ),
          ),
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.accentColor.withValues(alpha: 0.08),
            ),
          ),
          // Center Icon
          Icon(
            item.icon,
            size: 68,
            color: item.accentColor,
          ),
        ],
      ),
    );
  }
}

enum _IllustrationType { inverter, energy, warranty }

class _OnboardingItem {
  final String badge;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final List<String> chips;
  final _IllustrationType illustrationType;

  const _OnboardingItem({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.chips,
    required this.illustrationType,
  });
}
