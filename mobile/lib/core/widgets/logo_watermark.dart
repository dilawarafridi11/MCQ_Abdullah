import 'package:flutter/material.dart';

/// Reusable Muallim brand watermark rendered from the app logo asset.
class LogoWatermark extends StatelessWidget {
  const LogoWatermark({
    super.key,
    this.size = 180,
    this.opacity = 0.06,
    this.alignment = Alignment.bottomRight,
    this.padding = EdgeInsets.zero,
  });

  final double size;
  final double opacity;
  final Alignment alignment;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: padding,
          child: Opacity(
            opacity: opacity,
            child: Image.asset(
              'lib/images/hayatlogo.png',
              width: size,
              height: size,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
