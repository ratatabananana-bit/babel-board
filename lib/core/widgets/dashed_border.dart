import 'package:flutter/material.dart';

/// Paints a dashed rounded-rectangle border around its child.
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.color,
    required this.child,
    this.radius = 12,
    this.width = 2,
    this.dash = 6,
    this.gap = 4,
  });

  final Color color;
  final Widget child;
  final double radius, width, dash, gap;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(foregroundPainter: _DashPainter(color, radius, width, dash, gap), child: child);
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color, this.radius, this.width, this.dash, this.gap);
  final Color color;
  final double radius, width, dash, gap;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius((Offset.zero & size).deflate(width / 2), Radius.circular(radius));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color || old.radius != radius || old.width != width;
}
