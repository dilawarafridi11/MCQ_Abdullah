import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 72,
    this.dark = false,
    this.imagePath = 'lib/images/hayatlogo.png',
  });

  final double size;
  final bool dark;
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            imagePath,
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(height: size * 0.18),
        Text(
          'MCQ',
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: dark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        Text(
          'Hayat Form',
          style: TextStyle(
            fontSize: size * 0.16,
            color: AppColors.accent,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
