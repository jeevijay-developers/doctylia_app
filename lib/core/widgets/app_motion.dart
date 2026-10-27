import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Turns screen motion (entrances, count-ups, chart reveals) on or off for
/// a subtree. Off by default — a screen opts in by wrapping its loaded
/// content — and always off when the device asks to reduce motion.
class AppMotion extends InheritedWidget {
  const AppMotion({required this.enabled, required super.child, super.key});

  final bool enabled;

  static bool of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppMotion>();
    return (scope?.enabled ?? false) &&
        !MediaQuery.disableAnimationsOf(context);
  }

  @override
  bool updateShouldNotify(AppMotion oldWidget) => oldWidget.enabled != enabled;
}

/// Staggered entrance: fades in while sliding from [offset] (a fraction of
/// the child's size) and scaling up from [scale], starting [delay] +
/// [index] × [step] after mount.
///
/// Whether to animate is decided once, at mount ([enabled] and [AppMotion]
/// at that moment), so rebuilds never restart or cut short an entrance and
/// lists can skip items that already played by passing `enabled: false`.
class AppEntrance extends StatefulWidget {
  const AppEntrance({
    required this.index,
    required this.child,
    this.step = const Duration(milliseconds: 70),
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.12),
    this.scale = 0.97,
    this.curve = Curves.easeOutCubic,
    this.enabled = true,
    super.key,
  });

  final int index;
  final Widget child;
  final Duration step;

  /// Extra wait before the staggered start (e.g. after a parent entrance).
  final Duration delay;
  final Offset offset;
  final double scale;
  final Curve curve;
  final bool enabled;

  @override
  State<AppEntrance> createState() => _AppEntranceState();
}

class _AppEntranceState extends State<AppEntrance> {
  bool? _animate;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate ??= widget.enabled && AppMotion.of(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!_animate!) return widget.child;
    // The stagger is an effect delay (part of the controller's timeline),
    // not Animate's own `delay`: that one waits on an uncancellable timer
    // with no frames scheduled, which outlives quickly-disposed items.
    final delay = widget.delay + widget.step * widget.index;
    return widget.child
        .animate()
        .fadeIn(delay: delay, duration: 380.ms, curve: Curves.easeOut)
        .slide(
          delay: delay,
          begin: widget.offset,
          end: Offset.zero,
          duration: 480.ms,
          curve: Curves.easeOutCubic,
        )
        .scaleXY(
          delay: delay,
          begin: widget.scale,
          end: 1,
          duration: 520.ms,
          curve: widget.curve,
        );
  }
}

/// A number that counts up from 0 on first show, and eases between values
/// when the data refreshes. [format] renders each frame's value.
class AppCountUp extends StatelessWidget {
  const AppCountUp({
    required this.value,
    required this.format,
    this.style,
    this.maxLines = 1,
    this.overflow,
    this.delay = Duration.zero,
    super.key,
  });

  final double value;
  final String Function(double value) format;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow? overflow;

  /// Lets the count start once its card has mostly faded in.
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    Text text(double v) =>
        Text(format(v), maxLines: maxLines, overflow: overflow, style: style);
    if (!AppMotion.of(context)) return text(value);
    return _DelayedCount(delay: delay, value: value, builder: text);
  }
}

class _DelayedCount extends StatefulWidget {
  const _DelayedCount({
    required this.delay,
    required this.value,
    required this.builder,
  });

  final Duration delay;
  final double value;
  final Widget Function(double value) builder;

  @override
  State<_DelayedCount> createState() => _DelayedCountState();
}

class _DelayedCountState extends State<_DelayedCount> {
  bool _started = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () => setState(() => _started = true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _started ? widget.value : 0),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => widget.builder(v),
    );
  }
}

/// Reveals its child left → right (for sparklines/charts) on first show.
class AppReveal extends StatelessWidget {
  const AppReveal({required this.child, this.delay = Duration.zero, super.key});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (!AppMotion.of(context)) return child;
    return child
        .animate()
        .custom(
          delay: delay,
          duration: 900.ms,
          curve: Curves.easeInOutCubic,
          // Unclipped once done, so chart tooltips can overflow the box.
          builder: (context, t, child) => t >= 1
              ? child
              : ClipRect(clipper: _RevealClipper(t), child: child),
        );
  }
}

class _RevealClipper extends CustomClipper<Rect> {
  const _RevealClipper(this.progress);

  final double progress;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, -8, size.width * progress, size.height + 16);

  @override
  bool shouldReclip(_RevealClipper oldClipper) =>
      oldClipper.progress != progress;
}

/// Dips its child to 98% while pressed. Wire [builder]'s callback to an
/// InkWell's `onHighlightChanged`. Skipped under reduce-motion.
class AppPressScale extends StatefulWidget {
  const AppPressScale({required this.builder, super.key});

  final Widget Function(ValueChanged<bool> onHighlight) builder;

  @override
  State<AppPressScale> createState() => _AppPressScaleState();
}

class _AppPressScaleState extends State<AppPressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final child = widget.builder((pressed) {
      if (pressed != _pressed) setState(() => _pressed = pressed);
    });
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: child,
    );
  }
}
