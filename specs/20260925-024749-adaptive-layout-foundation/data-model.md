# Phase 1 Data Model: Adaptive Layout Foundation

All types below are new, framework-independent (or thin-Flutter) value
types introduced by this feature. None are persisted — there is no new
database table, column, or migration; nothing here is a domain entity in
the constitution's sense. They exist purely to give the shell and the two
touched screens (Tổng quan, Báo cáo) a single, shared, testable source of
truth for layout decisions, per Principle III and research.md Decisions 9–10.

## `WindowSizeClass`

Defined in `lib/core/theme/app_layout.dart`. A plain Dart `enum`, zero
Flutter dependency.

| Value | Lower bound (inclusive) | Meaning |
|---|---|---|
| `compact` | 0dp | Phone portrait; bottom-bar navigation (FR-001) |
| `medium` | 600dp | Rail navigation begins (FR-001); below content-width cap |
| `expanded` | 840dp | Rail navigation; content-width cap begins (FR-005/FR-006) |
| `large` | 1200dp | Reserved for later features (research.md Decision 10) — this feature draws no distinct behavior from it |
| `extraLarge` | 1600dp | Reserved for later features — same as above |

This feature's own logic only distinguishes two boundaries derived from
this enum: `< medium` (bottom bar) vs. `>= medium` (rail), and
`< expanded` (content unconstrained) vs. `>= expanded` (content capped).
The `large`/`extraLarge` tiers exist so later features consume the same
enum rather than inventing a second one (research.md Decision 10) — they
are not dead code in the sense of the constitution's "no dead code" rule,
since the enum's job is to be the one project-wide breakpoint scale, not to
have every value consumed by every feature that uses it.

## `windowSizeClassFor(double width)`

A pure function, `WindowSizeClass windowSizeClassFor(double width)`, in the
same file. Given a logical width in dp, returns the matching
`WindowSizeClass` per the table above (boundary values belong to the
*higher* class — e.g. exactly `600.0` → `medium`, matching Material's own
"`600dp` and above" phrasing and this feature's Edge Cases entry on
boundary consistency).

**Validation rule**: `width` MUST be `>= 0`; behavior for a negative width
is undefined (not a realistic input — `MediaQuery.sizeOf(context).width` is
never negative) and is not tested.

**Consumers**: `_AppShellState.build()` (bar vs. rail — only checks
`>= medium`); `AdaptiveBody` (capped vs. uncapped — only checks
`>= expanded`).

## `AppLayoutTokens` (constants, same file)

| Constant | Value | Used by |
|---|---|---|
| `contentMaxWidth` | `960.0` (logical px) | `AdaptiveBody` (FR-005/FR-006, SC-002) — the Tổng quan/Báo cáo starting default per spec.md Assumptions |

Only one width constant exists at this feature's scope; later per-screen
follow-ups (spec.md Out of Scope §B — e.g. a narrower ~440–480dp value for
the auth screens' centered card) may add their own constants here or
locally, decided when each screen is tackled, per spec.md's own Assumptions
section.

## `_NavDestinationSpec` (private, `app_router.dart`)

The single source-of-truth list research.md Decision 9 introduces, feeding
both navigation widgets. Not exported — internal to the shell.

| Field | Type | Meaning |
|---|---|---|
| `icon` | `IconData` | Same `lucide_icons` constant already used today per destination |
| `label` | `String Function(AppLocalizations)` | Defers localization lookup to build time (matches the existing pattern of reading `l10n.tabOverview` etc. inside `build()`) |
| `branchIndex` | `int` | The existing `StatefulShellRoute` branch index (unchanged — 0..4, same order as today) |

Exactly 5 instances, in the same order as today's `_AppShellState.build()`
(Tổng quan, Kiểm soát, Thu chi, Báo cáo, Hồ sơ) — this feature does not
reorder, add, or remove a destination.

**Derivation**:
- Compact branch: `destinations.map((d) => NavigationDestination(icon:
  Icon(d.icon), label: d.label(l10n)))`.
- Expanded branch: `destinations.map((d) => NavigationRailDestination(icon:
  Icon(d.icon), label: Text(d.label(l10n))))`, with the rail's own
  `labelType: NavigationRailLabelType.all` (research.md Decision 3) so
  every label renders regardless of selection state.

## Relationship to existing entities

None. This feature reads no domain entity (`ExpenseControlItem`,
`TransactionHistoryRecord`, etc.) and defines no new persisted shape. Its
only "state" beyond the pure values above is the `GlobalKey` research.md
Decision 2 introduces on `_AppShellState` — an implementation detail of
*how* `navigationShell` is kept alive across a layout switch, not a data
model in its own right (it carries no fields of its own; it is a Flutter
framework identity token).
