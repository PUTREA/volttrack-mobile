import 'package:flutter/material.dart';

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config.dart';
import '../services/auth_service.dart';
import '../services/aura_ai_service.dart';
import '../services/data_service.dart';
import '../widgets/motion_helpers.dart';
import '../widgets/energy_flow_widget.dart';
import '../widgets/custom_bottom_bar.dart';
import 'login_screen.dart';
import 'monitoring_screen.dart';
import 'warranty_screen.dart';
import 'roi_screen.dart';
import 'profile_screen.dart';
import 'order_detail_screen.dart';
import 'product_order_screen.dart';
import '../widgets/stitch_telemetry_bento.dart';
import '../widgets/smart_solar_house_3d.dart';
import '../widgets/aura_floating_button.dart';
import 'aura_assistant_sheet.dart';

import '../theme/theme_controller.dart';

// Dynamic design tokens reacting to Dark & Light mode
VoltTrackPalette get _palette => ThemeController.instance.palette;
Color get _kCardBg => _palette.cardBg;
Color get _kCardBgElevated => _palette.cardElevated;
Color get _kBorderColor => _palette.borderColor;
Color get _kPrimaryTeal => _palette.primaryTeal;
Color get _kNeonTeal => _palette.neonTeal;
Color get _kSolarAmber => _palette.solarAmber;
Color get _kTextPrimary => _palette.textPrimary;
Color get _kTextSecondary => _palette.textSecondary;
Color get _kTextMuted => _palette.textMuted;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _auth = AuthService();
  int _tab = 0;

  AuraInsight?
  _latestInsight; // insight terbaru untuk tip floating (null = tanpa tip)
  Timer? _insightTimer;

  @override
  void initState() {
    super.initState();
    ThemeController.instance.addListener(_handleThemeChanged);
    WidgetsBinding.instance.addObserver(this);
    _refreshInsights();
    // Segarkan tiap 2 menit selama tab Home aktif.
    _insightTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (_tab == 0) _refreshInsights();
    });
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_handleThemeChanged);
    WidgetsBinding.instance.removeObserver(this);
    _insightTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshInsights();
    }
  }

  Future<void> _refreshInsights() async {
    try {
      final list = await AuraAiService.instance.fetchInsights(limit: 5);
      if (!mounted) return;
      setState(() => _latestInsight = list.isNotEmpty ? list.first : null);
    } catch (_) {
      /* tip opsional; jangan ganggu UI bila gagal */
    }
  }

  void _handleThemeChanged() {
    if (mounted) setState(() {});
  }

  void _openInsightInAura() {
    final insight = _latestInsight;
    if (insight == null) {
      _openAuraAssistant();
      return;
    }
    // Tandai terbaca, buka AURA dengan pesan awal menjelaskan insight ini.
    AuraAiService.instance.markInsightRead(insight.id);
    AuraAssistantSheet.show(
      context,
      onNavigateTab: (idx) => setState(() => _tab = idx),
      initialPrompt: 'Jelaskan insight ini: ${insight.title}',
    );
    setState(() => _latestInsight = null); // tip hilang setelah dibuka
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Keluar dari Akun?',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: _kTextPrimary,
          ),
        ),
        content: Text(
          'Anda akan dialihkan kembali ke layar login.',
          style: GoogleFonts.inter(color: _kTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Batal',
              style: GoogleFonts.inter(color: _kTextSecondary),
            ),
          ),
          ScaleOnPress(
            onTap: () => Navigator.of(ctx).pop(true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade800,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Keluar',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );

    if (confirm != true) return;
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, animation, secondaryAnimation) => const LoginScreen(),
        transitionsBuilder: (_, animation, secondaryAnimation, child) =>
            FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: kEaseOutStrong,
              ),
              child: child,
            ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  void _openAuraAssistant() {
    AuraAssistantSheet.show(
      context,
      onNavigateTab: (idx) => setState(() => _tab = idx),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _ExecutiveHomeTab(
        onNavigateTab: (idx) => setState(() => _tab = idx),
        onExploreRoi: () => setState(() => _tab = 4),
      ),
      const _OrdersTab(),
      const MonitoringScreen(),
      const WarrantyScreen(),
      RoiScreen(onExploreMarketplace: () => setState(() => _tab = 0)),
      const ProfileScreen(),
    ];

    final titles = [
      'Executive Solar Hub',
      'Daftar Pesanan',
      'Live Monitoring',
      'Garansi & Unit',
      'Kalkulator ROI',
      'Profil Akun',
    ];

    return Scaffold(
      backgroundColor: _palette.bg,
      appBar: AppBar(
        backgroundColor: _palette.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 18,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _palette.isDark
                    ? const Color(0xFF1B1E28)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorderColor, width: 0.8),
              ),
              child: Center(
                child: Icon(Icons.bolt_rounded, color: _kSolarAmber, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'VoltTrack',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: _kTextPrimary,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: Text(
                    titles[_tab],
                    key: ValueKey('${_tab}_${_palette.isDark}'),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _kTextMuted,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          ScaleOnPress(
            onTap: _openAuraAssistant,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00F5D4).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00F5D4).withValues(alpha: 0.35),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00F5D4),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0xFF00F5D4), blurRadius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'AURA',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF00F5D4),
                      letterSpacing: 0.04,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const ThemeToggleSwitch(),
          const SizedBox(width: 6),
          ScaleOnPress(
            onTap: _logout,
            child: Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: _palette.isDark
                    ? const Color(0xFF141720)
                    : const Color(0xFFF1F3F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorderColor, width: 0.8),
              ),
              child: Icon(
                Icons.logout_rounded,
                color: _kTextSecondary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
      // AnimatedSwitcher for tab body wrapped in Stack with Living Aura Floating Button
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: kEaseOutCubic),
              child: child,
            ),
            child: KeyedSubtree(
              key: ValueKey('${_tab}_${_palette.isDark ? "dark" : "light"}'),
              child: tabs[_tab],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 84,
            child: AuraFloatingButton(
              onTap: _openAuraAssistant,
              // Tip NYATA dari insight engine (tanpa angka palsu bila tak ada insight).
              proactiveTip: (_tab == 0 && _latestInsight != null)
                  ? _latestInsight!.title
                  : null,
              severity: _latestInsight?.severity ?? 'info',
              onTipTap: _openInsightInAura,
            ),
          ),
        ],
      ),
      // Custom floating glassmorphic bottom navigation bar
      bottomNavigationBar: VoltTrackBottomBar(
        selectedIndex: _tab,
        onItemSelected: (i) => setState(() => _tab = i),
        items: const [
          VoltTrackNavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Beranda',
          ),
          VoltTrackNavItem(
            icon: Icons.receipt_long_outlined,
            activeIcon: Icons.receipt_long_rounded,
            label: 'Order',
          ),
          VoltTrackNavItem(
            icon: Icons.bolt_rounded,
            activeIcon: Icons.bolt_rounded,
            label: 'Monitor',
            isHero: true,
          ),
          VoltTrackNavItem(
            icon: Icons.verified_user_outlined,
            activeIcon: Icons.verified_user_rounded,
            label: 'Garansi',
          ),
          VoltTrackNavItem(
            icon: Icons.calculate_outlined,
            activeIcon: Icons.calculate_rounded,
            label: 'ROI',
          ),
          VoltTrackNavItem(
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// EXECUTIVE SOLAR & MARKETPLACE HUB (TAB 0)
// ─────────────────────────────────────────────────────────────

class _ExecutiveHomeTab extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;
  final VoidCallback? onExploreRoi;
  const _ExecutiveHomeTab({this.onNavigateTab, this.onExploreRoi});

  @override
  State<_ExecutiveHomeTab> createState() => _ExecutiveHomeTabState();
}

class _ExecutiveHomeTabState extends State<_ExecutiveHomeTab> {
  final _data = DataService();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _catalogKey = GlobalKey();
  late Future<List<Map<String, dynamic>>> _future;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedCategoryIndex = 0;

  final List<String> _categories = [
    'Semua',
    'Inverter Pintar',
    'Solar Kits',
    'Baterai',
  ];

  @override
  void initState() {
    super.initState();
    ThemeController.instance.addListener(_onThemeChanged);
    _refresh();
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onThemeChanged);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _refresh() {
    setState(() {
      _future = _data.products();
    });
  }

  void _scrollToCatalog() {
    HapticFeedback.selectionClick();
    if (_catalogKey.currentContext != null) {
      Scrollable.ensureVisible(
        _catalogKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  List<Map<String, dynamic>> _filterProducts(List<Map<String, dynamic>> all) {
    return all.where((p) {
      final name = (p['product_name'] ?? '').toString().toLowerCase();
      final model = (p['model'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase().trim();
      final matchQuery = q.isEmpty || name.contains(q) || model.contains(q);
      if (!matchQuery) return false;
      if (_selectedCategoryIndex == 1) {
        return name.contains('inverter') ||
            model.contains('x') ||
            model.contains('qr');
      } else if (_selectedCategoryIndex == 2) {
        return name.contains('solar') || name.contains('kit');
      } else if (_selectedCategoryIndex == 3) {
        return name.contains('baterai') || name.contains('battery');
      }
      return true;
    }).toList();
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ScaleOnPress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorderColor, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: _palette.isDark ? 0.25 : 0.04,
              ),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: _kTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSolarWeatherForecastCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _palette.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kBorderColor, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _palette.isDark ? 0.2 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _kSolarAmber.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.wb_sunny_rounded,
                        color: _kSolarAmber,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Prakiraan Radiasi Cuaca Surya',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: _kTextPrimary,
                            ),
                          ),
                          Text(
                            'Jakarta Selatan · Potensi Radiasi Surya Puncak',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: _kTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 12,
                      color: Color(0xFF34D399),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Index 8.2',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF34D399),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _weatherMiniStat(
                  'Radiasi Terik',
                  '940 W/m²',
                  Icons.flare_rounded,
                  _kSolarAmber,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _weatherMiniStat(
                  'Peak Sun Hours',
                  '4.8 PSH',
                  Icons.schedule_rounded,
                  _kNeonTeal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _weatherMiniStat(
                  'Estimasi Hasil',
                  '±21.5 kWh',
                  Icons.energy_savings_leaf_rounded,
                  const Color(0xFF34D399),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weatherMiniStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: _palette.cardElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorderColor, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    color: _kTextMuted,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _kTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: RefreshIndicator(
        onRefresh: () async => _refresh(),
        color: _kNeonTeal,
        backgroundColor: _kCardBg,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kNeonTeal.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Memuat data VoltTrack...',
                      style: GoogleFonts.inter(
                        color: _kTextSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }
            final allProducts = snap.data ?? [];
            final filtered = _filterProducts(allProducts);

            return ListView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              children: [
                // 1. Executive Status Header Card
                StaggerItem(
                  delay: const Duration(milliseconds: 0),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _kCardBg,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _kBorderColor, width: 0.8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: _palette.isDark ? 0.35 : 0.04,
                          ),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined,
                                        size: 12,
                                        color: _kNeonTeal,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Citra Garden Substation Alpha',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: _kTextMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Halo, Budi Santoso ☀️',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 15.0,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                      color: _kTextPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: _kNeonTeal.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: _kNeonTeal.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: _kNeonTeal,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: _kNeonTeal.withValues(
                                              alpha: 0.7,
                                            ),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'VT-INV-8492 Online',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: _kNeonTeal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Hero 3D Smart Solar House & Live Conduits
                StaggerItem(
                  delay: const Duration(milliseconds: 30),
                  child: SmartSolarHouse3D(
                    solarWatt: 3850,
                    loadWatt: 1420,
                    batterySoc: 88.0,
                    batteryWatt: 600,
                    gridWatt: -1830,
                    onSwitchToOrbit: () => widget.onNavigateTab?.call(2),
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Quick Action Dock (4 1-Tap Pills)
                StaggerItem(
                  delay: const Duration(milliseconds: 50),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildQuickAction(
                          icon: Icons.storefront_rounded,
                          label: 'Katalog',
                          color: _kSolarAmber,
                          onTap: _scrollToCatalog,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQuickAction(
                          icon: Icons.bolt_rounded,
                          label: 'Live Monitor',
                          color: _kNeonTeal,
                          onTap: () => widget.onNavigateTab?.call(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQuickAction(
                          icon: Icons.verified_user_rounded,
                          label: 'E-Garansi',
                          color: const Color(0xFF06B6D4),
                          onTap: () => widget.onNavigateTab?.call(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQuickAction(
                          icon: Icons.calculate_rounded,
                          label: 'Simulasi ROI',
                          color: const Color(0xFF8B5CF6),
                          onTap: () => widget.onNavigateTab?.call(4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Solar Weather & Radiation Forecast Card
                StaggerItem(
                  delay: const Duration(milliseconds: 60),
                  child: _buildSolarWeatherForecastCard(),
                ),
                const SizedBox(height: 16),

                // 4. Stitch Telemetry Bento Grid
                const StaggerItem(
                  delay: Duration(milliseconds: 70),
                  child: StitchTelemetryBento(
                    dailyYieldKwh: 18.4,
                    yieldGrowthPercent: 14.8,
                    monthlyRoiIdr: 1450000,
                    monthlyTargetIdr: 2000000,
                    autonomyPercent: 92.0,
                    co2OffsetKg: 14.2,
                    treesEquivalent: 0.7,
                  ),
                ),
                const SizedBox(height: 20),

                // Anchor for Scroll to Catalog
                Container(key: _catalogKey),

                // 5. Search Bar — dark glassmorphism
                StaggerItem(
                  delay: const Duration(milliseconds: 90),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _kCardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kBorderColor, width: 0.8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: GoogleFonts.inter(
                        color: _kTextPrimary,
                        fontSize: 13.5,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Cari tipe inverter, solar panel...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 13.5,
                          color: _kTextMuted,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: _kNeonTeal,
                          size: 22,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? ScaleOnPress(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: _kTextMuted,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.tune_rounded,
                                color: _kTextMuted,
                                size: 20,
                              ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Hardware Feature Showcase Card (Subtle & Architectural)
                StaggerItem(
                  delay: const Duration(milliseconds: 40),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _kCardBg,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _kBorderColor, width: 0.8),
                      boxShadow: [
                        BoxShadow(
                          color: _palette.isDark
                              ? Colors.black.withValues(alpha: 0.45)
                              : const Color(0xFF0F172A).withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _palette.isDark
                                      ? const Color(0xFF1E222F)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _kBorderColor,
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.solar_power_outlined,
                                      color: _kSolarAmber,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        'SOLAR ARCHITECTURE 2026',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          color: _palette.isDark
                                              ? const Color(0xFFCBD5E1)
                                              : const Color(0xFF475569),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InverterIconWidget(size: 24, color: _kPrimaryTeal),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Ekosistem PLTS Atap Cerdas',
                          style: GoogleFonts.inter(
                            color: _kTextPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Inverter pintar & modul surya efisiensi 98.4% untuk memangkas beban tagihan listrik PLN secara otomatis.',
                          style: GoogleFonts.inter(
                            color: _kTextSecondary,
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _kCardBgElevated,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _kBorderColor,
                                    width: 0.6,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.bolt_rounded,
                                      size: 14,
                                      color: _kSolarAmber,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Efisiensi 98.4%',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _kTextPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _kCardBgElevated,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _kBorderColor,
                                    width: 0.6,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.verified_user_outlined,
                                      size: 14,
                                      color: _kNeonTeal,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Garansi 25 Thn',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _kTextPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (widget.onExploreRoi != null) ...[
                          const SizedBox(height: 14),
                          ScaleOnPress(
                            onTap: widget.onExploreRoi,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _palette.isDark
                                    ? const Color(0xFF1E222F)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _kBorderColor,
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.calculate_outlined,
                                    color: _kTextPrimary,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Hitung Estimasi Penghematan (ROI) ➔',
                                    style: GoogleFonts.inter(
                                      color: _kTextPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Category Filter Chips
                StaggerItem(
                  delay: const Duration(milliseconds: 100),
                  child: SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final isSelected = _selectedCategoryIndex == idx;
                        return ScaleOnPress(
                          onTap: () =>
                              setState(() => _selectedCategoryIndex = idx),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: kEaseOutCubic,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (_palette.isDark
                                        ? const Color(0xFF222634)
                                        : const Color(0xFFE2E8F0))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? _kBorderColor
                                    : _kBorderColor.withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _categories[idx],
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? _kTextPrimary
                                      : _kTextMuted,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Section Title & Counter
                StaggerItem(
                  delay: const Duration(milliseconds: 120),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Katalog Hardware Resmi',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _kTextPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _kCardBgElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _kBorderColor),
                        ),
                        child: Text(
                          '${filtered.length} Unit',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _kTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 5. Product Cards — staggered entrance
                if (filtered.isEmpty)
                  StaggerItem(
                    delay: const Duration(milliseconds: 140),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: _kCardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _kBorderColor),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 54,
                            color: _kTextMuted.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tidak ada produk yang cocok.',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: _kTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedCategoryIndex == 3
                                ? 'Baterai LiFePO4 sedang dalam proses restock Q4 2026.'
                                : 'Coba ubah kata kunci pencarian atau kategori filter.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _kTextMuted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextButton.icon(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _selectedCategoryIndex = 0;
                              });
                            },
                            icon: Icon(
                              Icons.refresh_rounded,
                              size: 16,
                              color: _kNeonTeal,
                            ),
                            label: Text(
                              'Reset Filter',
                              style: GoogleFonts.inter(color: _kNeonTeal),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...filtered.asMap().entries.map((entry) {
                    return StaggerItem(
                      delay: Duration(milliseconds: 140 + entry.key * 50),
                      child: ScaleOnPress(
                        onTap: () {
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProductOrderScreen(product: entry.value),
                                ),
                              )
                              .then((_) => _refresh());
                        },
                        child: _buildProductCard(context, entry.value),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Map<String, dynamic> p) {
    final stock = int.tryParse(p['stock_qty']?.toString() ?? '') ?? 0;
    final inStock = stock > 0;
    final model = (p['model'] ?? 'Standard').toString();
    final name = (p['product_name'] ?? 'VoltTrack Unit').toString();
    final capacityWp = p['capacity_wp'];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kBorderColor, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: _kPrimaryTeal.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hardware Pod
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _kPrimaryTeal.withValues(alpha: 0.18),
                        _kNeonTeal.withValues(alpha: 0.06),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _kPrimaryTeal.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Center(
                    child: InverterIconWidget(size: 34, color: _kNeonTeal),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: _kTextPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: inStock
                                  ? const Color(0xFF10B981)
                                        .withValues(alpha: 0.15)
                                  : const Color(0xFFEF4444)
                                        .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: inStock
                                    ? const Color(0xFF10B981)
                                          .withValues(alpha: 0.4)
                                    : const Color(0xFFEF4444)
                                          .withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              inStock ? 'Stok: $stock' : 'Habis',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: inStock
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFFF87171),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: _kCardBgElevated,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _kBorderColor),
                            ),
                            child: Text(
                              model,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _kTextSecondary,
                              ),
                            ),
                          ),
                          if (capacityWp != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: _kSolarAmber.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _kSolarAmber.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                '$capacityWp Wp',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _kSolarAmber,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Feature row — dark style
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _kCardBgElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: Color(0xFF34D399),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Efisiensi 98.2%',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: _kTextSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: _kNeonTeal,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Garansi Resmi 25 Thn',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: _kTextSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 20, color: _kBorderColor.withValues(alpha: 0.6)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Harga Unit Resmi',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: _kTextMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppConfig.formatRupiah(p['price']),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: _kNeonTeal,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                ScaleOnPress(
                  onTap: inStock
                      ? () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProductOrderScreen(product: p),
                                ),
                              )
                              .then((_) => _refresh());
                        }
                      : null,
                  child: AnimatedOpacity(
                    opacity: inStock ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: inStock
                            ? (_palette.isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFF0F172A))
                            : _kCardBgElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: inStock ? _palette.borderColor : _kBorderColor,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 14,
                            color: inStock ? Colors.white : _kTextMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Pesan',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: inStock ? Colors.white : _kTextMuted,
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
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ORDERS TAB
// ─────────────────────────────────────────────────────────────

class _OrdersTab extends StatefulWidget {
  const _OrdersTab();

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  final _data = DataService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    ThemeController.instance.addListener(_onThemeChanged);
    _refresh();
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _refresh() {
    setState(() {
      _future = _data.myOrders();
    });
  }

  Widget _buildStatusChip(String? status) {
    Color bg;
    Color text;
    Color border;
    String label;

    switch (status) {
      case 'paid':
        bg = const Color(0xFF10B981).withValues(alpha: 0.12);
        text = const Color(0xFF34D399);
        border = const Color(0xFF10B981).withValues(alpha: 0.3);
        label = 'Lunas';
        break;
      case 'failed':
        bg = const Color(0xFFEF4444).withValues(alpha: 0.12);
        text = const Color(0xFFF87171);
        border = const Color(0xFFEF4444).withValues(alpha: 0.3);
        label = 'Gagal';
        break;
      case 'confirmed':
        bg = const Color(0xFF3B82F6).withValues(alpha: 0.12);
        text = const Color(0xFF60A5FA);
        border = const Color(0xFF3B82F6).withValues(alpha: 0.3);
        label = 'Dikonfirmasi';
        break;
      default:
        bg = _kSolarAmber.withValues(alpha: 0.12);
        text = _kSolarAmber;
        border = _kSolarAmber.withValues(alpha: 0.3);
        label = 'Menunggu Bayar';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );
  }

  String _formatOrderDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      final m = months[dt.month - 1];
      final min = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} $m ${dt.year} • ${dt.hour}:$min WIB';
    } catch (_) {
      return '';
    }
  }

  Widget _buildOrderSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _kBorderColor.withValues(alpha: 0.6),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 90,
                height: 15,
                decoration: BoxDecoration(
                  color: _kBorderColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              Container(
                width: 65,
                height: 20,
                decoration: BoxDecoration(
                  color: _kBorderColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: 190,
            height: 17,
            decoration: BoxDecoration(
              color: _kBorderColor.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 100,
                height: 13,
                decoration: BoxDecoration(
                  color: _kBorderColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              Container(
                width: 110,
                height: 15,
                decoration: BoxDecoration(
                  color: _kBorderColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      color: _kNeonTeal,
      backgroundColor: _kCardBg,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, _) => _buildOrderSkeleton(),
            );
          }
          final orders = snap.data ?? [];
          if (orders.isEmpty) {
            return ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              children: [
                const SizedBox(height: 120),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 54,
                        color: _kTextMuted.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Belum ada pesanan.',
                        style: GoogleFonts.inter(
                          color: _kTextMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final o = orders[i];
              final product = o['product'] as Map<String, dynamic>?;
              final dateStr = _formatOrderDate(o['created_at']?.toString());

              return StaggerItem(
                delay: Duration(milliseconds: i * 50),
                child: ScaleOnPress(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(order: o),
                      ),
                    );
                    if (mounted) _refresh();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _kCardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _kBorderColor, width: 0.8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order #${o['id']}',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14.5,
                                    color: _kTextPrimary,
                                  ),
                                ),
                                if (dateStr.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    dateStr,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: _kTextMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            _buildStatusChip(o['payment_status']?.toString()),
                          ],
                        ),
                        Divider(
                          height: 18,
                          color: _kBorderColor.withValues(alpha: 0.6),
                        ),
                        Text(
                          '${product?['product_name'] ?? 'Unit Produk'}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: _kTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Jumlah: ${o['quantity']} unit',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: _kTextMuted,
                              ),
                            ),
                            Text(
                              AppConfig.formatRupiah(o['total_price']),
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                color: _kNeonTeal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
