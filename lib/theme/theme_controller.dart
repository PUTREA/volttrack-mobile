import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/motion_helpers.dart';

enum AppThemeType {
  dark,
  light,
  glass,
}

class VoltTrackPalette {
  final bool isDark;
  final bool isGlass;
  final Color bg;
  final Color cardBg;
  final Color cardElevated;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color neonTeal;
  final Color primaryTeal;
  final Color solarAmber;
  final Color greenPositive;
  final Color redNegative;
  final Color glassHighlight;
  final Color tertiaryCyan;
  final Color surfaceDark;

  const VoltTrackPalette({
    required this.isDark,
    this.isGlass = false,
    required this.bg,
    required this.cardBg,
    required this.cardElevated,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.neonTeal,
    required this.primaryTeal,
    required this.solarAmber,
    required this.greenPositive,
    required this.redNegative,
    this.glassHighlight = Colors.transparent,
    this.tertiaryCyan = const Color(0xFF06B6D4),
    this.surfaceDark = const Color(0xFF121317),
  });

  TextStyle spaceGrotesk({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? textPrimary,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? textPrimary,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static const dark = VoltTrackPalette(
    isDark: true,
    isGlass: false,
    bg: Color(0xFF090A0E),
    cardBg: Color(0xFF12141B),
    cardElevated: Color(0xFF1A1D26),
    borderColor: Color(0xFF242836),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
    neonTeal: Color(0xFF10B981),
    primaryTeal: Color(0xFF059669),
    solarAmber: Color(0xFFF59E0B),
    greenPositive: Color(0xFF10B981),
    redNegative: Color(0xFFEF4444),
    glassHighlight: Color(0x18FFFFFF),
    tertiaryCyan: Color(0xFF06B6D4),
    surfaceDark: Color(0xFF121317),
  );

  static const light = VoltTrackPalette(
    isDark: false,
    isGlass: false,
    bg: Color(0xFFF8F9FB),
    cardBg: Color(0xFFFFFFFF),
    cardElevated: Color(0xFFF1F3F6),
    borderColor: Color(0xFFE5E7EB),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF94A3B8),
    neonTeal: Color(0xFF0D9488),
    primaryTeal: Color(0xFF0F766E),
    solarAmber: Color(0xFFD97706),
    greenPositive: Color(0xFF059669),
    redNegative: Color(0xFFDC2626),
    glassHighlight: Color(0x30FFFFFF),
    tertiaryCyan: Color(0xFF0284C7),
    surfaceDark: Color(0xFFF1F5F9),
  );

  static const glass = VoltTrackPalette(
    isDark: true,
    isGlass: true,
    bg: Color(0xFF060810),
    cardBg: Color(0x1A1E293B),
    cardElevated: Color(0x30334155),
    borderColor: Color(0x33FFFFFF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFCBD5E1),
    textMuted: Color(0xFF94A3B8),
    neonTeal: Color(0xFF2DD4BF),
    primaryTeal: Color(0xFF14B8A6),
    solarAmber: Color(0xFFFBBF24),
    greenPositive: Color(0xFF34D399),
    redNegative: Color(0xFFF87171),
    glassHighlight: Color(0x55FFFFFF),
    tertiaryCyan: Color(0xFF38BDF8),
    surfaceDark: Color(0x33121317),
  );
}

class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController._();
  ThemeController._();

  static const _storage = FlutterSecureStorage();
  static const _key = 'volttrack_theme_mode';

  AppThemeType _themeType = AppThemeType.dark;
  AppThemeType get themeType => _themeType;

  ThemeMode get themeMode => _themeType == AppThemeType.light ? ThemeMode.light : ThemeMode.dark;
  bool get isDark => _themeType != AppThemeType.light;
  bool get isGlass => _themeType == AppThemeType.glass;

