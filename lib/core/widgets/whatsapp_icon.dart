import 'package:flutter/material.dart';

/// WhatsApp brand glyph, ported from the web `WhatsAppIcon` SVG
/// (512×512 viewBox) so the app needs no SVG dependency.
class WhatsAppIcon extends StatelessWidget {
  const WhatsAppIcon({this.size = 18, this.withBackground = true, super.key});

  final double size;

  /// When false only the white bubble is drawn, for use on a green button.
  final bool withBackground;

  static const brandColor = Color(0xFF25D366);

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'WhatsApp',
    child: CustomPaint(
      size: Size.square(size),
      painter: _WhatsAppPainter(withBackground: withBackground),
    ),
  );
}

class _WhatsAppPainter extends CustomPainter {
  const _WhatsAppPainter({required this.withBackground});

  final bool withBackground;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 512, size.height / 512);
    final green = Paint()..color = WhatsAppIcon.brandColor;
    final white = Paint()..color = Colors.white;

    if (withBackground) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 512, 512),
          const Radius.circular(77),
        ),
        green,
      );
    }

    // Speech bubble: M123 393 l14-65 a138 138 0 1 1 50 47 z
    final bubble = Path()
      ..moveTo(123, 393)
      ..relativeLineTo(14, -65)
      ..relativeArcToPoint(
        const Offset(50, 47),
        radius: const Radius.circular(138),
        largeArc: true,
      )
      ..close();
    canvas.drawPath(
      bubble,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..strokeJoin = StrokeJoin.round,
    );

    // Handset.
    final handset = Path()
      ..moveTo(308, 273)
      ..relativeCubicTo(-3, -2, -6, -3, -9, 1)
      ..relativeLineTo(-12, 16)
      ..relativeCubicTo(-3, 2, -5, 3, -9, 1)
      ..relativeCubicTo(-15, -8, -36, -17, -54, -47)
      ..relativeCubicTo(-1, -4, 1, -6, 3, -8)
      ..relativeLineTo(9, -14)
      ..relativeCubicTo(2, -2, 1, -4, 0, -6)
      ..relativeLineTo(-12, -29)
      ..relativeCubicTo(-3, -8, -6, -7, -9, -7)
      ..relativeLineTo(-8, 0)
      ..relativeCubicTo(-2, 0, -6, 1, -10, 5)
      ..relativeCubicTo(-22, 22, -13, 53, 3, 73)
      ..relativeCubicTo(3, 4, 23, 40, 66, 59)
      ..relativeCubicTo(32, 14, 39, 12, 48, 10)
      ..relativeCubicTo(11, -1, 22, -10, 27, -19)
      ..relativeCubicTo(1, -3, 6, -16, 2, -18)
      ..close();
    canvas.drawPath(handset, white);
  }

  @override
  bool shouldRepaint(_WhatsAppPainter oldDelegate) =>
      oldDelegate.withBackground != withBackground;
}
