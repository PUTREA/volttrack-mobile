import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/auth_service.dart';
import 'services/api_client.dart';
import 'config.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';

import 'theme/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.init();
  runApp(const VoltTrackApp());
}

// ─────────────────────────────────────────────────────────────
// DESIGN TOKENS — Single source of truth for dark color system.
// Emil: "Good defaults matter more than options."
// ─────────────────────────────────────────────────────────────
const kDarkBg = Color(0xFF0A0F1E);
const kCardBg = Color(0xFF111827);
const kCardBgElevated = Color(0xFF161D2E);
const kBorderColor = Color(0xFF1E2A3A);
const kPrimaryTeal = Color(0xFF0F766E);
const kNeonTeal = Color(0xFF14F0D0);
const kSolarAmber = Color(0xFFFBBF24);
const kTextPrimary = Color(0xFFF1F5F9);
const kTextSecondary = Color(0xFF94A3B8);
const kTextMuted = Color(0xFF475569);
const kGreenPositive = Color(0xFF10B981);
const kRedNegative = Color(0xFFEF4444);

class VoltTrackApp extends StatelessWidget {
  const VoltTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'VoltTrack',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeController.instance.themeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: const _Gate(),
        );
      },
    );
  }
}

/// Determines the initial screen based on token presence.
class _Gate extends StatefulWidget {
  const _Gate();

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> with SingleTickerProviderStateMixin {
  final _auth = AuthService();
  bool _loading = true;
  bool _loggedIn = false;
  bool _hasSeenOnboarding = false;
  late final AnimationController _splashCtrl;
  late final Animation<double> _splashOpacity;
  late final Animation<double> _splashScale;

  @override
  void initState() {
    super.initState();
    _splashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _splashOpacity = CurvedAnimation(
      parent: _splashCtrl,
      curve: const Cubic(0.23, 1, 0.32, 1),
    );
    _splashScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _splashCtrl, curve: const Cubic(0.16, 1, 0.3, 1)),
    );
    _splashCtrl.forward();
    _check();
  }

  @override
  void dispose() {
    _splashCtrl.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    try {
      final token = await ApiClient.instance.token;
      if (token == null) {
        await _auth.login(AppConfig.demoEmail, AppConfig.demoPassword);
      }
      final loggedIn = await _auth
          .isLoggedIn()
          .timeout(const Duration(milliseconds: 1500), onTimeout: () => false);
      if (!mounted) return;
      setState(() {
        _hasSeenOnboarding = true;
        _loggedIn = loggedIn;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasSeenOnboarding = true;
        _loggedIn = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: kDarkBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated logo — spring scale from 0.6 → 1.0
              ScaleTransition(
                scale: _splashScale,
                child: FadeTransition(
                  opacity: _splashOpacity,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kPrimaryTeal, Color(0xFF0D9488)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: kPrimaryTeal.withValues(alpha: 0.45),
                          blurRadius: 28,
                          spreadRadius: -4,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: kNeonTeal.withValues(alpha: 0.15),
                          blurRadius: 48,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.bolt, size: 52, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FadeTransition(
                opacity: _splashOpacity,
                child: Text(
                  'VoltTrack',
                  style: GoogleFonts.inter(
                    color: kTextPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              FadeTransition(
                opacity: _splashOpacity,
                child: Text(
                  'Smart Solar Energy Platform',
                  style: GoogleFonts.inter(
                    color: kTextSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kNeonTeal.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        if (!_hasSeenOnboarding) {
          return const OnboardingScreen();
        }
        return _loggedIn ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
