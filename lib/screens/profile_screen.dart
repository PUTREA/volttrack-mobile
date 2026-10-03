import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme/theme_controller.dart';
import '../widgets/motion_helpers.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

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

/// Layar Profil Eksekutif & Pusat Keamanan (Executive Edition)
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthService();
  final _data = DataService();
  final _fullName = TextEditingController();
  final _email = TextEditingController();

  Map<String, dynamic>? _user;
  bool _loading = true;
  bool _busy = false;
  String? _message;

  // Preferensi Pengguna
  bool _faceIdEnabled = true;
  bool _notifyGridOutage = true;
  bool _notifyLowBattery = true;
  bool _notifyDailyYield = false;

  @override
  void initState() {
    super.initState();
    ThemeController.instance.addListener(_onThemeChanged);
    _load();
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onThemeChanged);
    _fullName.dispose();
    _email.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final user = await _auth.me();
    if (!mounted) return;
    setState(() {
      _user = user;
      _fullName.text = (user?['full_name'] ?? '').toString();
      _email.text = (user?['email'] ?? '').toString();
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final err = await _data.updateProfile({
      'full_name': _fullName.text.trim(),
      'email': _email.text.trim(),
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = err ?? 'Data profil berhasil diperbarui.';
    });
    if (err == null) {
      HapticFeedback.heavyImpact();
      _load();
    }
  }

  Future<void> _logout() async {
    HapticFeedback.mediumImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCardBgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Keluar dari Akun?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _kTextPrimary, fontSize: 16),
        ),
        content: Text(
          'Anda harus login kembali untuk memantau inverter dan data telemetri.',
          style: GoogleFonts.inter(color: _kTextSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.inter(color: _kTextMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Ya, Keluar',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _replayOnboarding() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OnboardingScreen(isTourOnly: true)),
    );
  }

  void _openWhatsAppConcierge() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F766E),
        content: Row(
          children: [
            const Icon(Icons.chat_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              'Menghubungkan ke WhatsApp Official VoltTrack Concierge...',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: _kNeonTeal.withValues(alpha: 0.8),
          ),
        ),
      );
    }

    final name = _user?['full_name']?.toString() ?? 'Pengguna';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final isGlass = ThemeController.instance.isGlass;

    return RefreshIndicator(
      onRefresh: () async => _load(),
      color: _kNeonTeal,
      backgroundColor: _kCardBg,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // ==========================================
          // 👤 HEADER PROFIL CARD
          // ==========================================
          StaggerItem(
            delay: const Duration(milliseconds: 0),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isGlass ? const Color(0xFF1E293B).withValues(alpha: 0.4) : _kCardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isGlass ? Colors.white.withValues(alpha: 0.2) : _kBorderColor,
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: ThemeController.instance.isDark ? 0.25 : 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_kPrimaryTeal, const Color(0xFF0D9488)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _kNeonTeal.withValues(alpha: 0.35),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _user?['email']?.toString() ?? '-',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _kTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF34D399)),
                        const SizedBox(width: 6),
                        Text(
                          'Pelanggan Terdaftar · Clean Energy VIP',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF34D399),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ==========================================
          // 🎨 THEME & APPEARANCE CARD
          // ==========================================
          StaggerItem(
            delay: const Duration(milliseconds: 30),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isGlass ? const Color(0xFF1E293B).withValues(alpha: 0.4) : _kCardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isGlass ? Colors.white.withValues(alpha: 0.2) : _kBorderColor,
                  width: 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _kNeonTeal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.palette_outlined, size: 20, color: _kNeonTeal),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tampilan & Tema Visual',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: _kTextPrimary,
                            ),
                          ),
                          Text(
                            'Pilih mode visual sesuai kenyamanan mata',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: _kTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListenableBuilder(
                    listenable: ThemeController.instance,
                    builder: (context, _) {
                      final currentType = ThemeController.instance.themeType;
                      return Row(
                        children: [
                          Expanded(
                            child: _buildProfileThemeBtn(
                              label: 'Gelap',
                              icon: Icons.dark_mode_rounded,
                              active: currentType == AppThemeType.dark,
                              activeColor: const Color(0xFF10B981),
                              type: AppThemeType.dark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildProfileThemeBtn(
                              label: 'Terang',
                              icon: Icons.light_mode_rounded,
                              active: currentType == AppThemeType.light,
                              activeColor: const Color(0xFFF59E0B),
                              type: AppThemeType.light,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildProfileThemeBtn(
                              label: 'Glass',
                              icon: Icons.auto_awesome_rounded,
                              active: currentType == AppThemeType.glass,
                              activeColor: const Color(0xFF2DD4BF),
                              type: AppThemeType.glass,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ==========================================
          // 🛡️ KEAMANAN & BIOMETRIK (FACE ID)
          // ==========================================
          StaggerItem(
            delay: const Duration(milliseconds: 50),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isGlass ? const Color(0xFF1E293B).withValues(alpha: 0.4) : _kCardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isGlass ? Colors.white.withValues(alpha: 0.2) : _kBorderColor,
                  width: 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _kNeonTeal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.security_rounded, size: 20, color: _kNeonTeal),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Keamanan & Akses Aplikasi',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: _kTextPrimary,
                            ),
                          ),
                          Text(
                            'Proteksi data telemetri & ekspor inverter',
                            style: GoogleFonts.inter(fontSize: 11.5, color: _kTextMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Material(
                    type: MaterialType.transparency,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Kunci Aplikasi dengan Face ID / Biometrik',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _kTextPrimary),
                      ),
                      subtitle: Text(
                        'Memerlukan autentikasi biometrik setiap membuka app',
                        style: GoogleFonts.inter(fontSize: 11.5, color: _kTextMuted),
                      ),
                      value: _faceIdEnabled,
                      activeThumbColor: _kNeonTeal,
                      activeTrackColor: _kNeonTeal.withValues(alpha: 0.3),
                      onChanged: (v) {
                        HapticFeedback.selectionClick();
                        setState(() => _faceIdEnabled = v);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ==========================================
          // 📡 STATUS JARINGAN IOT & CLOUD BROKER
          // ==========================================
          StaggerItem(
            delay: const Duration(milliseconds: 70),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isGlass ? const Color(0xFF1E293B).withValues(alpha: 0.4) : _kCardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isGlass ? Colors.white.withValues(alpha: 0.2) : _kBorderColor,
                  width: 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.cloud_sync_rounded, size: 20, color: Color(0xFF34D399)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Koneksi Cloud & IoT Gateway',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: _kTextPrimary,
                            ),
                          ),
                          Text(
                            'Status sinkronisasi perangkat keras real-time',
                            style: GoogleFonts.inter(fontSize: 11.5, color: _kTextMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kCardBgElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kBorderColor),
                    ),
                    child: Column(
                      children: [
                        _iotRow('Broker MQTT', 'mqtt.volttrack.internal (Online)', isSuccess: true),
                        const Divider(height: 14, color: Colors.white12),
                        _iotRow('Latensi Ping', '24 ms (Optimal)', isSuccess: true),
                        const Divider(height: 14, color: Colors.white12),
                        _iotRow('Enkripsi Jalur', 'TLS v1.3 End-to-End'),
                        const Divider(height: 14, color: Colors.white12),
                        _iotRow('Firmware Inverter', 'v1.2.0-STABLE (Terbaru)'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ==========================================
          // 🔔 NOTIFIKASI & PREFERENSI PERINGATAN
          // ==========================================
          StaggerItem(
            delay: const Duration(milliseconds: 80),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isGlass ? const Color(0xFF1E293B).withValues(alpha: 0.4) : _kCardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isGlass ? Colors.white.withValues(alpha: 0.2) : _kBorderColor,
                  width: 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _kSolarAmber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.notifications_active_outlined, size: 20, color: _kSolarAmber),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Preferensi Notifikasi',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: _kTextPrimary,
                            ),
                          ),
                          Text(
                            'Peringatan penting kondisi jaringan PLN & baterai',
                            style: GoogleFonts.inter(fontSize: 11.5, color: _kTextMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Material(
                    type: MaterialType.transparency,
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Peringatan Pemadaman PLN (Storm Mode)',
                              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: _kTextPrimary)),
                          value: _notifyGridOutage,
                          activeThumbColor: _kNeonTeal,
                          activeTrackColor: _kNeonTeal.withValues(alpha: 0.3),
                          onChanged: (v) => setState(() => _notifyGridOutage = v),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Baterai ESS Kritis (< 20%)',
                              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: _kTextPrimary)),
                          value: _notifyLowBattery,
                          activeThumbColor: _kNeonTeal,
                          activeTrackColor: _kNeonTeal.withValues(alpha: 0.3),
                          onChanged: (v) => setState(() => _notifyLowBattery = v),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Laporan Ringkasan Hasil Surya Harian',
                              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: _kTextPrimary)),
                          value: _notifyDailyYield,
                          activeThumbColor: _kNeonTeal,
                          activeTrackColor: _kNeonTeal.withValues(alpha: 0.3),
                          onChanged: (v) => setState(() => _notifyDailyYield = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ==========================================
          // 📝 EDIT FORM INFORMASI AKUN
          // ==========================================
          StaggerItem(
            delay: const Duration(milliseconds: 90),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isGlass ? const Color(0xFF1E293B).withValues(alpha: 0.4) : _kCardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isGlass ? Colors.white.withValues(alpha: 0.2) : _kBorderColor,
                  width: 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informasi Akun',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: _kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _fullName,
                    style: GoogleFonts.inter(color: _kTextPrimary, fontSize: 13.5),
                    decoration: InputDecoration(
                      labelText: 'Nama Lengkap',
                      labelStyle: GoogleFonts.inter(color: _kTextMuted, fontSize: 13),
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 20, color: _kNeonTeal),
                      filled: true,
                      fillColor: _kCardBgElevated,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: _kBorderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: _kNeonTeal, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.inter(color: _kTextPrimary, fontSize: 13.5),
                    decoration: InputDecoration(
                      labelText: 'Alamat Email',
                      labelStyle: GoogleFonts.inter(color: _kTextMuted, fontSize: 13),
                      prefixIcon: Icon(Icons.email_outlined, size: 20, color: _kNeonTeal),
                      filled: true,
                      fillColor: _kCardBgElevated,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: _kBorderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: _kNeonTeal, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_message != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: _message!.contains('berhasil')
                            ? const Color(0xFF10B981).withValues(alpha: 0.12)
                            : const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _message!.contains('berhasil')
                              ? const Color(0xFF10B981).withValues(alpha: 0.3)
                              : const Color(0xFFEF4444).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _message!,
                        style: GoogleFonts.inter(
                          color: _message!.contains('berhasil')
                              ? const Color(0xFF34D399)
                              : const Color(0xFFF87171),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ScaleOnPress(
                    onTap: _busy ? null : _save,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_kPrimaryTeal, const Color(0xFF0D9488)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _kPrimaryTeal.withValues(alpha: 0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                'Simpan Perubahan Akun',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ==========================================
          // 🚀 LAYANAN DUKUNGAN & TOUR ONBOARDING
          // ==========================================
          Row(
            children: [
              Expanded(
                child: ScaleOnPress(
                  onTap: _openWhatsAppConcierge,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isGlass ? const Color(0xFF1E293B).withValues(alpha: 0.4) : _kCardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _kBorderColor),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.support_agent_rounded, size: 26, color: Color(0xFF34D399)),
                        const SizedBox(height: 8),
                        Text(
                          'WhatsApp Support',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: _kTextPrimary),
                        ),
                        Text(
                          'Konsultasi Resmi 24/7',
                          style: GoogleFonts.inter(fontSize: 11, color: _kTextMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ScaleOnPress(
                  onTap: _replayOnboarding,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isGlass ? const Color(0xFF1E293B).withValues(alpha: 0.4) : _kCardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _kBorderColor),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.auto_stories_rounded, size: 26, color: _kSolarAmber),
                        const SizedBox(height: 8),
                        Text(
                          'Tour Panduan',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: _kTextPrimary),
                        ),
                        Text(
                          'Fitur Eksekutif App',
                          style: GoogleFonts.inter(fontSize: 11, color: _kTextMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ==========================================
          // 🚪 TOMBOL LOGOUT RESMI
          // ==========================================
          ScaleOnPress(
            onTap: _logout,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFF87171)),
                  const SizedBox(width: 8),
                  Text(
                    'Keluar dari Akun (Logout)',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFF87171),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Info Versi
          Center(
            child: Column(
              children: [
                Text(
                  'VoltTrack Mobile v1.0.0 (Build Executive Demo)',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: _kTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'VoltTrack Energy Ecosystem © 2026',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _kTextMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _iotRow(String label, String value, {bool isSuccess = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11.5, color: _kTextSecondary)),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSuccess ? const Color(0xFF34D399) : _kTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileThemeBtn({
    required String label,
    required IconData icon,
    required bool active,
    required Color activeColor,
    required AppThemeType type,
  }) {
    return ScaleOnPress(
      onTap: () {
        ThemeController.instance.setThemeType(type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: kEaseOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: active
              ? (type == AppThemeType.glass
                  ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                  : (type == AppThemeType.light
                      ? const Color(0xFF0F766E).withValues(alpha: 0.1)
                      : const Color(0xFF1E293B)))
              : _kCardBgElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? activeColor : _kBorderColor,
            width: active ? 1.8 : 0.8,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: active ? activeColor : _kTextMuted,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? _kTextPrimary : _kTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
