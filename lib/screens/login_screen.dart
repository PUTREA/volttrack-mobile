import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config.dart';
import '../services/auth_service.dart';
import '../widgets/motion_helpers.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();

  bool _registerMode = false;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    String? err;
    if (_registerMode) {
      err = await _auth.register(
        _fullName.text.trim(),
        _email.text.trim(),
        _password.text,
      );
      err ??= await _auth.login(_email.text.trim(), _password.text);
    } else {
      err = await _auth.login(_email.text.trim(), _password.text);
    }

    if (!mounted) return;
    setState(() => _busy = false);

    if (err == null) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, animation, secondaryAnimation) => const HomeScreen(),
          transitionsBuilder: (_, animation, secondaryAnimation, child) => FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: kEaseOutStrong),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } else {
      setState(() => _error = err);
    }
  }

  Future<void> _quickDemoLogin() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _registerMode = false;
      _email.text = AppConfig.demoEmail;
      _password.text = AppConfig.demoPassword;
    });
    await _submit();
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0F766E);
    const neonTeal = Color(0xFF14F0D0);
    const amber = Color(0xFFFBBF24);
    const darkBg = Color(0xFF0A0F1E);

    return Scaffold(
      backgroundColor: darkBg,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // ── Layer 1: Dark radial gradient background ──────────────
            Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.3, -0.65),
                radius: 1.3,
                colors: [Color(0xFF0D2137), darkBg],
                stops: [0.0, 1.0],
              ),
            ),
          ),
          // ── Layer 2: Subtle teal glow orb top-right ───────────────
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    teal.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // ── Layer 3: Starfield particles (static CustomPaint) ─────
          Positioned.fill(
            child: CustomPaint(painter: StarfieldPainter(seed: 137)),
          ),
          // ── Layer 4: Bottom amber glow ─────────────────────────────
          Positioned(
            bottom: -60,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    amber.withValues(alpha: 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // ── Layer 5: Main login content ───────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Logo Hero — spring enter from below ──────
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 80),
                        duration: const Duration(milliseconds: 600),
                        child: Center(
                          child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [teal, Color(0xFF0D9488)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: teal.withValues(alpha: 0.40),
                                  blurRadius: 30,
                                  spreadRadius: -4,
                                  offset: const Offset(0, 12),
                                ),
                                BoxShadow(
                                  color: neonTeal.withValues(alpha: 0.12),
                                  blurRadius: 60,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.bolt, size: 52, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      // ── Brand title ──────────────────────────────
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 140),
                        duration: const Duration(milliseconds: 550),
                        child: Column(
                          children: [
                            Text(
                              'VOLTTRACK',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.8,
                                color: const Color(0xFFF1F5F9),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Smart Solar Energy & IoT Platform',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF94A3B8),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // ── Demo quick-access card ───────────────────
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 200),
                        duration: const Duration(milliseconds: 500),
                        child: ScaleOnPress(
                          onTap: _busy ? null : _quickDemoLogin,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  amber.withValues(alpha: 0.12),
                                  amber.withValues(alpha: 0.06),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: amber.withValues(alpha: 0.35),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: amber.withValues(alpha: 0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.bolt, color: amber, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Akses Presentasi Demo',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: amber,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: amber,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '1-TAP',
                                        style: GoogleFonts.inter(
                                          color: Colors.black,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Langsung masuk dengan akun pelanggan demo lengkap dengan data telemetri surya.',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: amber.withValues(alpha: 0.75),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Emil: buttons that can't be pressed should look disabled
                                AnimatedOpacity(
                                  opacity: _busy ? 0.5 : 1.0,
                                  duration: const Duration(milliseconds: 150),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: amber,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: amber.withValues(alpha: 0.25),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: _busy
                                        ? const Center(
                                            child: SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.black,
                                              ),
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.play_arrow_rounded, size: 18, color: Colors.black),
                                              const SizedBox(width: 6),
                                              Text(
                                                '⚡ Masuk Cepat Demo',
                                                style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      // ── Divider ──────────────────────────────────
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 260),
                        child: Row(
                          children: [
                            const Expanded(child: Divider(color: Color(0xFF1E2A3A))),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'atau masuk manual',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ),
                            const Expanded(child: Divider(color: Color(0xFF1E2A3A))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Manual Login Form Card ─────────────────────
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 320),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF111827).withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF1E2A3A), width: 0.8),
                              ),
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    _registerMode ? 'Buat Akun Baru' : 'Masuk ke Akun',
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFF1F5F9),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  // Animated height for register field
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 280),
                                    curve: kEaseOutCubic,
                                    child: _registerMode
                                        ? Column(
                                            children: [
                                              TextField(
                                                controller: _fullName,
                                                style: GoogleFonts.inter(color: const Color(0xFFF1F5F9)),
                                                decoration: const InputDecoration(
                                                  labelText: 'Nama Lengkap',
                                                  prefixIcon: Icon(Icons.person_outline, size: 20),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                            ],
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                  TextField(
                                    controller: _email,
                                    keyboardType: TextInputType.emailAddress,
                                    style: GoogleFonts.inter(color: const Color(0xFFF1F5F9)),
                                    decoration: const InputDecoration(
                                      labelText: 'Email',
                                      prefixIcon: Icon(Icons.email_outlined, size: 20),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _password,
                                    obscureText: _obscurePassword,
                                    style: GoogleFonts.inter(color: const Color(0xFFF1F5F9)),
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                          size: 20,
                                          color: const Color(0xFF94A3B8),
                                        ),
                                        onPressed: () {
                                          HapticFeedback.selectionClick();
                                          setState(() => _obscurePassword = !_obscurePassword);
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Error banner — Emil: opacity transition, not jump-in
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 220),
                                    curve: kEaseOutCubic,
                                    child: _error != null
                                        ? Container(
                                            padding: const EdgeInsets.all(10),
                                            margin: const EdgeInsets.only(bottom: 14),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    _error!,
                                                    style: GoogleFonts.inter(
                                                      color: const Color(0xFFFCA5A5),
                                                      fontSize: 12.5,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),

                                  // Submit button with press feedback
                                  ScaleOnPress(
                                    onTap: _busy ? null : _submit,
                                    child: AnimatedOpacity(
                                      opacity: _busy ? 0.6 : 1.0,
                                      duration: const Duration(milliseconds: 150),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF0F766E).withValues(alpha: 0.35),
                                              blurRadius: 16,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        child: _busy
                                            ? const Center(
                                                child: SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              )
                                            : Center(
                                                child: Text(
                                                  _registerMode ? 'Daftar Sekarang' : 'Masuk',
                                                  style: GoogleFonts.inter(
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 400),
                        child: TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _registerMode = !_registerMode;
                                    _error = null;
                                  }),
                          child: Text(
                            _registerMode
                                ? 'Sudah punya akun? Masuk'
                                : 'Belum punya akun? Daftar akun baru',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF14F0D0),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 450),
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const OnboardingScreen(isTourOnly: true),
                              ),
                            );
                          },
                          icon: const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF94A3B8)),
                          label: Text(
                            'Lihat Tur Aplikasi (Onboarding)',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}
