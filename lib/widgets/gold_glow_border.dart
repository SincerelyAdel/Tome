import 'package:flutter/material.dart';
import '../theme.dart';

/// Draws a soft glow around the edge of the screen, gold running into the
/// app icon's teal, on top of [child].
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
    final strength = isDark ? 0.8 : 0.7;

    // Gold at the top left and bottom right, teal in the other corners.
    // On light pages the teal keeps its full strength, so it still shows.
    final tealStrength = isDark ? 1.0 : 1.15;
    Shader sweep(Color gold, Color teal, double alpha) {
      final g = gold.withOpacity(alpha);
      final t = teal.withOpacity((alpha / strength * tealStrength).clamp(0.0, 1.0));
      return SweepGradient(colors: [g, t, g, t, g]).createShader(rect);
    }

    // Wide haze: main gold and teal.
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..shader = sweep(AppColors.accent, AppColors.teal, 0.55 * strength)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // Softer, brighter core in the lighter gold and teal.
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..shader =
            sweep(AppColors.accentLight, AppColors.tealLight, 0.45 * strength)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) => old.isDark != isDark;
}
