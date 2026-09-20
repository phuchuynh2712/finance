import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_semantic_colors.dart';

/// Light and dark [ThemeData], built from the "Khai Tam" brand palette.
/// Hex values, WCAG AA contrast verification, and usage constraints are
/// documented in research.md §4-§6 and data-model.md's Theme Palette
/// tables.
class AppTheme {
  AppTheme._();

  static final _lightColorScheme = const ColorScheme.light(
    primary: AppColors.lightPrimary,
    onPrimary: AppColors.lightOnPrimary,
    error: AppColors.lightDanger,
    onError: AppColors.lightOnDanger,
    surface: AppColors.lightSurface,
    onSurface: AppColors.lightOnSurface,
    // theme-tokens.json's "neutral-100" (kiem-soat-spec.md) — used by
    // Material widgets themselves (Chip, NavigationBar, etc.) as well as
    // this app's own secondary-badge backgrounds.
    surfaceContainerHighest: Color(0xFFF3EFE9),
  );

  static final _darkColorScheme = const ColorScheme.dark(
    primary: AppColors.darkPrimary,
    onPrimary: AppColors.darkOnPrimary,
    error: AppColors.darkDanger,
    onError: AppColors.darkOnDanger,
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkOnSurface,
    surfaceContainerHighest: Color(0xFF332F29),
  );

  static final light = ThemeData(
    useMaterial3: true,
    fontFamily: 'Lexend',
    // Unset, ColorScheme.light's ~30 other slots (scaffold background,
    // surfaceContainer*, etc.) fall back to Flutter's default Material You
    // purple-gray seed instead of the brand palette — visible as unwanted
    // gray tinting across the app (research.md's bgApp/bgSunken tokens).
    scaffoldBackgroundColor: AppColors.lightBgApp,
    colorScheme: _lightColorScheme,
    // FR-013: selection is indicated by icon/label color alone — no pill
    // background shape behind the selected icon.
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.lightPrimary
              : _lightColorScheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? AppColors.lightPrimary
              : _lightColorScheme.onSurfaceVariant,
        ),
      ),
    ),
    extensions: const [AppSemanticColors.light],
  );

  static final dark = ThemeData(
    useMaterial3: true,
    fontFamily: 'Lexend',
    scaffoldBackgroundColor: AppColors.darkBgApp,
    colorScheme: _darkColorScheme,
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.darkPrimaryAccentText
              : _darkColorScheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? AppColors.darkPrimaryAccentText
              : _darkColorScheme.onSurfaceVariant,
        ),
      ),
    ),
    extensions: const [AppSemanticColors.dark],
  );
}
