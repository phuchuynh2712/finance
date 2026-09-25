# Phase 0 Research: Adaptive Layout Foundation

## Decision 1: Width measurement — `MediaQuery.sizeOf`, not `LayoutBuilder` or unscoped `MediaQuery.of(...).size`

**Decision**: The single place that decides bottom-bar-vs-rail
(`_AppShellState.build()` in `lib/core/router/app_router.dart`) reads
`MediaQuery.sizeOf(context).width`.

**Rationale**: The decision needs the *window's* width, not the incoming
constraints of some inner widget, which is what `LayoutBuilder` measures —
`LayoutBuilder` is the right tool inside a widget whose own box has already
been constrained by its parent (e.g. `AdaptiveBody`, Decision 5 below), but
the app shell itself sits directly under `MaterialApp.router`, where its
available size *is* the window size, so `MediaQuery` is the correct source.
`MediaQuery.sizeOf(context)` (the scoped accessor) is used instead of the
older `MediaQuery.of(context).size` because `sizeOf` only registers a
dependency on the `size` field specifically — the shell rebuilds when width
changes, but not when an unrelated `MediaQuery` field changes (text scale,
platform brightness, padding), satisfying the constitution's Principle IV
scoped-rebuild rule.

**Alternatives considered**: `LayoutBuilder` wrapping the whole shell —
rejected; at the shell's position in the tree its constraints already equal
the window size, so it would work today, but it's the wrong semantic tool
and would behave incorrectly if the shell were ever nested under something
that constrains it (e.g. an outer padding/inset), which `MediaQuery` is not
sensitive to. Unscoped `MediaQuery.of(context).size` — rejected as a needless
over-rebuild.

## Decision 2: Preserving screen state across a breakpoint crossing — a stable `GlobalKey` on `navigationShell`

**Decision**: `_AppShellState` owns a single `GlobalKey` (created once, in
`initState`, not rebuilt per `build()` call), attached to
`widget.navigationShell` in *both* the compact and expanded branches of
`_AppShellState.build()`.

**Rationale**: Resolves Clarification Q2 ("the screen is not remounted,
only the navigation chrome changes") concretely. `_AppShellState.build()`
must return structurally different trees for the two layouts — compact:
`Scaffold(body: navigationShell, bottomNavigationBar: NavigationBar(...))`;
expanded: `Scaffold(body: Row(children: [NavigationRail(...), Expanded(child:
navigationShell)]))`. Without a `GlobalKey`, Flutter's reconciliation
compares the widget at each tree *position*; since `navigationShell`'s
immediate parent differs between the two branches (`Scaffold` directly vs.
`Expanded` nested in `Row`), a plain/no key would make Flutter treat it as
a different element on a layout switch and dispose the old one — tearing
down and rebuilding the whole currently-active screen (losing scroll
position, unsubmitted text, everything Clarification Q2 requires to
survive). The installed Flutter SDK's own `GlobalKey` documentation
(`/opt/flutter/packages/flutter/lib/src/widgets/framework.dart`) confirms
this is exactly the supported mechanism for this situation: *"Widgets that
have global keys reparent their subtrees when they are moved from one
location in the tree to another location in the tree... Reparenting an
Element using a global key is relatively expensive, as this operation will
trigger a call to `State.deactivate` on the associated State and all of its
descendants; then force all widgets that depend on an `InheritedWidget` to
rebuild."* — `deactivate`, not `dispose`: the `State` object itself (and
therefore scroll controllers, text controllers, and `StatefulShellRoute`'s
own internal `IndexedStack`-backed per-tab state) survives the move. The
same doc's "Pitfalls" section is why the key must be created once and
owned by `_AppShellState`, not constructed inline in `build()` — a
freshly-created key every build would defeat the whole purpose.

