import 'package:flutter/material.dart';

import 'package:finance/core/theme/app_layout.dart';

/// Caps `child`'s width at [maxWidth] and centers it once the window
/// reaches [activatesAt] or wider — below that, `child` renders unchanged,
/// at the full width its parent gives it (FR-005/FR-006). See
/// contracts/adaptive-shell-ui.md's `AdaptiveBody` contract in
/// specs/20260925-024749-adaptive-layout-foundation/, extended by
/// contracts/auth-adaptive-ui.md in
/// specs/20260925-204837-auth-screens-responsive/.
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
    if (widthClass.index < activatesAt.index) {
      return child;
    }
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
