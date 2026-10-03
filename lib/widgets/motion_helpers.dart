import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// CUSTOM EASING CURVES — Emil Kowalski standard curves
// Never use linear or the built-in weak easings for UI.
// ─────────────────────────────────────────────────────────────

/// Strong ease-out: starts fast, perfect for elements entering the screen.
const Curve kEaseOutStrong = Cubic(0.23, 1, 0.32, 1);

/// Strong ease-in-out: for elements moving across the screen.
const Curve kEaseInOutStrong = Cubic(0.77, 0, 0.175, 1);

/// iOS-style drawer/sheet curve (from Ionic Framework).
const Curve kDrawerCurve = Cubic(0.32, 0.72, 0, 1);

/// Snappy ease-out for press feedback and small UI interactions.
const Curve kEaseOutCubic = Cubic(0.33, 1, 0.68, 1);

// ─────────────────────────────────────────────────────────────
// _ScaleOnPress — Universal press feedback widget
// Emil: "Buttons must feel responsive to press."
// scale: 0.97 in 120ms easeOutCubic on press, restore on release.
// ─────────────────────────────────────────────────────────────

class ScaleOnPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final Duration duration;

  const ScaleOnPress({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
    this.duration = const Duration(milliseconds: 120),
  });

  @override
  State<ScaleOnPress> createState() => _ScaleOnPressState();
}

class _ScaleOnPressState extends State<ScaleOnPress> {
  bool _pressed = false;

  void _onTapDown(TapDownDetails _) => setState(() => _pressed = true);

  void _onTapUp(TapUpDetails _) {
    setState(() => _pressed = false);
    widget.onTap?.call();
  }

  void _onTapCancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: widget.duration,
        curve: kEaseOutCubic,
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// StaggerItem — Delayed entrance animation for list items
// Emil: "Keep stagger delays short (30-80ms between items)."
// Each item fades + slides up from 12px below.
// ─────────────────────────────────────────────────────────────

class StaggerItem extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double slideOffset;

  const StaggerItem({
    super.key,
    required this.child,
    required this.delay,
    this.duration = const Duration(milliseconds: 340),
    this.slideOffset = 12.0,
  });

  @override
  State<StaggerItem> createState() => _StaggerItemState();
}

class _StaggerItemState extends State<StaggerItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _ctrl, curve: kEaseOutCubic);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.slideOffset / 200),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: kEaseOutStrong));

    // Respect reduced motion
    final mediaQuery = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    if (mediaQuery.reduceMotion) {
      _ctrl.value = 1.0;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect system reduced motion setting
    if (MediaQuery.of(context).disableAnimations) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FadeSlideIn — Single element mount entrance animation
// Emil: "Nothing in the real world appears from nothing."
// Use for hero elements, cards, or any single element that mounts.
// ─────────────────────────────────────────────────────────────

class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double slideOffset;
  final Axis axis;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 500),
    this.slideOffset = 20.0,
    this.axis = Axis.vertical,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _ctrl, curve: kEaseOutCubic);

    final dy = widget.axis == Axis.vertical ? widget.slideOffset / 200 : 0.0;
    final dx = widget.axis == Axis.horizontal ? widget.slideOffset / 200 : 0.0;
    _slide = Tween<Offset>(
      begin: Offset(dx, dy),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: kEaseOutStrong));

    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AnimatedNumber — Smooth number ticker
// Emil: "A faster-spinning spinner makes the app feel like it loads
// faster." Numbers that jump feel broken; tickers feel like instruments.
// ─────────────────────────────────────────────────────────────

class AnimatedNumber extends StatelessWidget {
  final double value;
  final Duration duration;
  final TextStyle? style;
  final String Function(double value) formatter;
  final Curve curve;

  const AnimatedNumber({
    super.key,
    required this.value,
    required this.formatter,
    this.duration = const Duration(milliseconds: 700),
    this.style,
    this.curve = kEaseInOutStrong,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value),
      duration: duration,
      curve: curve,
      builder: (_, v, child) => Text(
        formatter(v),
        style: style,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GlowContainer — Dark card with optional neon glow shadow
// Used for all premium dark cards throughout VoltTrack.
// ─────────────────────────────────────────────────────────────

class GlowContainer extends StatelessWidget {
  final Widget child;
  final Color cardColor;
  final Color borderColor;
  final Color? glowColor;
  final double glowIntensity;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const GlowContainer({
    super.key,
    required this.child,
    this.cardColor = const Color(0xFF111827),
    this.borderColor = const Color(0xFF1E2A3A),
    this.glowColor,
    this.glowIntensity = 0.12,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final glow = glowColor ?? const Color(0xFF0F766E);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: glowIntensity),
            blurRadius: 20,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// StarfieldPainter — Subtle dark background particle effect
// Used on login screen to evoke "energy / night sky" context.
// Static (no animation) for performance.
// ─────────────────────────────────────────────────────────────

class StarfieldPainter extends CustomPainter {
  final int seed;
  StarfieldPainter({this.seed = 42});

  @override
  void paint(Canvas canvas, Size size) {
    // Deterministic pseudo-random star positions
    final paint = Paint()..style = PaintingStyle.fill;
    var r = seed;
    for (int i = 0; i < 80; i++) {
      r = (r * 1103515245 + 12345) & 0x7fffffff;
      final x = (r % 10000) / 10000.0 * size.width;
      r = (r * 1103515245 + 12345) & 0x7fffffff;
      final y = (r % 10000) / 10000.0 * size.height;
      r = (r * 1103515245 + 12345) & 0x7fffffff;
      final radius = 0.5 + (r % 100) / 100.0 * 1.2;
      r = (r * 1103515245 + 12345) & 0x7fffffff;
      final alpha = 0.15 + (r % 100) / 100.0 * 0.45;
      paint.color = Color.fromRGBO(180, 220, 255, alpha);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
    // A few slightly larger, teal-tinted "energy nodes"
    for (int i = 0; i < 12; i++) {
      r = (r * 1103515245 + 12345) & 0x7fffffff;
      final x = (r % 10000) / 10000.0 * size.width;
      r = (r * 1103515245 + 12345) & 0x7fffffff;
      final y = (r % 10000) / 10000.0 * size.height;
      r = (r * 1103515245 + 12345) & 0x7fffffff;
      final radius = 1.0 + (r % 100) / 100.0 * 1.5;
      paint
        ..color = const Color(0xFF14F0D0).withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(x, y), radius, paint);
      paint.maskFilter = null;
    }
  }

  @override
  bool shouldRepaint(StarfieldPainter old) => old.seed != seed;
}
