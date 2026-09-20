import 'package:flutter/material.dart';

/// A single dashed top border, separating an expanded group's children from
/// each other (reference/thu-chi-spec.md). Deliberately re-implemented here
/// rather than imported from `expense_control`'s own `DashedTopBorder` —
/// features MUST NOT import another feature's presentation internals
/// directly (Constitution Recommended Architecture); this is a small,
/// self-contained painter, not worth promoting to `core/` for one shared
/// visual detail.
class DashedTopBorder extends StatelessWidget {
  const DashedTopBorder({
    super.key,
    required this.child,
    required this.color,
    this.strokeWidth = 1,
    this.dashWidth = 4,
    this.gapWidth = 3,
  });

  final Widget child;
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double gapWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedLinePainter(
        color: color,
        strokeWidth: strokeWidth,
        dashWidth: dashWidth,
        gapWidth: gapWidth,
      ),
      child: child,
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.gapWidth,
  });

  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double gapWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) {
    return color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        dashWidth != oldDelegate.dashWidth ||
        gapWidth != oldDelegate.gapWidth;
  }
}
