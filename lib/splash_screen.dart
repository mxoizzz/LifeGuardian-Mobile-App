import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'features/auth/auth_gate.dart';

class LifeGuardianSplash extends StatefulWidget {
  const LifeGuardianSplash({super.key});

  @override
  State<LifeGuardianSplash> createState() => _LifeGuardianSplashState();
}

class _LifeGuardianSplashState extends State<LifeGuardianSplash>
    with TickerProviderStateMixin {
  static const String _appName = 'LifeGuardian+';
  static const Color _green = Color(0xFF2ECC89);
  static const Color _darkText = Color(0xFF1A1A1A);

  // ── Controllers ──────────────────────────────────────────────────────────
  late AnimationController _lettersCtrl;   // staggered letter drop-in
  late AnimationController _shimmerCtrl;   // green shimmer sweep
  late AnimationController _underlineCtrl; // underline draw
  late AnimationController _plusCtrl;      // "+" elastic pop
  late AnimationController _rippleCtrl;    // expanding ripple ring
  late AnimationController _dotCtrl;       // loading dots
  late AnimationController _exitCtrl;      // exit fade

  // ── Per-letter animations ────────────────────────────────────────────────
  late List<Animation<double>> _letterOpacity;
  late List<Animation<double>> _letterY;

  // ── Other animations ─────────────────────────────────────────────────────
  late Animation<double> _shimmerPos;
  late Animation<double> _underlineW;
  late Animation<double> _plusScale;
  late Animation<double> _rippleRadius;
  late Animation<double> _rippleOpacity;
  late Animation<double> _exitOpacity;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
    ));
    _build();
    _run();
  }

  void _build() {
    final n = _appName.length;

    // ── Letters (total 1100ms): each drops from above with staggered start ─
    _lettersCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _letterOpacity = List.generate(n, (i) {
      final t0 = (i / n) * 0.65;
      final t1 = (t0 + 0.35).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _lettersCtrl,
          curve: Interval(t0, t1, curve: Curves.easeOut),
        ),
      );
    });

    _letterY = List.generate(n, (i) {
      final t0 = (i / n) * 0.65;
      final t1 = (t0 + 0.35).clamp(0.0, 1.0);
      return Tween<double>(begin: -28, end: 0).animate(
        CurvedAnimation(
          parent: _lettersCtrl,
          curve: Interval(t0, t1, curve: Curves.easeOutCubic),
        ),
      );
    });

    // ── Shimmer sweep (800ms) ─────────────────────────────────────────────
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _shimmerPos = Tween<double>(begin: -0.6, end: 1.6).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );

    // ── Underline draw (550ms) ────────────────────────────────────────────
    _underlineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _underlineW = CurvedAnimation(
      parent: _underlineCtrl,
      curve: Curves.easeOut,
    );

    // ── "+" elastic pop (500ms) ───────────────────────────────────────────
    _plusCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _plusScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.7), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.7, end: 0.85), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.05), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 15),
    ]).animate(CurvedAnimation(parent: _plusCtrl, curve: Curves.easeInOut));

    // ── Ripple ring (1600ms, repeats 2×) ─────────────────────────────────
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _rippleRadius = Tween<double>(begin: 0, end: 240).animate(
      CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut),
    );
    _rippleOpacity = Tween<double>(begin: 0.18, end: 0).animate(
      CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeIn),
    );

    // ── Loading dots ──────────────────────────────────────────────────────
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // ── Exit fade (450ms) ─────────────────────────────────────────────────
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _exitOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn),
    );
  }

  Future<void> _run() async {
    // Letters drop in
    await Future.delayed(const Duration(milliseconds: 150));
    _lettersCtrl.forward();

    // First ripple expands from center
    await Future.delayed(const Duration(milliseconds: 100));
    _rippleCtrl.forward();

    // Shimmer sweeps across text
    await Future.delayed(const Duration(milliseconds: 900));
    _shimmerCtrl.forward();

    // Underline draws simultaneously
    _underlineCtrl.forward();

    // "+" pops after shimmer hits it
    await Future.delayed(const Duration(milliseconds: 450));
    _plusCtrl.forward();

    // Loading dots appear
    await Future.delayed(const Duration(milliseconds: 100));
    _dotCtrl.repeat(reverse: true);

    // Second ripple pulse for elegance
    await Future.delayed(const Duration(milliseconds: 400));
    _rippleCtrl.reset();
    _rippleCtrl.forward();

    // Shimmer sweeps one more time
    await Future.delayed(const Duration(milliseconds: 400));
    _shimmerCtrl.reset();
    _shimmerCtrl.forward();

    // Exit
    await Future.delayed(const Duration(milliseconds: 700));
    _dotCtrl.stop();
    _exitCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 450));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const AuthGate(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 450),
        ),
      );
    }
  }

  @override
  void dispose() {
    _lettersCtrl.dispose();
    _shimmerCtrl.dispose();
    _underlineCtrl.dispose();
    _plusCtrl.dispose();
    _rippleCtrl.dispose();
    _dotCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _lettersCtrl, _shimmerCtrl, _underlineCtrl,
          _plusCtrl, _rippleCtrl, _dotCtrl, _exitCtrl,
        ]),
        builder: (ctx, _) {
          return Opacity(
            opacity: _exitOpacity.value,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Expanding ripple ring
                _buildRipple(ctx),

                // Centered text + underline
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildText(),
                      const SizedBox(height: 10),
                      _buildUnderline(),
                      const SizedBox(height: 48),
                      _buildDots(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Ripple ────────────────────────────────────────────────────────────────

  Widget _buildRipple(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    return CustomPaint(
      painter: _RipplePainter(
        center: Offset(sz.width / 2, sz.height / 2),
        radius: _rippleRadius.value,
        opacity: _rippleOpacity.value,
        color: _green,
      ),
    );
  }

  // ── Letter-by-letter text with shimmer ───────────────────────────────────

  Widget _buildText() {
    final chars = _appName.split('');

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (Rect bounds) {
        final p = _shimmerPos.value;
        const w = 0.25; // shimmer highlight half-width
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: [
            (p - w).clamp(0.0, 1.0),
            p.clamp(0.0, 1.0),
            (p + w).clamp(0.0, 1.0),
          ],
          colors: const [_darkText, _green, _darkText],
        ).createShader(bounds);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: List.generate(chars.length, (i) {
          final isPlus = chars[i] == '+';
          Widget letter = Text(
            chars[i],
            style: TextStyle(
              fontSize: isPlus ? 42 : 38,
              fontWeight: FontWeight.w800,
              color: Colors.black, // overridden by ShaderMask
              height: 1,
              letterSpacing: 0.5,
            ),
          );

          if (isPlus) {
            letter = Transform.scale(
              scale: _plusScale.value,
              alignment: Alignment.center,
              child: letter,
            );
          }

          return Opacity(
            opacity: _letterOpacity[i].value,
            child: Transform.translate(
              offset: Offset(0, _letterY[i].value),
              child: letter,
            ),
          );
        }),
      ),
    );
  }

  // ── Animated underline ────────────────────────────────────────────────────

  Widget _buildUnderline() {
    const fullWidth = 272.0;
    return SizedBox(
      width: fullWidth,
      child: Row(
        children: [
          Container(
            width: fullWidth * _underlineW.value,
            height: 2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: const LinearGradient(
                colors: [_green, Color(0xFF1A9B5A)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Loading dots ──────────────────────────────────────────────────────────

  Widget _buildDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final offset = i / 3;
        // Each dot phase-shifted from the controller value
        final t = (_dotCtrl.value - offset + 1) % 1;
        final scale = 0.5 + 0.5 * math.sin(t * math.pi);
        final opacity = (_underlineW.value * 1).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _green.withOpacity(0.3 + 0.7 * scale),
            ),
            transform: Matrix4.identity()
              ..translate(0.0, -4.0 * scale),
          ),
        );
      }),
    );
  }
}

// ── Ripple CustomPainter ──────────────────────────────────────────────────────

class _RipplePainter extends CustomPainter {
  final Offset center;
  final double radius;
  final double opacity;
  final Color color;

  const _RipplePainter({
    required this.center,
    required this.radius,
    required this.opacity,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0 || radius <= 0) return;
    void ring(double r, double op) {
      if (r <= 0) return;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = color.withOpacity(op)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    ring(radius, opacity);
    ring(radius * 0.67, opacity * 0.55);
    ring(radius * 0.38, opacity * 0.25);
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.radius != radius || old.opacity != opacity;
}