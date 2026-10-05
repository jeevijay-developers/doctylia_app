import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Colours used to paint a [Skeleton].
class SkeletonPalette {
  const SkeletonPalette({
    required this.surface,
    required this.surfaceBorder,
    required this.bone,
    required this.innerSurface,
  });

  /// Fill for top-level card surfaces.
  final Color surface;
  final Color surfaceBorder;

  /// Text-line and icon placeholders.
  final Color bone;

  /// Fill for nested surfaces (badges, icon tiles, recessed panels).
  final Color innerSurface;
}

/// Renders [child]'s exact layout as a skeleton: the child is laid out
/// normally — so every size, gap and radius matches the real widgets — but
/// instead of its pixels, each decorated surface, text line and custom
/// painting is drawn as a soft placeholder. Swapping the skeleton for the
/// loaded widgets therefore causes no layout shift.
class Skeleton extends StatefulWidget {
  const Skeleton({
    required this.child,
    required this.palette,
    this.semanticsLabel = 'Loading',
    super.key,
  });

  final Widget child;
  final SkeletonPalette palette;
  final String semanticsLabel;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the platform "reduce motion" setting with a static skeleton.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse
        ..stop()
        ..value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.semanticsLabel,
    child: ExcludeSemantics(
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _pulse.drive(
            Tween<double>(
              begin: 0.55,
              end: 1,
            ).chain(CurveTween(curve: Curves.easeInOut)),
          ),
          child: _SkeletonLayer(palette: widget.palette, child: widget.child),
        ),
      ),
    ),
  );
}

class _SkeletonLayer extends SingleChildRenderObjectWidget {
  const _SkeletonLayer({required this.palette, required super.child});

  final SkeletonPalette palette;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSkeleton(palette);

  @override
  void updateRenderObject(BuildContext context, _RenderSkeleton renderObject) {
    renderObject.palette = palette;
  }
}

class _RenderSkeleton extends RenderProxyBox {
  _RenderSkeleton(this._palette);

  SkeletonPalette _palette;
  set palette(SkeletonPalette value) {
    if (value == _palette) return;
    _palette = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final root = child;
    if (root == null) return;
    final canvas = context.canvas
      ..save()
      ..clipRect(offset & size);
    void visit(RenderObject node, int depth) {
      if (node is RenderOffstage && node.offstage) return;
      var nextDepth = depth;
      if (node is RenderBox && node.hasSize) {
        final rect = MatrixUtils.transformRect(
          node.getTransformTo(this),
          Offset.zero & node.size,
        ).shift(offset);
        if (node is RenderParagraph) {
          _paintText(canvas, node, rect);
          return;
        }
        if (node is RenderDecoratedBox) {
          if (_paintSurface(canvas, node.decoration, rect, depth)) {
            nextDepth++;
          }
        } else if (node is RenderPhysicalShape) {
          _paintBlock(canvas, rect, depth, radius: 10);
          nextDepth++;
        } else if (_isCustomGraphic(node)) {
          _paintBlock(canvas, rect, depth + 1, radius: 10);
          return;
        }
        // Honour the child's clipping so decorations that are clipped in
        // the real UI (e.g. header glows) don't bleed out of their card.
        if (node is RenderClipRect ||
            node is RenderClipRRect ||
            node is RenderClipPath ||
            node is RenderClipOval) {
          canvas
            ..save()
            ..clipRect(rect);
          node.visitChildren((child) => visit(child, nextDepth));
          canvas.restore();
          return;
        }
      }
      node.visitChildren((child) => visit(child, nextDepth));
    }

    visit(root, 0);
    canvas.restore();
  }

  /// Paints a decorated container as a surface. Returns whether it did.
  bool _paintSurface(
    Canvas canvas,
    Decoration decoration,
    Rect rect,
    int depth,
  ) {
    if (decoration is! BoxDecoration) return false;
    // Near-invisible fills (decorative glows, faint tints) are skipped.
    final visible =
        (decoration.color != null && decoration.color!.a >= 0.1) ||
        decoration.gradient != null ||
        decoration.border != null;
    if (!visible || rect.isEmpty) return false;
    final rrect = decoration.shape == BoxShape.circle
        ? RRect.fromRectAndRadius(rect, Radius.circular(rect.shortestSide / 2))
        : (decoration.borderRadius?.resolve(TextDirection.ltr) ??
                  BorderRadius.zero)
              .toRRect(rect);
    canvas.drawRRect(
      rrect,
      Paint()..color = depth == 0 ? _palette.surface : _palette.innerSurface,
    );
    if (depth == 0) {
      canvas.drawRRect(
        rrect.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = _palette.surfaceBorder,
      );
    }
    return true;
  }

  void _paintBlock(
    Canvas canvas,
    Rect rect,
    int depth, {
    required double radius,
  }) {
    if (rect.isEmpty) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()..color = depth == 0 ? _palette.surface : _palette.innerSurface,
    );
  }

  /// One rounded bar per laid-out text line (icons become small squares).
  void _paintText(Canvas canvas, RenderParagraph paragraph, Rect rect) {
    final length = paragraph.text.toPlainText(includeSemanticsLabels: false);
    if (length.isEmpty) return;
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: length.length),
    );
    final scale = paragraph.size.width == 0
        ? 1.0
        : rect.width / paragraph.size.width;
    final paint = Paint()..color = _palette.bone;
    // Merge glyph runs that share a line into one bar.
    final lines = <double, Rect>{};
    for (final box in boxes) {
      final r = box.toRect();
      final key = (r.top * 10).roundToDouble();
      lines[key] = lines[key]?.expandToInclude(r) ?? r;
    }
    for (final line in lines.values) {
      final bar = Rect.fromLTWH(
        rect.left + line.left * scale,
        rect.top + line.top * scale,
        line.width * scale,
        line.height * scale,
      );
      final height = bar.height * 0.62;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: bar.center, width: bar.width, height: height),
          Radius.circular(height / 2.6),
        ),
        paint,
      );
    }
  }

  static bool _isCustomGraphic(RenderObject node) {
    if (node is RenderCustomPaint) {
      // Background painters only: foreground-only painters are overlays
      // such as Material shape borders on ink layers, not content.
      return node.painter != null &&
          node.size.width > 24 &&
          node.size.height > 16;
    }
    // Third-party chart render objects (e.g. fl_chart) paint directly.
    return node is RenderBox &&
        node.hasSize &&
        node.size.width > 24 &&
        node.size.height > 24 &&
        node.runtimeType.toString().contains('Chart');
  }

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      false;
}
