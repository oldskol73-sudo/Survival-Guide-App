// The line-drawn mountain mark used on the home cards. Drawn in code so it scales and needs no asset.

import 'package:flutter/material.dart';

import '../core/theme.dart';

class MountainLogo extends StatelessWidget {
  const MountainLogo({super.key, this.size = 48, this.color = AppTheme.accent});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CustomPaint(size: Size(size * 1.5, size), painter: _MountainPainter(color)),
      );
}

class _MountainPainter extends CustomPainter {
  _MountainPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    Offset p(double x, double y) => Offset(x * s.width, y * s.height);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.height * 0.06
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;

    // Main ridge and the smaller shoulder to the right.
    final ridge = Path()
      ..moveTo(p(0.02, 0.9).dx, p(0.02, 0.9).dy)
      ..lineTo(p(0.2, 0.62).dx, p(0.2, 0.62).dy)
      ..lineTo(p(0.3, 0.7).dx, p(0.3, 0.7).dy)
      ..lineTo(p(0.5, 0.08).dx, p(0.5, 0.08).dy)
      ..lineTo(p(0.62, 0.42).dx, p(0.62, 0.42).dy)
      ..lineTo(p(0.7, 0.34).dx, p(0.7, 0.34).dy)
      ..lineTo(p(0.98, 0.9).dx, p(0.98, 0.9).dy);
    canvas.drawPath(ridge, stroke);

    // Snow cap and rock hatching under the peak.
    final cap = Path()
      ..moveTo(p(0.43, 0.3).dx, p(0.43, 0.3).dy)
      ..lineTo(p(0.5, 0.08).dx, p(0.5, 0.08).dy)
      ..lineTo(p(0.57, 0.3).dx, p(0.57, 0.3).dy)
      ..lineTo(p(0.52, 0.25).dx, p(0.52, 0.25).dy)
      ..lineTo(p(0.48, 0.32).dx, p(0.48, 0.32).dy)
      ..close();
    canvas.drawPath(cap, fill);
    for (final h in const [
      [0.3, 0.8, 0.4, 0.55],
      [0.38, 0.88, 0.47, 0.6],
      [0.5, 0.9, 0.56, 0.62],
      [0.62, 0.88, 0.7, 0.55],
      [0.2, 0.86, 0.27, 0.72],
      [0.78, 0.84, 0.84, 0.66],
    ]) {
      canvas.drawLine(p(h[0], h[1]), p(h[2], h[3]), stroke..strokeWidth = s.height * 0.035);
    }
  }

  @override
  bool shouldRepaint(_MountainPainter old) => old.color != color;
}
