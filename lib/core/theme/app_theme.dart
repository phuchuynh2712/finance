import 'package:flutter/material.dart';

import 'package:finance/core/theme/app_colors.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';

/// Light and dark [ThemeData], built from the "Kiểm Soát" brand palette.
/// Hex values, WCAG AA contrast verification, and usage constraints are
/// documented in research.md §4-§6 and data-model.md's Theme Palette
/// tables.
class AppTheme {
  AppTheme._();

  static const double _navLabelFontSize = 12;

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
    // Explicit, not left to Flutter's per-platform default: on
    // linux/macOS/windows (a desktop browser's Web build included),
    // ThemeData would otherwise default to VisualDensity.compact and
    // MaterialTapTargetSize.shrinkWrap, silently shrinking every tap
    // target below the app's own >=48x48dp minimum
    // (adaptive-layout-foundation FR-007, research.md Decision 6).
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    // Every pop-up (item form, delete confirmation, language choice,
    // biometric offer, discard prompt) is centered and at most 560dp wide on
    // a wide window: Flutter's default only sets a 280dp minimum, so a
    // dialog's width otherwise follows its content and the window
    // (specs/20261007-100751-adaptive-web-remaining-screens/research.md,
    // Decision 6).
    dialogTheme: const DialogThemeData(
      constraints: BoxConstraints(minWidth: 280, maxWidth: 560),
    ),
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
          // Material 3's label size. Without a size the label fell back to the
          // 14sp body text, in which "Tổng quan" (73dp) wraps on a phone
          // 360dp wide or narrower; at 12sp (63dp) it fits one line down to
          // 320dp.
          fontSize: _navLabelFontSize,
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
    // See AppTheme.light's matching fields for why these are explicit.
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    // Every pop-up (item form, delete confirmation, language choice,
    // biometric offer, discard prompt) is centered and at most 560dp wide on
    // a wide window: Flutter's default only sets a 280dp minimum, so a
    // dialog's width otherwise follows its content and the window
    // (specs/20261007-100751-adaptive-web-remaining-screens/research.md,
    // Decision 6).
    dialogTheme: const DialogThemeData(
      constraints: BoxConstraints(minWidth: 280, maxWidth: 560),
    ),
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
          fontSize: _navLabelFontSize,
          color: states.contains(WidgetState.selected)
              ? AppColors.darkPrimaryAccentText
              : _darkColorScheme.onSurfaceVariant,
        ),
      ),
    ),
    extensions: const [AppSemanticColors.dark],
  );
}
