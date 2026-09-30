# Phase 0 Research: Transaction History Screen Responsive Redesign

## Decision 1: Width-cap mechanism and activation threshold

**Decision**: Wrap the screen's `Expanded(child: CustomScrollView(...))` in
`AdaptiveBody` with its default parameters — no `activatesAt` or `maxWidth`
override. This activates the cap at `WindowSizeClass.expanded` (840dp) and
caps at `AppLayoutTokens.contentMaxWidth` (960dp), identical to Home
Overview and Monthly Report.

**Rationale**: `AdaptiveBody`'s constructor already defaults to
`activatesAt: WindowSizeClass.expanded` and
`maxWidth: AppLayoutTokens.contentMaxWidth`
(`lib/core/widgets/adaptive_body.dart`) — these defaults exist specifically
so a list/dashboard-shaped screen needs zero extra arguments to adopt the
pattern, unlike the Auth screens (form-shaped, narrower `authContentMaxWidth`
activated at the narrower `medium` breakpoint). Transaction History is
list/dashboard-shaped (a scrollable list of rows under a header and filter
controls), matching Home Overview's and Monthly Report's shape exactly, not
the Auth screens' shape. No new value or threshold is introduced.

**Alternatives considered**:
- A new, narrower max-width specific to this screen: rejected — the screen's
  content (transaction rows, filter chips) has no natural narrow-form
  reading width the way a login form does; a longer row (name + amount) is
  easier to scan at `contentMaxWidth` than forced into a login-form-width
  column.
- Extending `AdaptiveBody`'s API further (a third parameter, a new
  activation mode): rejected — no gap exists that the current
  `activatesAt`/`maxWidth` pair (introduced by auth-screens-responsive)
  doesn't already cover. `contracts/` from that prior feature already
  documents this exact contract; this feature adds no new clause to it.

**⚠️ Superseded in part by Decision 1a below**: this Decision's "reused
as-is" framing was found to be incomplete during this feature's own
planning — `AdaptiveBody`'s *implementation* (not its parameter contract)
has a real, previously-undetected bug that this feature's own FR-004
(scroll position preserved across a live resize) exposes. Decision 1a
documents the bug, the fix, and — per explicit user instruction during this
feature's planning — is written deliberately verbosely so a future session
reading only this file (without conversation history) cannot repeat the
investigation from scratch or, worse, reintroduce the bug while "cleaning
up" `AdaptiveBody` later.

---

## Decision 1a: `AdaptiveBody` has a state-loss bug on threshold crossing — fixed at the root, not patched per-caller

### The bug, precisely

`AdaptiveBody.build()` (`lib/core/widgets/adaptive_body.dart`), **before
this feature's fix**, had this shape:

```dart
Widget build(BuildContext context) {
  final widthClass = windowSizeClassFor(MediaQuery.sizeOf(context).width);
  if (widthClass.index < activatesAt.index) {
    return child;                                    // shape A
  }
  return Center(                                      // shape B
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
```

This returns a **different widget-tree shape** on either side of the
threshold: `child` directly (shape A) vs.
`Center > ConstrainedBox > child` (shape B). When the window is resized
live across `activatesAt`, Flutter's Element reconciliation sees a
different `Widget` type at the same tree position between frames. Per
Flutter's reconciliation rules (a `StatelessWidget`/`Center` cannot
"become" its own child in place), this **disposes the old Element subtree
and mounts a brand-new one** — it is not a constraint-only relayout.

**Concretely**: if `child` is (or contains) a `Scrollable` — a `ListView`,
`CustomScrollView`, `SingleChildScrollView` — that `Scrollable`'s
`ScrollPosition` is owned by its `ScrollableState`, which is *inside* the
disposed subtree. Disposing and remounting it resets scroll offset to 0.
The same applies to any other State living below `AdaptiveBody`'s `child`
boundary: `TextEditingController` listener attachments, in-flight
`AnimationController`s, `ExpansionTile` open/closed state, etc. — anything
Flutter's Element system would normally preserve across a rebuild is lost
here, because this isn't an ordinary rebuild; it's a dispose-and-remount.

### How this was found

