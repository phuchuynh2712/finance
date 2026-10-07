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

  /// Content max-width for the 4 Auth screens (Sign In, Sign Up, Forgot
  /// Password, Reset Password) — matches MUI's own official Sign-in
  /// template (research.md Decision 2, auth-screens-responsive feature).
  /// Activated at [WindowSizeClass.medium] (600dp), narrower than
  /// [contentMaxWidth]'s [WindowSizeClass.expanded] (840dp) activation, per
  /// that feature's [contracts/auth-adaptive-ui.md] contract.
  static const double authContentMaxWidth = 450;

  /// Content max-width for the two entry screens (Chi tiêu and Thu nhập):
  /// a number pad plus a short chooser, or a short list of rows with an
  /// amount field each. Activated at [WindowSizeClass.medium] (600dp)
  /// because the pad must stop growing with the window from that width
  /// (specs/20261007-100751-adaptive-web-remaining-screens/research.md,
  /// Decision 2). At 520dp a three-key row is 168dp wide per key and a chip
  /// row holds about five account chips.
  static const double entryContentMaxWidth = 520;

  /// The minimum horizontal inset between a screen's content and the edge of
  /// its viewport. Equals the 18dp padding the screens already use, so below
  /// a screen's activation width [adaptiveGutterFor] returns exactly today's
  /// layout.
  static const double screenGutter = 18;

  /// The width of the *content* of a finished list screen (Tổng quan, Báo cáo,
  /// Lịch sử giao dịch) at and above [WindowSizeClass.expanded]: those screens
  /// used to cap a list that was itself padded by [screenGutter] at
  /// [contentMaxWidth], so their cards were 960 − 2 × 18 = 924dp wide. Handing
  /// this width to `AdaptiveGutters` keeps that look exactly while the scroll
  /// view now spans the whole viewport (the mouse wheel works over the margins).
  static const double paddedListMaxWidth = contentMaxWidth - 2 * screenGutter;
}

/// The horizontal inset that bounds content to [maxWidth] and centers it
/// inside a viewport of [viewportWidth], once the *window* reaches
/// [activatesAt]; below that, [minGutter].
///
/// Why a number instead of a wrapper widget: a scroll view that spans the
/// whole viewport and pads itself by this inset keeps mouse-wheel, trackpad
/// and the scroll bar working over the empty side margins, and a padding
/// value changing never remounts the subtree (specs/20261007-100751-adaptive-
/// web-remaining-screens/research.md, Decision 1).
///
/// - [windowWidth] picks the size class (the single breakpoint scale);
/// - [viewportWidth] is the width the scroll view or bar actually gets, which
///   is narrower than the window beside the navigation rail, so centering
///   uses it, not the window.
double adaptiveGutterFor({
  required double windowWidth,
  required double viewportWidth,
  double maxWidth = AppLayoutTokens.contentMaxWidth,
  WindowSizeClass activatesAt = WindowSizeClass.expanded,
  double minGutter = AppLayoutTokens.screenGutter,
}) {
  if (windowSizeClassFor(windowWidth).index < activatesAt.index) {
    return minGutter;
  }
  final centered = (viewportWidth - maxWidth) / 2;
  return centered > minGutter ? centered : minGutter;
}