**Alternatives considered**: Rebuilding both branches from a single shared
sub-widget defined once and referenced with a plain (non-global) `Key` in
each branch — rejected; a plain `Key` only helps Flutter match elements at
the *same* position across two builds of the *same* parent structure, it
does not let a widget move to a structurally different parent (`Scaffold`
directly vs. `Row > Expanded`) without disposal, which is exactly this
feature's situation. Restructuring the shell so `navigationShell` always
sits at the same structural position (e.g. always inside a `Row`, with the
rail conditionally `SizedBox.shrink()`-collapsed in compact mode) —
rejected as needlessly clever and a departure from `NavigationBar`'s own
expected `Scaffold.bottomNavigationBar` slot, for a benefit (`avoiding the
GlobalKey`) that isn't needed once the key's cost is understood to be a
one-time, crossing-only cost (Decision 3 of the Performance Goals
reasoning in plan.md), not a steady-state one.

## Decision 3: Rail label visibility — `NavigationRailLabelType.all`

**Decision**: The `NavigationRail` is configured with
`labelType: NavigationRailLabelType.all`.

**Rationale**: Directly resolves Clarification Q1. Confirmed present in
the installed SDK (`/opt/flutter/packages/flutter/lib/src/material/
navigation_rail.dart`): `NavigationRailLabelType` has exactly three values
— `none` ("Only the destinations are shown"), `selected` ("Only the
selected destination will show its label"), and `all` ("All destinations
will show their label") — `all` is the one matching "icon + text label
always visible, matching the bottom bar's existing presentation."

**Alternatives considered**: `.none`/`.selected` — rejected, both were the
literal alternatives offered in Clarification Q1 and not chosen.

## Decision 4: Pinning the test suite's default surface size — a new `test/flutter_test_config.dart`

**Decision**: Add `test/flutter_test_config.dart` (the filename
`flutter_test`'s own test runner specifically recognizes and auto-wraps
every test in that directory tree with, before this feature's first
functional task), pinning `tester.view.physicalSize` /
`tester.view.devicePixelRatio` to an explicit compact reference size
(390×844 logical — a common phone reference size already used ad hoc by
one existing test, `expense_screen_test.dart`) for any test that doesn't
already set its own surface size.

**Rationale**: Empirically measured in this session (not assumed) by
running a throwaway probe test on the project's actual installed toolchain
(Flutter 3.41.0): `flutter_test`'s default is `physicalSize=2400×1800`,
`devicePixelRatio=3.0`, i.e. **800×600 logical pixels** — which is already
*past* this feature's own 600dp compact/expanded breakpoint. Concretely,
today, every existing widget test that never calls `tester.view
.physicalSize = ...` (the overwhelming majority of this project's 386
tests) is implicitly running at a width this feature will treat as
"expanded." Without an explicit pin, shipping this feature would silently
flip what those tests exercise — e.g. `app_shell_nav_bar_test.dart`
currently asserts a `NavigationBar` is present; after this feature, at the
unpinned 800px-wide default, it would instead find a `NavigationRail` and
fail for a reason having nothing to do with what it's actually testing.
This is precisely the risk the constitution's amended Principle II
anticipates ("The test suite MUST pin an explicit default test viewport...
so existing tests do not silently change meaning as adaptive breakpoints
are introduced") — this decision is that requirement's concrete
implementation, and it is ordered as this feature's first task specifically
because every other task's tests depend on it being in place first.

**Alternatives considered**: Leaving the default as-is and instead adding
`tester.view.physicalSize = ...` to every individual test file that needs a
specific width — rejected; it fixes only the tests someone remembers to
touch, leaves every *other* existing test silently exposed to the
800×600-is-already-expanded problem above, and violates the constitution's
explicit "pin an explicit default" (singular, suite-wide) wording. A wider
or narrower default than 390×844 — 390×844 was chosen because it is already
used by an existing test in this repo (`expense_screen_test.dart`) and
comfortably sits in "compact" (<600dp) with margin, so it does not itself
sit near a boundary.

## Decision 5: Content max-width mechanism — `AdaptiveBody` (`ConstrainedBox` + `Center`)

**Decision**: A new `lib/core/widgets/adaptive_body.dart` wraps a child in
`Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: token),
child: child))`, used inside Tổng quan's and Báo cáo's existing top-level
`ListView`/content column (replacing the direct content, not the screen's
outer `Scaffold`/`SafeArea`/header — those stay as-is).

**Rationale**: Standard, well-understood Flutter composition; needs no new
package. Placed in `core/widgets/` because it has two consumers from its
first commit (Tổng quan, Báo cáo — FR-005/FR-006), meeting the
constitution's "`core/` only once ≥2 features/screens need it" bar
immediately, unlike the Report feature's single-consumer usage-bar
precedent which had to stay feature-local for exactly that reason.

**Alternatives considered**: A `LayoutBuilder`-driven manual width
calculation per screen — rejected as unnecessary duplication of what
`ConstrainedBox` already does declaratively, and harder to keep the
960px-default value consistent across the two screens without a shared
constant (which `AdaptiveBody` already centralizes via Decision 9).

## Decision 6: Uniform ≥48×48dp tap target, including desktop — explicit `AppTheme` override

**Decision**: `AppTheme.light` and `AppTheme.dark` both explicitly set
`visualDensity: VisualDensity.standard` and `materialTapTargetSize:
MaterialTapTargetSize.padded` on their `ThemeData`, rather than leaving
Flutter to pick its own per-platform default.

**Rationale**: Confirmed directly against the installed SDK
(`/opt/flutter/packages/flutter/lib/src/material/theme_data.dart`):
`ThemeData`'s own defaulting logic (`materialTapTargetSize ??= ...`,
`visualDensity ??= VisualDensity.defaultDensityForPlatform(platform)`)
picks `MaterialTapTargetSize.shrinkWrap` and a `compact` `VisualDensity`
specifically for `TargetPlatform.linux/.macOS/.windows` — i.e., anyone
running this app's Flutter *web build* in a desktop browser (`kIsWeb` with
`defaultTargetPlatform` resolved to one of those three) already gets a
smaller effective tap target than the app's own constitution-mandated
≥48×48dp minimum, purely from Flutter's own defaults, with zero code in
this project currently overriding it. Setting both fields explicitly,
project-wide, in the one place (`AppTheme`) that already defines every
other token, satisfies FR-007/SC-003 for the entire app in a single change
— no per-screen or per-widget work needed, exactly matching User Story 3's
"implemented once at the shared theme level" independent-test claim.