This feature's own FR-004 ("Resizing the window live, at any scroll
position, MUST NOT reset scroll position...") prompted verification
*before* assuming the existing shared `AdaptiveBody` mechanism satisfied it
for free (the "reused as-is" framing in Decision 1 above). A throwaway
widget test — `AdaptiveBody(child: ListView.builder(...))`,
`controller.jumpTo(500)`, resize the test viewport across the
`activatesAt` threshold, then read `controller.offset` — **empirically
reproduced the bug**: offset was `500.0` before the resize and `0.0` after,
confirming the Element-disposal theory rather than leaving it as
speculation. This test was throwaway (written, run, deleted immediately
after — confirmed via `git status`), per this project's established
practice of not committing exploratory scaffolding; the citation here (and
the reasoning above) is what a future session should trust, not a
re-derivation from first principles each time.

**Why Home Overview and Monthly Report never surfaced this**: neither
screen's own spec/tasks ever included a scroll-position-preservation
requirement, so nothing in this codebase had previously exercised this
exact failure mode before this feature's FR-004 did. The bug was latent,
not previously absent.

### The fix

`AdaptiveBody.build()` now **always returns the same widget-tree shape** —
`Center(child: ConstrainedBox(child: child))` — on both sides of the
threshold. Only the `ConstrainedBox`'s `maxWidth` constraint *value*
changes: `double.infinity` (a true layout no-op — verified empirically,
see below) below `activatesAt`'s threshold, the configured `maxWidth` at or
above it. Because the widget shape never changes, Flutter's reconciliation
treats every threshold crossing as an ordinary constraint-only relayout of
the *same* Element — `child`'s subtree, and everything living inside it
(scroll position, text field content, animations), is never disposed.

This was verified empirically in two more throwaway tests, both run,
observed, and deleted (per the same practice as above — nothing here is
speculative):
1. The same `ListView` + `jumpTo(500)` + cross-threshold-resize scenario,
   this time against the same-shape implementation: offset read `500.0`
   both before and after the resize.
2. `Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth:
   double.infinity), child: <a full-width child>))` alone, to confirm
   `maxWidth: double.infinity` genuinely imposes zero layout constraint
   (not even a rounding/pixel-snapping side-effect): the child's rendered
   width and horizontal position exactly matched what it would have been
   with no `ConstrainedBox` at all.

### The alternative that was rejected, and why (recorded so it is not
   re-proposed as "simpler")

**`PageStorageKey`** (e.g. `ListView(key: PageStorageKey('some-id'), ...)`)
was also verified empirically to fix the scroll-offset symptom — Flutter's
`ScrollPosition.saveScrollOffset`/`restoreScrollOffset` round-trips through
`PageStorageBucket` synchronously within the same reconciliation pass that
disposes/remounts the `Scrollable`, so the offset comes back correctly.
**This was deliberately rejected as the fix**, for reasons a future session
should weigh before reaching for it again on a *different* `AdaptiveBody`
caller that hits this same bug:

- It is a **per-instance opt-in**, not a structural fix. Every future
  scrollable placed under `AdaptiveBody` would need its own
  `PageStorageKey` to avoid this bug — a future author who doesn't know
  this history (exactly the scenario this section exists to prevent) will
  very plausibly forget it, and the bug will silently reappear for their
  screen while this file describes it as "fixed."
- It **only addresses `ScrollPosition`**, one specific kind of state.
  `TextEditingController` content, `AnimationController` state, and any
  other State living inside `AdaptiveBody`'s `child` are still disposed and
  lost by a `PageStorageKey`-only fix — it treats a symptom of the
  Element-disposal bug, not the bug itself.
- The structural (same-shape) fix, once applied to `AdaptiveBody` itself,
  requires **zero additional code at any call site, present or future** —
  every one of `AdaptiveBody`'s 5 existing callers (Overview, Report, and
  the 4 Auth screens) and every future caller gets the fix automatically,
  with no obligation to remember anything.

