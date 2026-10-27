import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Doctylia splash: brand-gradient background, soft glow circles, dot grid,
/// a pulsing logo with an orbiting dashed ring, wordmark + tagline, bouncing
/// dots, a progress bar and a "powered by" footer.
///
/// This widget is visual only. Routing (onboarding / login / role check /
/// dashboard) stays in your router or auth provider, as before.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// One-shot timeline: logo pop, text reveal, progress fill.
  late final AnimationController _intro;

  /// Looping timeline (3.6s): pulse x3, dots x4, orbit ring x1 per cycle.
  late final AnimationController _loop;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _glowOpacity;
  late final Animation<Offset> _brandSlide;
  late final Animation<double> _brandOpacity;
  late final Animation<Offset> _taglineSlide;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _dotsOpacity;
  late final Animation<double> _footerOpacity;
  late final Animation<double> _progress;

  bool _started = false;

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );

    CurvedAnimation interval(double begin, double end, Curve curve) =>
        CurvedAnimation(
          parent: _intro,
          curve: Interval(begin, end, curve: curve),
        );

    _logoScale = Tween<double>(
      begin: 0.3,
      end: 1,
    ).animate(interval(0.0, 0.5, Curves.elasticOut));
    _logoOpacity = interval(0.0, 0.2, Curves.easeOut);
    _glowOpacity = interval(0.15, 0.5, Curves.easeOut);

    _brandOpacity = interval(0.25, 0.6, Curves.easeOut);
    _brandSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(interval(0.25, 0.6, Curves.easeOutCubic));

    _taglineOpacity = interval(0.4, 0.75, Curves.easeOut);
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(interval(0.4, 0.75, Curves.easeOutCubic));

    _dotsOpacity = interval(0.5, 0.8, Curves.easeOut);
    _footerOpacity = interval(0.6, 0.9, Curves.easeOut);
    _progress = CurvedAnimation(parent: _intro, curve: Curves.easeInOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (MediaQuery.disableAnimationsOf(context)) {
      // Reduce-motion: jump to the final frame, no looping animation.
      _intro.value = 1;
    } else {
      _intro.forward();
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _SplashPalette.from(Theme.of(context).colorScheme.primary);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: palette.dark,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Static layers are cached by the RepaintBoundary.
            RepaintBoundary(child: _Background(palette: palette)),
            SafeArea(
              child: Semantics(
                label: 'Doctylia is loading',
                liveRegion: true,
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    _LogoSection(
                      loop: _loop,
                      logoScale: _logoScale,
                      logoOpacity: _logoOpacity,
                      glowOpacity: _glowOpacity,
                      shadowColor: palette.dark,
                    ),
                    const SizedBox(height: 36),
                    FadeTransition(
                      opacity: _brandOpacity,
                      child: SlideTransition(
                        position: _brandSlide,
                        child: const Text(
                          'Doctylia',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FadeTransition(
                      opacity: _taglineOpacity,
                      child: SlideTransition(
                        position: _taglineSlide,
                        child: Text(
                          'Your practice, in your pocket',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(flex: 3),
                    FadeTransition(
                      opacity: _dotsOpacity,
                      child: _LoadingDots(loop: _loop),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: AnimatedBuilder(
                        animation: _progress,
                        builder: (context, _) => ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: _progress.value,
                            minHeight: 3,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.18,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FadeTransition(
                      opacity: _footerOpacity,
                      child: Text(
                        'Powered by Jeevijay Technologies',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PALETTE (derived from the theme's primary color)
// ─────────────────────────────────────────────
class _SplashPalette {
  const _SplashPalette({
    required this.light,
    required this.mid,
    required this.base,
    required this.dark,
  });

  final Color light;
  final Color mid;
  final Color base;
  final Color dark;

  factory _SplashPalette.from(Color primary) {
    final hsl = HSLColor.fromColor(primary);
    Color shift(double delta) =>
        hsl.withLightness((hsl.lightness + delta).clamp(0.06, 0.92)).toColor();

    return _SplashPalette(
      light: shift(0.16),
      mid: shift(0.06),
      base: primary,
      dark: shift(-0.18),
    );
  }
}

// ─────────────────────────────────────────────
// BACKGROUND (gradient + glow circles + dot grid)
// ─────────────────────────────────────────────
class _Background extends StatelessWidget {
  const _Background({required this.palette});

  final _SplashPalette palette;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [palette.light, palette.mid, palette.base, palette.dark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.25, 0.65, 1.0],
            ),
          ),
        ),
        const Positioned(
          top: -100,
          left: -80,
          child: _GlowCircle(size: 320, opacity: 0.09),
        ),
        const Positioned(
          top: 60,
          right: -60,
          child: _GlowCircle(size: 180, opacity: 0.07),
        ),
        const Positioned(
          bottom: 80,
          left: -40,
          child: _GlowCircle(size: 200, opacity: 0.06),
        ),
        const Positioned(
          bottom: -80,
          right: -60,
          child: _GlowCircle(size: 260, opacity: 0.08),
        ),
        CustomPaint(painter: _DotGridPainter(), size: Size.infinite),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..style = PaintingStyle.fill;

    const spacing = 28.0;
    const radius = 1.2;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────
// LOGO SECTION (pulsing halo, orbit ring, logo)
// ─────────────────────────────────────────────
class _LogoSection extends StatelessWidget {
  const _LogoSection({
    required this.loop,
    required this.logoScale,
    required this.logoOpacity,
    required this.glowOpacity,
    required this.shadowColor,
  });

  final AnimationController loop;
  final Animation<double> logoScale;
  final Animation<double> logoOpacity;
  final Animation<double> glowOpacity;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: 180,
        height: 180,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Halo + frosted ring, gently pulsing (3 pulses per loop).
            FadeTransition(
              opacity: glowOpacity,
              child: AnimatedBuilder(
                animation: loop,
                builder: (context, child) {
                  final pulse =
                      1 + 0.06 * math.sin(loop.value * 2 * math.pi * 3);
                  return Transform.scale(scale: pulse, child: child);
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    Container(
                      width: 148,
                      height: 148,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.09),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Orbiting dashed ring + 4 sparkle dots (one rotation per loop).
            FadeTransition(
              opacity: glowOpacity,
              child: AnimatedBuilder(
                animation: loop,
                builder: (context, child) => Transform.rotate(
                  angle: loop.value * 2 * math.pi,
                  child: child,
                ),
                child: const SizedBox(
                  width: 148,
                  height: 148,
                  child: CustomPaint(painter: _OrbitPainter()),
                ),
              ),
            ),

            // Logo on a white disc.
            ScaleTransition(
              scale: logoScale,
              child: FadeTransition(
                opacity: logoOpacity,
                child: Container(
                  width: 106,
                  height: 106,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.20),
                        blurRadius: 28,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: shadowColor.withValues(alpha: 0.30),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  // Icon-only "D" mark: the full logo (with wordmark) is
                  // ~2.8x wider than tall and overflowed this disc.
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Image.asset(
                      'assets/icon/icon.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      excludeFromSemantics: true,
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

/// Dashed ring plus four sparkle dots. Static; the parent rotates it.
class _OrbitPainter extends CustomPainter {
  const _OrbitPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    const dashCount = 16;
    const dashLength = 0.15; // radians
    const step = 2 * math.pi / dashCount;

    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(rect, i * step, dashLength, false, dashPaint);
    }

    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final a = i * (math.pi / 2);
      canvas.drawCircle(
        Offset(
          center.dx + radius * math.cos(a),
          center.dy + radius * math.sin(a),
        ),
        3.5,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────
// LOADING DOTS
// ─────────────────────────────────────────────
class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.loop});

  final AnimationController loop;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: loop,
        builder: (context, _) {
          // 4 bounce cycles per 3.6s loop.
          final t = (loop.value * 4) % 1.0;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final p = ((t - i * 0.18) % 1.0 + 1.0) % 1.0;
              final bounce = p < 0.6 ? math.sin(p / 0.6 * math.pi) : 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Transform.translate(
                  offset: Offset(0, -8 * bounce),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(
                        alpha: 0.40 + 0.60 * bounce,
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
