import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'dashboard_hero_slider.dart';

/// Very low-opacity Persian carpet inspired geometric overlay.
class CarpetPattern extends StatelessWidget {
  const CarpetPattern({
    super.key,
    this.color = AppColors.gold,
    this.opacity = 0.045,
  });

  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _CarpetPatternPainter(color: color, opacity: opacity),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Full premium backdrop: cream/black gradient + carpet motif + faded logo.
class PremiumBackground extends StatelessWidget {
  const PremiumBackground({
    super.key,
    required this.isDark,
    required this.child,
    this.watermarkSize = 320,
    this.watermarkOpacity = 0.025,
    this.watermarkAlignment,
  });

  final bool isDark;
  final Widget child;
  final double watermarkSize;
  final double watermarkOpacity;

  /// When set, the faded logo is aligned inside the screen (e.g. behind a form)
  /// instead of bleeding off the top-right corner.
  final Alignment? watermarkAlignment;

  Widget _watermark() {
    return IgnorePointer(
      child: Opacity(
        opacity: watermarkOpacity,
        child: Image.asset(
          'lib/images/hayatlogo.png',
          width: watermarkSize,
          height: watermarkSize,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isDark ? AppGradients.bgDark : AppGradients.bg,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CarpetPattern(opacity: isDark ? 0.05 : 0.04),
          if (watermarkAlignment != null)
            Align(alignment: watermarkAlignment!, child: _watermark())
          else
            Positioned(
              top: -watermarkSize * 0.25,
              right: -watermarkSize * 0.35,
              child: _watermark(),
            ),
          child,
        ],
      ),
    );
  }
}

class _CarpetPatternPainter extends CustomPainter {
  _CarpetPatternPainter({required this.color, required this.opacity});

  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height * 0.42);
    final r = math.min(size.width, size.height) * 0.34;

    canvas.drawCircle(center, r, paint);
    canvas.drawCircle(center, r * 0.72, paint);
    canvas.drawCircle(center, r * 0.5, paint);

    final points = <Offset>[];
    for (var i = 0; i < 16; i++) {
      final ang = i * math.pi / 8;
      final rad = i.isEven ? r * 0.6 : r * 0.86;
      points.add(center + Offset(math.cos(ang) * rad, math.sin(ang) * rad));
    }
    final star = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      star.lineTo(p.dx, p.dy);
    }
    star.close();
    canvas.drawPath(star, paint);

    for (var i = 0; i < 8; i++) {
      final ang = i * math.pi / 4 + math.pi / 8;
      final d = center + Offset(math.cos(ang) * r * 0.6, math.sin(ang) * r * 0.6);
      canvas.drawPath(_diamond(d, r * 0.09), paint);
    }

    final inset = 12.0;
    final cornerR = math.min(size.width, size.height) * 0.055;
    for (final c in [
      Offset(inset, inset),
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      Offset(size.width - inset, size.height - inset),
    ]) {
      canvas.drawPath(_diamond(c, cornerR), paint);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4, 4, size.width - 8, size.height - 8),
        const Radius.circular(28),
      ),
      paint,
    );
  }

  Path _diamond(Offset center, double s) {
    return Path()
      ..moveTo(center.dx, center.dy - s)
      ..lineTo(center.dx + s, center.dy)
      ..lineTo(center.dx, center.dy + s)
      ..lineTo(center.dx - s, center.dy)
      ..close();
  }

  @override
  bool shouldRepaint(_CarpetPatternPainter oldDelegate) =>
      oldDelegate.opacity != opacity || oldDelegate.color != color;
}
