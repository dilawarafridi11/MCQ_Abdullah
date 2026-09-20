import 'package:flutter/material.dart';

/// Hayat Foam brand palette.
/// Luxury Gold (#D4AF37) · Deep Black (#121212) · Premium Red (#8B1E1E) · Cream (#F8F6F1)
class AppColors {
  AppColors._();

  // ---- Brand anchors -------------------------------------------------------
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFE9CE7A);
  static const Color goldDark = Color(0xFFB8912A);
  static const Color deepBlack = Color(0xFF121212);
  static const Color premiumRed = Color(0xFF8B1E1E);
  static const Color premiumRedLight = Color(0xFFA83636);
  static const Color cream = Color(0xFFF8F6F1);
  static const Color creamLight = Color(0xFFFFFDF8);

  // ---- Semantic aliases ----------------------------------------------------
  static const Color primary = Color(0xFF1C1C1C); // Near-black (buttons, seed)
  static const Color primaryLight = Color(0xFF3A3A3A);
  static const Color primaryDark = Color(0xFF0E0E0E);
  static const Color accent = Color(0xFFD4AF37); // Gold
  static const Color accentLight = Color(0xFFE9CE7A);
  static const Color secondary = Color(0xFFD4AF37); // Gold accents
  static const Color secondaryLight = Color(0xFFE9CE7A);
  static const Color success = Color(0xFF3E8E5A);
  static const Color successLight = Color(0xFF6FBE8C);
  static const Color danger = Color(0xFF8B1E1E); // Premium red
  static const Color dangerLight = Color(0xFFB04A4A);
  static const Color warning = Color(0xFFC9971F); // Gold-amber
  static const Color warningLight = Color(0xFFE0B84F);
  static const Color info = Color(0xFFB8860B); // Bronze
  static const Color infoLight = Color(0xFFD4AF37);
  static const Color violet = Color(0xFF6D5AA8);
  static const Color pink = Color(0xFFC2507A);

  /// Common soft gradient pairs used for gradient cards.
  static const LinearGradient emeraldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1C1C1C), Color(0xFF3B3330)],
  );
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD4AF37), Color(0xFFE9CE7A)],
  );
  static const LinearGradient royalGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B1E1E), Color(0xFFA83636)],
  );
  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B1E1E), Color(0xFFB04A4A)],
  );
  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC9971F), Color(0xFFE0B84F)],
  );
  static const LinearGradient violetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6D5AA8), Color(0xFF8A77C4)],
  );
  static const LinearGradient pinkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC2507A), Color(0xFFD68AA8)],
  );
  static const LinearGradient infoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB8860B), Color(0xFFD4AF37)],
  );

  // Light (cream / off-white)
  static const Color background = Color(0xFFF8F6F1);
  static const Color backgroundTop = Color(0xFFF1ECE1);
  static const Color surface = Color(0xFFFFFDF8);
  static const Color surfaceHigh = Color(0xFFF2EDE2);
  static const Color border = Color(0xFFE7E0D0);
  static const Color borderStrong = Color(0xFFD5CBB5);

  // Dark (deep black with warm undertone)
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkBackgroundTop = Color(0xFF1A1815);
  static const Color darkSurface = Color(0xFF1C1B19);
  static const Color darkSurfaceHigh = Color(0xFF282520);
  static const Color darkBorder = Color(0xFF2E2B25);
  static const Color darkBorderStrong = Color(0xFF3E3A31);

  static const Color textPrimary = Color(0xFF1C1A16);
  static const Color textSecondary = Color(0xFF6F675A);
  static const Color darkTextPrimary = Color(0xFFF5EFE2);
  static const Color darkTextSecondary = Color(0xFFABA394);
}