**Explicit scope-and-process note (recorded because the user raised this
directly during planning)**: fixing this in `AdaptiveBody` itself, rather
than patching only Transaction History's own call site, means this
feature's changes are not strictly confined to
`features/expenses/presentation/` as originally scoped in Decision 1 and
plan.md's first draft. This was a deliberate choice, made after the user
was asked to choose between a locally-scoped patch and a root-cause fix in
the shared widget, and explicitly chose the root-cause fix — reasoning: a
project's priority is output quality, not minimizing an individual PR's
diff size at the cost of latent bugs that require a later refactor to
actually fix. **Do not revert this to a per-caller patch in a future
"scope cleanup" pass** without re-reading this section first — the
per-caller approach was considered and rejected for the structural reasons
above, not merely because "sharing the fix was convenient this time."

### Consequence: a pre-existing visual inconsistency is now resolved, not introduced

Verified empirically (throwaway test, same practice as above): **before**
this fix, a short (`mainAxisSize: MainAxisSize.min`) child inside
`SingleChildScrollView > AdaptiveBody` — the exact structure Sign In and
Sign Up use — was **already vertically centered within the scroll view's
viewport at/above `activatesAt`'s threshold** (`Center`'s pre-existing,
unavoidable behavior for a `Center` receiving unbounded-but-constrained
height from a `SingleChildScrollView` parent). This fix's structural change
means that same vertical-centering behavior now also applies *below* the
threshold, where previously the child was returned unwrapped (and thus
top-anchored, `SingleChildScrollView`'s own default).

**This is not a new regression this feature introduces** — it is an
existing, already-shipped visual behavior (verified present in the current
production code, not hypothetical) becoming *consistent* across all window
sizes instead of only applying above the threshold. Sign In and Sign Up are
the two Auth screens with this exact `SingleChildScrollView > AdaptiveBody`
structure and are therefore the ones whose narrow-width appearance changes
(content now vertically centered instead of top-anchored, matching what
those same screens already look like above 600dp today); Forgot Password
and Reset Password use `Padding > AdaptiveBody` directly (no
`SingleChildScrollView` in between) and were not separately re-verified
against this specific consequence in this feature's own testing —
`/speckit-tasks` for this feature MUST include an explicit visual
regression check for all 4 Auth screens before considering this feature's
`AdaptiveBody` change complete, not just Transaction History's own tests.

## Decision 2: `AdaptiveBody` placement in the widget tree

**Decision**: Wrap only the `Expanded`'s child (the `CustomScrollView`
containing the month/filter controls sliver, transaction-group slivers, and
loading/error/empty-state slivers) — leave `_HistoryHeader` (the back
button + title bar) outside `AdaptiveBody`, exactly as Sign Up / Forgot
Password / Reset Password keep their header bars outside their own
`AdaptiveBody` wrap.

**Rationale**: FR-003 requires the header stay full-width at every window
size; only the scrollable body is capped. This mirrors the established
Header-outside/Body-inside split already used by every screen that has both
a fixed header and a capped scrollable body (Sign Up, Forgot Password,
Reset Password) — Home Overview and Monthly Report follow the identical
split (`_Header()` outside, `AdaptiveBody(child: ListView(...))` inside).
Since the month/filter controls (`_HistoryControls`) are the first sliver
*inside* the `CustomScrollView`, wrapping the whole `CustomScrollView` in
`AdaptiveBody` (rather than wrapping only individual slivers) is what caps
both the controls and the list together as FR-001 requires, in one pass —
matching how Home Overview wraps a single `ListView` containing multiple
logical sections.

