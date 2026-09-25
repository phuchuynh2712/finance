/// Shared adaptive-layout tokens (Constitution Principle III — "Adaptive
/// Layout"): Material's window size class breakpoints and the content
/// max-width this feature introduces. Defined once here so no screen
/// re-derives or hardcodes its own breakpoint values.
///
/// Pure Dart, no Flutter import — layout *decisions* built on top of this
/// (which widget to render) live in `core/router/` and `core/widgets/`;
/// this file only classifies a width.
library;

/// Material's five window size classes, ordered from narrowest to widest.
/// Each value's associated width is documented on the value itself; the
/// classification boundary belongs to the *higher* class (e.g. exactly
/// 600dp is [medium], not [compact]) — see [windowSizeClassFor].
///
/// This feature's own requirements only branch on two of these five
/// thresholds ([compact] vs. [medium] for navigation, below vs. at/above
/// [expanded] for content width) — [large] and [extraLarge] exist so later
/// features reuse this one definition instead of inventing a second one
/// (research.md Decision 10).
enum WindowSizeClass {
  /// < 600dp — phone portrait. Bottom-bar navigation.
  compact,

  /// 600dp–839dp — rail navigation begins; content width still unconstrained.
  medium,

  /// 840dp–1199dp — rail navigation; content-width cap begins.
  expanded,

  /// 1200dp–1599dp — reserved for later features.
  large,

  /// ≥1600dp — reserved for later features.
  extraLarge,
}

/// Classifies [width] (logical pixels) into the [WindowSizeClass] whose
/// lower bound is the greatest one `<= width`. A boundary value belongs to
/// the higher class: exactly `600.0` returns [WindowSizeClass.medium], not
/// [WindowSizeClass.compact].
///
/// [width] MUST be `>= 0` — [MediaQuery]'s own width is never negative, so
/// this is not defensively checked here.
WindowSizeClass windowSizeClassFor(double width) {
  if (width >= 1600) return WindowSizeClass.extraLarge;
  if (width >= 1200) return WindowSizeClass.large;
  if (width >= 840) return WindowSizeClass.expanded;
  if (width >= 600) return WindowSizeClass.medium;
  return WindowSizeClass.compact;
}

/// Shared numeric layout constants derived from the breakpoint scale
/// above.
class AppLayoutTokens {
  AppLayoutTokens._();

  /// Content max-width for dashboard-style screens (Tổng quan, Báo cáo) at
  /// [WindowSizeClass.expanded] and above — this feature's starting
  /// default (spec.md Assumptions); later, differently-shaped screens
  /// (list-detail, forms) may introduce their own constant here when
  /// they're tackled.
  static const double contentMaxWidth = 960;
}
