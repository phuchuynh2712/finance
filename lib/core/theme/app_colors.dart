import 'package:flutter/material.dart';

/// Brand palette tokens, sourced from the design handoff's
/// `theme-tokens.json` (see specs/20260904-030816-theme-icon-splash/
/// reference/theme-tokens.json). WCAG AA verification and usage
/// constraints are documented in research.md §4-§6 and data-model.md's
/// Theme Palette tables.
class AppColors {
  AppColors._();

  // Light
  static const lightPrimary = Color(0xFF1A72E0);
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightDanger = Color(0xFFA42619);
  static const lightOnDanger = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightOnSurface = Color(0xFF1A1714);
  static const lightSuccess = Color(0xFF237A50);
  static const lightSuccessSoft = Color(0xFFEBF5F0);
  static const lightWarning = Color(0xFFAE8015);
  static const lightWarningSoft = Color(0xFFFBF3E0);
  static const lightDangerSoft = Color(0xFFFBEDEB);
  static const lightPrimarySoft = Color(0xFFEDF4FF);
  static const lightBgApp = Color(0xFFFAF8F5);
  static const lightFg2 = Color(0xFF4A443B);
  static const lightFg3 = Color(0xFF8A8073);
  static const lightBorder1 = Color(0xFFE7E1D8);
  static const lightBorder2 = Color(0xFFD4CCC0);

  // Dark
  static const darkPrimary = Color(0xFF3B8DF8);
  // Reused bgApp token, not white — white-on-primary measures 3.31:1 and
  // fails AA; bgApp-on-primary measures 5.40:1 (research.md §5).
  static const darkOnPrimary = Color(0xFF1A1714);
  static const darkDanger = Color(0xFFE07A6D);
  // Same reused-bgApp fix as onPrimary — white-on-danger measures 2.93:1
  // and fails AA (research.md §6).
  static const darkOnDanger = Color(0xFF1A1714);
  static const darkSurface = Color(0xFF241F1A);
  static const darkOnSurface = Color(0xFFFAF8F5);
  static const darkSuccess = Color(0xFF62BB91);
  static const darkSuccessSoft = Color(0x2923795A); // rgba(35,122,80,0.16)
  static const darkWarning = Color(0xFFDFB04A);
  static const darkWarningSoft = Color(0x29C9971F); // rgba(201,151,31,0.16)
  static const darkDangerSoft = Color(0x29C43020); // rgba(196,48,32,0.16)
  static const darkPrimarySoft = Color(0x293B8DF8); // rgba(59,141,248,0.16)
  static const darkBgApp = Color(0xFF1A1714);
  static const darkFg2 = Color(0xFFB0A696);
  static const darkFg3 = Color(0xFF8A8073);
  static const darkBorder1 = Color(0xFF4A443B);
  static const darkBorder2 = Color(0xFF4A443B);

  // Dark-mode-only "Fg" variants (text/icon color for content drawn on a
  // *Soft tint or on bgApp/bgSurface) — see data-model.md's AppSemanticColors
  // table for why light mode aliases these to success/warning/danger instead.
  static const darkSuccessFg = Color(0xFF8FD6B0);
  static const darkWarningFg = Color(0xFFECCB7E);
  static const darkDangerFg = Color(0xFFF0B3A8);
}
