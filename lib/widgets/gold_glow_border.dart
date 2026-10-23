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
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: _GlowPainter(AppColors.isDark)),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter(this.isDark);

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    // Strokes sit exactly on the screen edge and are heavily blurred, so
    // only their inner half shows: light that fades softly inward, with no
    // hard line or flat band.
    final rect = Offset.zero & size;
    canvas.clipRect(rect);
    final strength = isDark ? 1.0 : 0.7;

    // Wide haze in the main gold.
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..color = AppColors.accent.withOpacity(0.55 * strength)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // Softer, brighter core in the lighter gold.
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = AppColors.accentLight.withOpacity(0.45 * strength)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) => old.isDark != isDark;
}