**Alternatives considered**: Per-widget `ConstrainedBox(constraints:
BoxConstraints(minWidth: 48, minHeight: 48))` wrapping — rejected; this is
already the ad hoc pattern several existing widgets use today (e.g.
`expense_item_row.dart`, `allocation_mode_toggle.dart`, per the codebase
survey behind this feature's research), and it is exactly the
per-screen-repetition the constitution's FR-010-equivalent shared-token
principle exists to avoid; a single theme-level fix supersedes the need for
any *new* instances of that pattern (existing ones are harmless left as-is,
since 48dp ⊇ Flutter's smaller default either way).

## Decision 7: Tooltip text source — reuse existing localized labels first

**Decision**: For each icon-only control this feature touches, `Tooltip
.message` is sourced from that control's existing localized string where
one is already defined and semantically appropriate (e.g. a screen's own
`AppLocalizations` title/action string); a new ARB key (`vi` + `en`, per
the constitution's Localization rule) is added only where no suitable
existing string exists.

**Rationale**: Avoids duplicate/drifting copies of the same string under
two different ARB keys; keeps this feature's localization footprint
minimal (most navigation-adjacent icon buttons already have a label
somewhere — e.g. the navigation destinations themselves already carry
`l10n.tabOverview` etc.). The exact enumeration of which specific icon
buttons need a *new* key (as opposed to reusing one) is a `/speckit-tasks`-
level activity, not a plan-level one — this decision fixes the *policy*,
not the exhaustive list.

**Alternatives considered**: A blanket new ARB key per icon button
regardless of whether a suitable string already exists — rejected as
needless duplication and added translation-maintenance burden.

## Decision 8: Keyboard focus order — Flutter's default traversal, no custom policy

**Decision**: No custom `FocusTraversalPolicy`/`FocusTraversalGroup`
ordering is introduced; FR-009 is satisfied by Flutter's own default
reading-order traversal over the existing, already-linear widget structure
of the screens this feature touches (shell navigation, Tổng quan, Báo cáo).

**Rationale**: All three affected surfaces are already simple, top-to-bottom
Material layouts (`Column`/`ListView` of `Row`s) with no custom absolute
positioning or `Stack`-based layering that would confuse the default
order. Introducing a custom policy without a concrete failure to fix would
be unjustified complexity per the constitution's Governance section
("unjustified complexity is grounds for rejecting a plan").

**Alternatives considered**: A project-wide custom `FocusTraversalPolicy`
— deferred; if a *specific* later screen (e.g. one of the more complex
per-screen redesigns in spec.md's Out of Scope §B, such as Kiểm soát's
grid) turns out to need one, that is that follow-up feature's decision to
make against its own concrete layout, not something to speculatively add
here.

## Decision 9: One shared destination-data list feeding both navigation widgets

**Decision**: `_AppShellState` builds one small, ordered, plain-data list
(5 entries: icon, a label-string getter, and the existing route-branch
index) once, and maps it to a `List<NavigationDestination>` for the
compact branch and a `List<NavigationRailDestination>` for the expanded
branch at build time, rather than hand-maintaining two separate destination
literals.

**Rationale**: Confirmed via the installed SDK that `NavigationBar` and
`NavigationRail` take genuinely different destination types —
`NavigationDestination` (`navigation_bar.dart`) vs.
`NavigationRailDestination` (`navigation_rail.dart`, `required this.icon`
plus a label) — so they cannot literally share one list, but a single
source-of-truth list of plain data, mapped to each shape at the point of
use, prevents the two presentations' destinations (icon, label, order)
from silently drifting apart from each other over time — a real risk given
this project's existing pattern of writing the 5
`NavigationDestination`s out by hand directly inside `build()`
(`app_router.dart`, current `_AppShellState.build()`).

**Alternatives considered**: Leaving two independently-hand-written
destination lists (today's pattern, extended with a second copy for the
rail) — rejected; directly invites the two presentations to disagree after
a future edit touches one but not the other.

## Decision 10: Shared breakpoint/max-width tokens — `core/theme/app_layout.dart`, full 5-value scale

**Decision**: A new `lib/core/theme/app_layout.dart` defines a
`WindowSizeClass` enum with all five of the constitution's reference values
(`compact`, `medium`, `expanded`, `large`, `extraLarge` at the 600/840/
1200/1600dp thresholds) plus a pure `windowSizeClassFor(double width)`
classifier and the content-max-width constant(s) this feature uses — even
though this feature's own requirements only branch on two of those five
thresholds (600 for navigation, 840 for content width).

**Rationale**: The constitution requires these breakpoints be "defined
once as shared tokens in `core/theme/`" project-wide, not merely for this
feature — later follow-up work (spec.md Out of Scope §B's per-screen
redesigns, which may need the 1200/1600dp tiers this feature itself does
not consume) should extend usage of this one definition, not redefine the
scale a second time. Keeping the enum's shape aligned with the full,
already-ratified constitution scale now is cheaper than two nearly-identical
enums existing later.

**Alternatives considered**: A minimal two-value enum (`compact`/`expanded`)
scoped tightly to only what this feature needs — rejected; would need a
breaking rename/extension the moment any follow-up feature needs the
large/extra-large tiers, for a definition the constitution already fixes
today.
