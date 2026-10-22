import 'package:flutter/material.dart';
import '../theme.dart';

/// Draws a soft gold glow around the edge of the screen, on top of [child].
/// It ignores touches, so the app underneath works as normal.
class GoldGlowBorder extends StatelessWidget {
  const GoldGlowBorder({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: _GlowPainter()),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Wide, faint outer haze in the main gold.
    canvas.drawRect(
      rect.deflate(2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = AppColors.accent.withOpacity(0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Tighter, brighter glow in the lighter gold.
    canvas.drawRect(
      rect.deflate(1.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.accentLight.withOpacity(0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Crisp edge line.
    canvas.drawRect(
      rect.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.accentLight,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
