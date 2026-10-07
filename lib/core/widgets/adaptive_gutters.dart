import 'package:flutter/material.dart';

import 'package:finance/core/theme/app_layout.dart';

/// Hands its [builder] the horizontal inset that bounds a screen's content to
/// [maxWidth] and centers it, from [activatesAt] up (see [adaptiveGutterFor]).
///
/// It adds no layout widget of its own — no `Center`, no `ConstrainedBox` —
/// so the scroll view [builder] returns spans the whole viewport (the mouse
/// wheel, the trackpad and the scroll bar work over the side margins too) and
/// the widget tree has the same shape at every width: a resize across a
/// breakpoint changes one number and remounts nothing, so typed values and
/// scroll positions survive.
///
/// This sits next to `AdaptiveBody` on purpose: `AdaptiveBody` wraps a child
/// in `Center > ConstrainedBox`, so a `ListView` inside it is only
/// column-wide and the margins beside it are dead zones for scrolling. Use
/// `AdaptiveBody` for non-scrolling content, and [AdaptiveGutters] for a
/// scroll view or for bars that must share a scroll view's column.
///
/// Usage: pad a scroll view with the gutter
/// (`ListView(padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 20))`) and
/// pinned bars with `Padding(padding: EdgeInsets.symmetric(horizontal:
/// gutter))`, so they all share one column.
class AdaptiveGutters extends StatelessWidget {
  const AdaptiveGutters({
    super.key,
    required this.builder,
    this.maxWidth = AppLayoutTokens.contentMaxWidth,
    this.activatesAt = WindowSizeClass.expanded,
    this.minGutter = AppLayoutTokens.screenGutter,
  });

  final Widget Function(BuildContext context, double gutter) builder;
  final double maxWidth;

  /// The narrowest [WindowSizeClass] at which the width cap activates.
  final WindowSizeClass activatesAt;

  /// The inset used below [activatesAt] and as a floor above it.
  final double minGutter;

  @override
  Widget build(BuildContext context) {
    final windowWidth = MediaQuery.sizeOf(context).width;
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = adaptiveGutterFor(
          windowWidth: windowWidth,
          viewportWidth: constraints.maxWidth,
          maxWidth: maxWidth,
          activatesAt: activatesAt,
          minGutter: minGutter,
        );
        return builder(context, gutter);
      },
    );
  }
}
