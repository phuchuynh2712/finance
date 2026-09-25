# Internal UI Contract: Adaptive Layout Foundation

## Purpose

Define the internal application/UI contract for the app shell's
window-size-driven navigation switch and the two touched screens' content
max-width. This is an internal Flutter application contract, not a public
HTTP API. This feature is presentation/theme-layer only — see "Gateway
Contracts" below.

## Gateway Contracts

**None new.** This feature reads no repository, no database, no network
call — it introduces no new data dependency and changes no existing one.
`_AppShellState`, `AdaptiveBody`, and `windowSizeClassFor` all operate only
on `MediaQuery`-supplied window geometry and (for the shell) the already-
existing `AppLocalizations`/`StatefulNavigationShell` inputs it already
receives today.

## Presentation Contracts

### `windowSizeClassFor(double width) -> WindowSizeClass`

- **Input**: a non-negative logical width in dp.
- **Output**: the `WindowSizeClass` whose range contains `width` (data-model.md).
- **Purity**: no side effects, no `BuildContext`, unit-testable directly.

### `_AppShellState` (existing widget, reworked build)

- **Input** (unchanged from today): `widget.navigationShell`
  (`StatefulNavigationShell`, provided by `GoRouter`'s
  `StatefulShellRoute.indexedStack` — unchanged, no new route/path), plus
  `MediaQuery.sizeOf(context).width` (new read).
- **Output states**:
  | `windowSizeClassFor(width)` | Navigation presentation | Destination labels |
  |---|---|---|
  | `compact` (<600dp) | `NavigationBar` (bottom) | icon + label (unchanged from today) |
  | `medium`/`expanded`/`large`/`extraLarge` (≥600dp) | `NavigationRail` (side) | icon + label always visible (`NavigationRailLabelType.all` — Clarification Q1) |
- **Identity contract**: `widget.navigationShell` is wrapped with the same
  `GlobalKey` instance in both output states (research.md Decision 2) — a
  caller/test MUST be able to resize across the 600dp boundary and observe
  that a descendant screen's own local state (scroll offset, an
  uncommitted `TextField`'s content) is unchanged afterward (Clarification
  Q2, spec.md Acceptance Scenario 5).
- **Unsaved-Kiểm-soát-edits contract** (existing, unchanged behavior):
  regardless of which of the two output states triggered
  `_handleDestinationSelected`, the existing `_DiscardPromptDialog` gate
  fires identically (FR-004) — this feature does not touch
  `_handleDestinationSelected`'s logic, only what renders around it.

### `AdaptiveBody` (new widget)

- **Input**: `child` (the screen's main content column), an optional
  `maxWidth` override (defaults to `AppLayoutTokens.contentMaxWidth`, i.e.
  960dp — data-model.md).
- **Output states**:
  | Window width | Behavior |
  |---|---|
  | `< 840dp` (`compact`/`medium`) | passthrough — `child` unchanged, full available width (FR-006) |
  | `>= 840dp` (`expanded`+) | `child` centered, capped at `maxWidth` (FR-005) |
- **Used by**: `overview_screen.dart`, `report_screen.dart` only, in this
  feature. Every other screen is explicitly unchanged (spec.md Out of
  Scope §B).

## Error Contract

**None new.** `windowSizeClassFor` cannot fail for any realistic input
(width is always ≥0 from `MediaQuery`); `AdaptiveBody` and the reworked
`_AppShell` introduce no new async operation, no new loading/error
`AsyncValue` branch — the screens' *existing* loading/error handling
(`overview_summary_service`, `report_summary`, etc.) is untouched, only
wrapped by a layout primitive that has no failure mode of its own.

## Navigation Contract

**None new.** This feature introduces zero new routes/paths. The five
existing `StatefulShellRoute` branches
(`/overview /expense-control /spending /history /account`) are unchanged.
The `Navigator.push`/`MaterialPageRoute` call sites noted in spec.md's Out
of Scope §A.7 are explicitly untouched by this feature — they remain a
follow-up concern for whichever spec restructures navigation for list-detail
layouts.
