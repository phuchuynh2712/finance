import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Light and dark [ThemeData], derived from the brand icon's palette.
/// Hex values and their WCAG AA contrast verification are documented in
/// research.md §2-§3 and data-model.md's Theme Palette table.
class AppTheme {
  AppTheme._();

  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF287A53),
      onPrimary: Colors.white,
      // Accent color. In the light theme this is non-text/large-UI use
      // only (icons, chips, selected-state fills, large headlines) — max
      // 3.56:1 against light backgrounds even when darkened, below the
      // 4.5:1 text threshold. See research.md §2.
      secondary: AppColors.iconGold,
      onSecondary: Color(0xFF153F2A),
      surface: AppColors.iconCream,
      onSurface: Color(0xFF153F2A),
    ),
  );

  static final dark = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.iconLightGreen,
      onPrimary: Color(0xFF0C2318),
      secondary: AppColors.iconGold,
      onSecondary: Color(0xFF0C2318),
      // Darkened/desaturated derivative of the icon's green, not a neutral
      // gray/black, so the dark theme still reads as brand-colored. See
      // spec.md Clarifications.
      surface: Color(0xFF0C2318),
      onSurface: Colors.white,
    ),
  );
}
