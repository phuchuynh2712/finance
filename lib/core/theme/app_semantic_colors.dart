import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Semantic colors with no native [ColorScheme] slot (success, warning, and
/// their soft/tint/foreground variants). Registered on [ThemeData.extensions]
/// for both light and dark themes; consume via
/// `Theme.of(context).extension<AppSemanticColors>()!`.
///
/// See data-model.md's AppSemanticColors table and research.md §6 for why
/// this exists instead of forcing these onto [ColorScheme.secondary]/
/// [ColorScheme.tertiary].
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.successSoft,
    required this.successFg,
    required this.warning,
    required this.warningSoft,
    required this.warningFg,
    required this.dangerSoft,
    required this.dangerFg,
    required this.primarySoft,
    required this.bgApp,
    required this.fg2,
    required this.fg3,
    required this.border1,
    required this.border2,
  });

  final Color success;
  final Color successSoft;
  final Color successFg;
  final Color warning;
  final Color warningSoft;
  final Color warningFg;
  final Color dangerSoft;
  final Color dangerFg;
  final Color primarySoft;
  final Color bgApp;
  final Color fg2;
  final Color fg3;
  final Color border1;
  final Color border2;

  static const light = AppSemanticColors(
    success: AppColors.lightSuccess,
    successSoft: AppColors.lightSuccessSoft,
    // No distinct light-mode token exists in theme-tokens.json; success is
    // already AA-safe as text on light backgrounds (research.md §4), so
    // successFg aliases success rather than introducing a new color.
    successFg: AppColors.lightSuccess,
    warning: AppColors.lightWarning,
    warningSoft: AppColors.lightWarningSoft,
    // Same aliasing rationale as successFg; warningFg additionally inherits
    // warning's non-text-only restriction in light mode (research.md §4).
    warningFg: AppColors.lightWarning,
    dangerSoft: AppColors.lightDangerSoft,
    dangerFg: AppColors.lightDanger,
    primarySoft: AppColors.lightPrimarySoft,
    bgApp: AppColors.lightBgApp,
    fg2: AppColors.lightFg2,
    fg3: AppColors.lightFg3,
    border1: AppColors.lightBorder1,
    border2: AppColors.lightBorder2,
  );

  static const dark = AppSemanticColors(
    success: AppColors.darkSuccess,
    successSoft: AppColors.darkSuccessSoft,
    successFg: AppColors.darkSuccessFg,
    warning: AppColors.darkWarning,
    warningSoft: AppColors.darkWarningSoft,
    warningFg: AppColors.darkWarningFg,
    dangerSoft: AppColors.darkDangerSoft,
    dangerFg: AppColors.darkDangerFg,
    primarySoft: AppColors.darkPrimarySoft,
    bgApp: AppColors.darkBgApp,
    fg2: AppColors.darkFg2,
    fg3: AppColors.darkFg3,
    border1: AppColors.darkBorder1,
    border2: AppColors.darkBorder2,
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? successSoft,
    Color? successFg,
    Color? warning,
    Color? warningSoft,
    Color? warningFg,
    Color? dangerSoft,
    Color? dangerFg,
    Color? primarySoft,
    Color? bgApp,
    Color? fg2,
    Color? fg3,
    Color? border1,
    Color? border2,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      successFg: successFg ?? this.successFg,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      warningFg: warningFg ?? this.warningFg,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      dangerFg: dangerFg ?? this.dangerFg,
      primarySoft: primarySoft ?? this.primarySoft,
      bgApp: bgApp ?? this.bgApp,
      fg2: fg2 ?? this.fg2,
      fg3: fg3 ?? this.fg3,
      border1: border1 ?? this.border1,
      border2: border2 ?? this.border2,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) {
      return this;
    }
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      successFg: Color.lerp(successFg, other.successFg, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      warningFg: Color.lerp(warningFg, other.warningFg, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      dangerFg: Color.lerp(dangerFg, other.dangerFg, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      bgApp: Color.lerp(bgApp, other.bgApp, t)!,
      fg2: Color.lerp(fg2, other.fg2, t)!,
      fg3: Color.lerp(fg3, other.fg3, t)!,
      border1: Color.lerp(border1, other.border1, t)!,
      border2: Color.lerp(border2, other.border2, t)!,
    );
  }
}
