import 'package:flutter/material.dart';

import 'package:finance/core/theme/app_layout.dart';

/// Caps `child`'s width at [maxWidth] and centers it once the window
/// reaches [activatesAt] or wider — below that, `child` renders at the full
/// width its parent gives it (FR-005/FR-006). See
/// contracts/adaptive-shell-ui.md's `AdaptiveBody` contract in
/// specs/20260925-024749-adaptive-layout-foundation/, extended by
/// contracts/auth-adaptive-ui.md in
/// specs/20260925-204837-auth-screens-responsive/, and by
/// contracts/transaction-history-adaptive-ui.md in
/// specs/20260928-081611-transaction-history-redesign/ (the internal
/// implementation fix documented on [build] below — the external
/// parameter contract is unchanged).
///
/// Placed in `core/widgets/` (not feature-local) because it has two
/// consumers from its first commit — Tổng quan and Báo cáo — meeting the
/// constitution's "`core/` only once ≥2 features/screens need it" bar
/// immediately.
class AdaptiveBody extends StatelessWidget {
  const AdaptiveBody({
    super.key,
    required this.child,
    this.maxWidth = AppLayoutTokens.contentMaxWidth,
    this.activatesAt = WindowSizeClass.expanded,
  });

  final Widget child;
  final double maxWidth;

  /// The narrowest [WindowSizeClass] at which the width cap activates.
  /// Defaults to [WindowSizeClass.expanded] (840dp), preserving this
  /// widget's original behavior for its 2 pre-existing callers.
  final WindowSizeClass activatesAt;

  @override
  Widget build(BuildContext context) {
    final widthClass = windowSizeClassFor(MediaQuery.sizeOf(context).width);
    // Always return the SAME widget-tree shape (Center > ConstrainedBox >
    // child) on both sides of the threshold — only the constraint VALUE
    // changes. This is deliberate, not incidental: returning `child`
    // unwrapped below the threshold (as an earlier version of this widget
    // did) and `Center(ConstrainedBox(child))` at/above it are two
    // DIFFERENT widget types at the same tree position, so a live resize
    // crossing the threshold makes Flutter's Element reconciliation
    // dispose and remount `child`'s entire subtree — silently resetting
    // any State inside it (scroll position, text field content, running
    // animations) to its initial value on every crossing. Verified
    // empirically (transaction-history-redesign feature, research.md
    // Decision 1a): a ScrollController's offset read back as 0 after a
    // cross-threshold resize under the old two-shape implementation, and
    // stayed correct once this same-shape structure replaced it.
    // `maxWidth: double.infinity` below the threshold is a true layout
    // no-op (also verified empirically) — it does not add padding, does
    // not change the child's rendered width, and does not require
    // `Center` to have a bounded parent.
    //
    // Do not "simplify" this back to a conditional return — see
    // research.md Decision 1a in
    // specs/20260928-081611-transaction-history-redesign/ for the full
    // investigation, including why a per-caller `PageStorageKey` was
    // considered and rejected as a fix for this exact bug.
    final effectiveMaxWidth = widthClass.index < activatesAt.index
        ? double.infinity
        : maxWidth;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: child,
      ),
    );
  }
}
