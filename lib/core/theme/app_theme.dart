import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_semantic_colors.dart';

/// Light and dark [ThemeData], built from the "Khai Tam" brand palette.
/// Hex values, WCAG AA contrast verification, and usage constraints are
/// documented in research.md §4-§6 and data-model.md's Theme Palette
/// tables.
class AppTheme {
  AppTheme._();

  static final light = ThemeData(
    useMaterial3: true,
    fontFamily: 'Lexend',
    colorScheme: const ColorScheme.light(
      primary: AppColors.lightPrimary,
      onPrimary: AppColors.lightOnPrimary,
      error: AppColors.lightDanger,
      onError: AppColors.lightOnDanger,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightOnSurface,
    ),
    extensions: const [AppSemanticColors.light],
  );

  static final dark = ThemeData(
    useMaterial3: true,
    fontFamily: 'Lexend',
    colorScheme: const ColorScheme.dark(
      primary: AppColors.darkPrimary,
      onPrimary: AppColors.darkOnPrimary,
      error: AppColors.darkDanger,
      onError: AppColors.darkOnDanger,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkOnSurface,
    ),
    extensions: const [AppSemanticColors.dark],
  );
}
