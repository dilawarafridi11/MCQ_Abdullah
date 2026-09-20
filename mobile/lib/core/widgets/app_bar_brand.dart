import 'package:flutter/material.dart';

/// Compact Hayat Foam brand mark for AppBar leading / titles.
class AppBarBrand extends StatelessWidget {
  const AppBarBrand({super.key, this.size = 30, this.showText = true});

  final double size;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.28),
          child: Image.asset(
            'lib/images/hayatlogo.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 8),
          Text(
            'MCQ',
            style: TextStyle(
              fontSize: size * 0.55,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ],
    );
  }
}
