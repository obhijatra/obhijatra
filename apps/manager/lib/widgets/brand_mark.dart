import 'package:flutter/material.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// The Obhijatra app icon: a flag on a mast over a river bank, white on
/// Deep Monsoon. Drawn from the approved design's SVG (72 x 72).
class BrandMark extends StatelessWidget {
  /// Creates the mark at [size] logical pixels.
  const BrandMark({this.size = 28, super.key});

  /// Width and height.
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _BrandPainter(palette.surfaceBrand, palette.textOnBrand),
      ),
    );
  }
}

class _BrandPainter extends CustomPainter {
  const _BrandPainter(this.ground, this.mark);

  final Color ground;
  final Color mark;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 72;
    canvas.scale(scale);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 72, 72),
        const Radius.circular(20),
      ),
      Paint()..color = ground,
    );
    canvas.translate(13, 13.5);
    canvas.scale(0.9167);
    final paint = Paint()..color = mark;
    final bank = Path()
      ..moveTo(6, 42)
      ..cubicTo(7, 34, 27, 37.5, 29, 31)
      ..lineTo(32.5, 31)
      ..cubicTo(32.5, 39, 19, 37, 18.5, 42)
      ..close();
    canvas.drawPath(bank, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(29, 7, 3.5, 24),
        const Radius.circular(1.75),
      ),
      paint,
    );
    final flag = Path()
      ..moveTo(32.5, 8)
      ..lineTo(44, 12.75)
      ..lineTo(32.5, 17.5)
      ..close();
    canvas.drawPath(flag, paint);
  }

  @override
  bool shouldRepaint(_BrandPainter old) =>
      old.ground != ground || old.mark != mark;
}
