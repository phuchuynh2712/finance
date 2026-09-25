import 'package:flutter/material.dart';

import 'package:finance/core/theme/app_layout.dart';

/// Caps `child`'s width at [maxWidth] and centers it once the window
/// reaches [WindowSizeClass.expanded] (840dp) — below that, `child`
/// renders unchanged, at the full width its parent gives it (FR-005/
/// FR-006). See contracts/adaptive-shell-ui.md's `AdaptiveBody` contract
/// in specs/20260925-024749-adaptive-layout-foundation/.
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
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final widthClass = windowSizeClassFor(MediaQuery.sizeOf(context).width);
    if (widthClass == WindowSizeClass.compact ||
        widthClass == WindowSizeClass.medium) {
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