  VoltTrackPalette get palette {
    switch (_themeType) {
      case AppThemeType.glass:
        return VoltTrackPalette.glass;
      case AppThemeType.light:
        return VoltTrackPalette.light;
      case AppThemeType.dark:
        return VoltTrackPalette.dark;
    }
  }

  Future<void> init() async {
    try {
      final saved = await _storage.read(key: _key);
      if (saved == 'glass') {
        _themeType = AppThemeType.glass;
      } else if (saved == 'light') {
        _themeType = AppThemeType.light;
      } else {
        _themeType = AppThemeType.dark;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggle() async {
    HapticFeedback.lightImpact();
    if (_themeType == AppThemeType.dark) {
      await setThemeType(AppThemeType.light);
    } else if (_themeType == AppThemeType.light) {
      await setThemeType(AppThemeType.glass);
    } else {
      await setThemeType(AppThemeType.dark);
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    await setThemeType(mode == ThemeMode.light ? AppThemeType.light : AppThemeType.dark);
  }

  Future<void> setThemeType(AppThemeType type) async {
    if (_themeType == type) return;
    HapticFeedback.selectionClick();
    _themeType = type;
    notifyListeners();
    try {
      await _storage.write(key: _key, value: type.name);
    } catch (_) {}
  }
}

class AppColors {
  AppColors._();
  static VoltTrackPalette of(BuildContext context) {
    return ThemeController.instance.palette;
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    const p = VoltTrackPalette.dark;
    final base = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData.dark().copyWith(
      textTheme: base,
      colorScheme: ColorScheme.dark(
        primary: p.primaryTeal,
        onPrimary: Colors.white,
        secondary: p.solarAmber,
        onSecondary: Colors.black,
        surface: p.cardBg,
        onSurface: p.textPrimary,
        outline: p.borderColor,
        surfaceContainerLowest: p.bg,
        error: p.redNegative,
      ),
      scaffoldBackgroundColor: p.bg,
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: p.textPrimary,
          letterSpacing: -0.3,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: p.cardBg,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.borderColor, width: 0.8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.cardElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(fontSize: 13.5, color: p.textMuted),
        labelStyle: GoogleFonts.inter(fontSize: 13.5, color: p.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.borderColor, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.neonTeal, width: 1.5),
        ),
        prefixIconColor: p.textSecondary,
      ),
    );
  }

  static ThemeData get lightTheme {
    const p = VoltTrackPalette.light;
    final base = GoogleFonts.interTextTheme(ThemeData.light().textTheme);

    return ThemeData.light().copyWith(
      textTheme: base,
      colorScheme: ColorScheme.light(
        primary: p.primaryTeal,
        onPrimary: Colors.white,
        secondary: p.solarAmber,
        onSecondary: Colors.white,
        surface: p.cardBg,
        onSurface: p.textPrimary,
        outline: p.borderColor,
        surfaceContainerLowest: p.bg,
        error: p.redNegative,
      ),
      scaffoldBackgroundColor: p.bg,
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: p.textPrimary,
          letterSpacing: -0.3,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: p.cardBg,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.borderColor, width: 0.8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.cardElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(fontSize: 13.5, color: p.textMuted),
        labelStyle: GoogleFonts.inter(fontSize: 13.5, color: p.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.borderColor, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.primaryTeal, width: 1.5),
        ),
        prefixIconColor: p.textSecondary,
      ),
    );
  }
}

/// Animated Theme Toggle button with Emil Kowalski spring micro-interaction
class ThemeToggleSwitch extends StatelessWidget {
  const ThemeToggleSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final isDark = ThemeController.instance.isDark;

        return ScaleOnPress(
          pressedScale: 0.88,
          onTap: () => ThemeController.instance.toggle(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: kEaseOutCubic,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF162032) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF1E2A3A)
                    : const Color(0xFFCBD5E1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => RotationTransition(
                turns: Tween<double>(begin: 0.75, end: 1.0).animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                key: ValueKey(isDark),
                size: 19,
                color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B),
              ),
            ),
          ),
        );
      },
    );
  }
}
