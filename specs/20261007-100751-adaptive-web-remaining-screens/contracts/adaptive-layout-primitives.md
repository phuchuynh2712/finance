# Contract: Shared Layout Primitives

**Feature**: `20261007-100751-adaptive-web-remaining-screens` | **Date**: 2026-10-07 | **Delivered with**: story 1 (PR 1)

## `AppLayoutTokens` additions (`lib/core/theme/app_layout.dart`)

```dart
static const double entryContentMaxWidth = 520; // Chi tiêu, Thu nhập; activates at WindowSizeClass.medium
static const double screenGutter = 18;          // minimum horizontal inset (today's screen padding)
```

`contentMaxWidth` (960) and `authContentMaxWidth` (450) are unchanged.

## `adaptiveGutterFor` (`lib/core/theme/app_layout.dart`)

```dart
double adaptiveGutterFor({
  required double windowWidth,
  required double viewportWidth,
  double maxWidth = AppLayoutTokens.contentMaxWidth,
  WindowSizeClass activatesAt = WindowSizeClass.expanded,
  double minGutter = AppLayoutTokens.screenGutter,
});
```

Pure; no `BuildContext`. Behavior table (the unit tests pin each row):

| windowWidth | viewportWidth | maxWidth | activatesAt | Result |
|-------------|---------------|----------|-------------|--------|
| 412 | 412 | 960 | expanded | 18 (compact: unchanged) |
| 839.9 | 757 | 960 | expanded | 18 (below activation) |
| 840 | 757 | 960 | expanded | 18 (viewport narrower than max: `max(18, (757−960)/2)`) |
| 1440 | 1357 | 960 | expanded | 198.5 |
| 2560 | 2477 | 960 | expanded | 758.5 |
| 600 | 517 | 520 | medium | 18 |
| 1000 | 917 | 520 | medium | 198.5 |
| 599.9 | 599.9 | 520 | medium | 18 |

## `AdaptiveGutters` (`lib/core/widgets/adaptive_gutters.dart`)

```dart
class AdaptiveGutters extends StatelessWidget {
  const AdaptiveGutters({
    super.key,
    required this.builder,
    this.maxWidth = AppLayoutTokens.contentMaxWidth,
    this.activatesAt = WindowSizeClass.expanded,
    this.minGutter = AppLayoutTokens.screenGutter,
  });
  final Widget Function(BuildContext context, double gutter) builder;
  ...
}
```

Rules:
1. Wraps `LayoutBuilder` and `MediaQuery.sizeOf(context).width`; calls `adaptiveGutterFor` and passes the number to
   `builder`. It adds **no** layout widget of its own (no `Center`, no `ConstrainedBox`), so the scroll view returned by
   `builder` spans the whole viewport and the tree has the same shape at every width.
2. A screen uses the returned gutter as `ListView(padding: EdgeInsets.fromLTRB(gutter, top, gutter, bottom))` for
   scroll views and `Padding(padding: EdgeInsets.symmetric(horizontal: gutter))` for pinned bars, so a scroll view's
   content, its pinned bars and any sibling of it share one column.
3. Pages with a header bar that spans the window (the title strip of Kế hoạch) keep it full-width, exactly like the
   finished Tổng quan header.
4. `AdaptiveBody` is not removed or changed by this feature's stories 1–6 (Decision 1 of research.md); the sweep migrates
   the finished screens that wrap a scroll view in it if their wheel dead zone reproduces.

## Tests (core)

| File | Covers |
|------|--------|
| `test/unit/core/theme/adaptive_gutter_test.dart` | the table above, plus monotonic and `≥ minGutter` properties |
| `test/widget/core/widgets/adaptive_gutters_test.dart` | at 412 the builder gets 18; at 1440 it gets (viewport − 960) / 2; resizing 1440 → 412 → 1440 keeps a `StatefulWidget` child's state (same-shape proof); the widget adds no `Center`/`ConstrainedBox` |

## Non-goals

No third-party package; no change to `windowSizeClassFor` or the five size classes; no new navigation behavior.