**Alternatives considered**:
- Wrapping `_HistoryControls` and the transaction-list slivers in two
  separate `AdaptiveBody` instances: rejected — unnecessary duplication,
  and risks the two caps drifting out of alignment (e.g. a future edit to
  one call site's `maxWidth` without the other) for no behavioral benefit;
  a single wrap around the whole scroll view keeps one source of truth.
- Wrapping the whole `Column` (header + scroll view) in one `AdaptiveBody`:
  rejected — this would cap the header too, violating FR-003.

## Decision 3: Keyboard/hover/focus support — verify, don't build

**Decision**: Treat User Story 2 (FR-006–FR-009) as a verification pass
against Flutter's default `ButtonStyleButton`/`InkWell` behavior first, and
only add code where an actual gap is found. A `grep` of the screen's
current source confirms no `FocusNode`, `canRequestFocus`, `IgnorePointer`,
`AbsorbPointer`, or custom `MouseRegion` overrides exist anywhere in
`transaction_history_screen.dart` — every interactive control
(`IconButton` back button, `OutlinedButton` month buttons, `InkWell` filter
chips, `FilledButton` retry button via `EmptyStateView`) is a stock Material
widget with Flutter's default hover/focus/keyboard-activation machinery
already wired in, unmodified.

**Rationale**: This mirrors the Auth screens redesign's own finding
(research.md Decision 3 of that feature): hover and Tab-focus come free
from Flutter's default button/`InkWell` implementation; the only *real* gap
that feature found was Enter-to-submit on text fields, which has no
equivalent here (this screen has no text input or submit action). Verified
via Flutter SDK source (Flutter 3.41.0, this project's pinned SDK):
- `ButtonStyleButton.enabled` (`button_style_button.dart:242`) is
  `onPressed != null || onLongPress != null` — wired straight into the
  underlying `InkWell`'s `canRequestFocus`.
- `_InkResponseState._canRequestFocus`
  (`ink_well.dart:1333-1336`) combines that `enabled` flag with
  `NavigationMode` to decide focusability, then feeds it directly into
  `Focus(canRequestFocus: ...)` (`ink_well.dart:1392`).
- `FocusTraversalPolicy`'s candidate-node filter
  (`focus_manager.dart:687,725`) excludes any node with
  `canRequestFocus == false` from the Tab-traversal set entirely — not
  merely inert when activated, but structurally skipped.

**Consequence for FR-009**: a disabled control (the next-month button when
the selected month is the current month) is *unreachable* by Tab under
Flutter's default `NavigationMode.traditional` (the app's mode — no
`Shortcuts`/`FocusTraversalGroup` override sets `NavigationMode.directional`
anywhere in this codebase, confirmed by the same source check). This makes
FR-009's "MUST be clearly indicated as non-interactive when it holds focus"
clause **structurally satisfied by construction** — that state (a disabled
button holding keyboard focus) cannot occur, so no additional visual-state
code is needed for it specifically. The disabled button still needs its
existing visual disabled-appearance (already present, unmodified) and MUST
simply be *skipped* by Tab traversal (verified, not built) rather than
landed-on-and-inert.

**Alternatives considered**:
- Writing defensive code to explicitly hide/disable focus on the next-month
  button: rejected — redundant with Flutter's default behavior verified
  above; would be dead code with no observable effect, violating
  constitution Principle I's prohibition on unnecessary complexity.
- Assuming a gap exists without checking (as a previous feature's research
  initially over-assumed for Enter-to-submit before verifying): rejected —
  this feature explicitly checked via source grep first, per the "trust but
  verify" lesson from the Auth screens redesign's own corrected
  Enter-to-submit research.

## Decision 4: Widget test pattern for breakpoint + keyboard coverage

**Decision**: Reuse the exact test pattern already established by the Auth
screens redesign's widget tests: `tester.view.physicalSize` +
`tester.view.devicePixelRatio = 1.0` for breakpoint pumps (not the
deprecated `tester.binding.window` API), `tester.sendKeyEvent
(LogicalKeyboardKey.tab)` for traversal tests asserting
`FocusManager.instance.primaryFocus` is non-null at each stop, and this
repository's project-wide pinned reference widths — 410dp for "compact"
(matching `test/flutter_test_config.dart`'s documented default, not an
unverified 375dp), 1024dp for "expanded" (already used by every prior
adaptive-layout test file in this repo).

**Rationale**: Consistency with every other adaptive-layout test file in
this repository (Auth screens: `sign_in_screen_test.dart` etc.; Home
Overview / Monthly Report's own breakpoint tests) avoids introducing a
second, divergent test-authoring convention, and reuses widths this project
has already separately verified are safe (410dp does not overflow this
app's headers, unlike the unverified 375dp a prior feature's first draft
mistakenly used before correcting it).

**Alternatives considered**:
- Golden/screenshot tests: constitution Principle II says golden tests
  "SHOULD be used ... where pixel-level regressions matter (charts, balance
  summaries)" — Transaction History's list-row layout is not in that
  category (no chart, no aggregate-summary widget being introduced here),
  so plain widget-test size/position assertions (already this repo's
  standard for layout-cap verification) are sufficient and consistent with
  precedent.
