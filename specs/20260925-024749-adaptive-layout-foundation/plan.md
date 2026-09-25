# Implementation Plan: Adaptive Layout Foundation

**Branch**: `20260925-024749-adaptive-layout-foundation` | **Date**: 2026-09-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from
`specs/20260925-024749-adaptive-layout-foundation/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See
`.specify/templates/plan-template.md` for the execution workflow.

## Summary

Make the app's navigation shell and its two busiest screens (Tổng quan,
Báo cáo) respond to the window they're actually running in, instead of
rendering an identical single-column mobile layout everywhere. The primary
navigation switches between a bottom bar (<600dp) and a side rail (≥600dp,
icon+label always visible per Clarification Q1); Tổng quan and Báo cáo cap
their content at a shared max-width and center it once the window reaches
840dp; every interactive control gets a uniform ≥48×48dp target, a tooltip
when icon-only, and full keyboard reachability — enforced once at the
shared theme level so it applies everywhere immediately. Per Clarification
Q2, the currently viewed screen's own local state (scroll position,
unsubmitted form input) MUST survive a breakpoint crossing — the screen is
reparented via a stable `GlobalKey`, not rebuilt, when the shell's chrome
switches. A pre-existing, previously-invisible test-configuration gap is
fixed as part of Phase 2's first task: `flutter_test`'s own default
surface size (empirically confirmed at 800×600 logical pixels — see
research.md Decision 4) is already past this feature's own 600dp
navigation breakpoint, so every existing widget test that doesn't
explicitly set a surface size needs an explicit, pinned default before
this feature can ship without silently breaking them.

## Technical Context

**Language/Version**: Dart 3.11 / Flutter 3.41.0 (existing project; toolchain
verified installed and run in this session — `flutter analyze`/`flutter
test` both pass clean on the current `main` before this feature's changes).

**Primary Dependencies**: Flutter Material (`NavigationBar`, `NavigationRail`
— both already available in the installed SDK; no new package), Riverpod
(`flutter_riverpod`), GoRouter (`StatefulShellRoute.indexedStack`, unchanged
by this feature — see research.md Decision 9 / contracts), existing
`AppTheme`/`AppSemanticColors` tokens. No new runtime package is required
(constitution's dependency-hygiene rule: prefer `MediaQuery`/`LayoutBuilder`
over third-party responsive packages, several of which are unmaintained or
discontinued as of this amendment — Principle III).

**Storage**: Unchanged. This feature reads no new data and touches no
database, migration, or repository — purely presentation/theme layer.

**Testing**: `flutter analyze`, `dart format --output=none
--set-exit-if-changed`, a new `test/flutter_test_config.dart` pinning the
default widget-test surface size (Phase 2, first task — see Summary),
focused unit/widget tests at both a compact (<600dp) and an expanded
(≥840dp) width per the constitution's amended Principle II, then
`flutter test` (currently 386 tests, all passing — must stay green per
FR-012/SC-005).

**Target Platform**: Android, iOS, and Web (per constitution v1.5.0's
Multi-Platform Support section — Web is a fully supported target, not a
stretch goal, for layout purposes; this feature does not touch the
separately-tracked Web data-layer defect — see Constitution Check below and
spec.md's "Out of Scope & Follow-Up Work" §A). Native Desktop stays
out of scope (no platform folders exist yet); nothing in this feature
blocks adding one later, per the same section.

**Project Type**: Feature-first mobile/web Flutter application.

**Performance Goals**: A breakpoint crossing (window resize) must not
visibly jank — the `GlobalKey` reparent (research.md Decision 2) is a
bounded, one-time cost exactly at the moment of crossing, not a per-frame
cost; `MediaQuery.sizeOf(context)` (not the unscoped `MediaQuery.of
(context).size`) is used at the single decision point so only the shell
itself rebuilds on a width change, not every `MediaQuery`-dependent widget
in the tree (constitution Principle IV's scoped-rebuild rule).

**Constraints**: No new route/path is introduced (existing
`/overview /expense-control /spending /history /account` paths and the
`StatefulShellRoute.indexedStack` branches are unchanged — only what wraps
`navigationShell` changes, per Clarification Q2 and research.md Decision
2); no new persisted preference (no manual "desktop mode" toggle, per
spec.md Assumptions); Vietnamese and English localization for any new
tooltip string; existing light/dark tokens reused, no new color.

**Scale/Scope**: One new pure module (`lib/core/theme/app_layout.dart`);
one new shared widget (`lib/core/widgets/adaptive_body.dart`); one reworked
existing widget (`_AppShell` in `lib/core/router/app_router.dart`); one
theme change (`lib/core/theme/app_theme.dart` — explicit density/tap-target
override); two screens updated to use the new shared widget (Tổng quan,
Báo cáo); one new test-infrastructure file
(`test/flutter_test_config.dart`); no new feature directory, no new route,
no repository/domain change.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

- **Principle I — Code Quality: PASS.** `windowSizeClassFor()` (research.md
  Decision 9) is a plain, framework-independent Dart function outside any
  `build()`; `AdaptiveBody` and the reworked `_AppShell` stay
  state/rendering only, with the breakpoint decision itself delegated to
  that pure function so it's unit-testable without pumping a widget tree.
- **Principle II — Testing Standards: PASS, with a required foundational
  fix first.** `flutter_test`'s own default surface size is 800×600
  logical pixels (empirically confirmed this session — research.md
  Decision 4) — already past this feature's own 600dp breakpoint. Every
  existing widget test that does not explicitly set a surface size is
  therefore implicitly "expanded" today and would silently start seeing a
  rail instead of a bottom bar once `_AppShell` changes, breaking tests
  like `app_shell_nav_bar_test.dart` for a reason unrelated to what they're
  actually asserting. `test/flutter_test_config.dart` (Phase 2's first
  task) pins a compact default before any other change lands, satisfying
  the constitution's "pin an explicit default test viewport" requirement
  and keeping every pre-existing test's assumed width unchanged. New
  coverage: `windowSizeClassFor()` unit tests (boundary values at 600/840/
  1200/1600 exactly, per the constitution's breakpoint scale); `_AppShell`
  widget tests at both a compact and an expanded width, including a resize
  scenario asserting `GlobalKey` reparenting actually preserves a
  descendant screen's scroll position/text-field content (Clarification
  Q2); `AdaptiveBody` widget tests (below/at/above 840dp); extended
  Tổng quan/Báo cáo widget tests for the capped width at ≥840dp; a
  tap-target-size sweep assertion at a desktop-sized window. Existing
  domain/data coverage is untouched by this feature and stays ≥80%.
- **Principle III — User Experience Consistency & Adaptive Design: PASS —
  this feature is the direct implementation of this principle's new
  adaptive-layout mandate.** Window-size-driven, not platform-driven
  (`MediaQuery.sizeOf`, never `Platform.is*`/`kIsWeb`/`defaultTargetPlatform`
  — FR-002); Material's window-size-class breakpoints defined once as
  shared tokens in `core/theme/app_layout.dart` (constitution's amended
  `theme/` bullet), not re-derived per screen; bottom bar <600dp / rail
  ≥600dp with icon+label always visible (Clarification Q1,
  `NavigationRailLabelType.all` — confirmed present in the installed SDK),
  no navigation drawer; content max-width capped and centered via the new
  shared `AdaptiveBody` (FR-005/FR-006); the existing ≥48×48dp minimum is
  enforced even on desktop by explicitly overriding Flutter's own
  platform-scoped defaults in `AppTheme` (research.md Decision 6, citing
  the installed SDK's `theme_data.dart`) rather than accepting them;
  tooltips on icon-only controls and full keyboard reachability (FR-008/
  FR-009) via `Tooltip` + Flutter's default focus traversal, no custom
  policy needed (research.md Decisions 7–8); no third-party responsive
  package added — pure `MediaQuery`/`LayoutBuilder`, per the constitution's
  dependency-hygiene cross-reference.
- **Principle IV — Performance: PASS.** `MediaQuery.sizeOf` scopes the
  shell's own rebuild to width changes only; the `GlobalKey` reparent is a
  bounded one-time cost exactly at a breakpoint crossing (Flutter's own
  `GlobalKey` documentation — research.md Decision 2), not a steady-state
  or per-frame cost; no new list, no new query, no work moved onto or off
  the UI isolate.
- **Clean Architecture / Recommended Architecture: PASS.** `AdaptiveBody`
  lives in `core/widgets/` with two immediate consumers at inception
  (Tổng quan, Báo cáo), satisfying the constitution's "`core/` only once
  ≥2 features/screens need it" rule from first use, unlike the Report
  feature's usage-bar precedent (which stayed feature-local because only
  one screen used it initially) — this one qualifies for `core/` from the
  start. `app_layout.dart` lives in `core/theme/`, matching the
  constitution's amended bullet exactly. No new repository, no new DI
  registration, no feature importing another feature's `presentation/`.
- **Offline-First Data & Sync: N/A.** No database, migration, sync, or
  repository change — this feature is presentation/theme layer only.
- **Multi-Platform Support: PASS for this feature's own changes, with an
  explicitly-flagged, still-open constitution conflict it does not
  resolve.** This feature makes the shell and two screens lay out
  correctly at any window size, including in a browser — a real, net
  improvement for Web. It does **not** fix the separately-tracked Web
  data-layer defect (Drift never opens on Web today because
  `driftDatabase()` is missing the required `web:` option — spec.md
  "Out of Scope & Follow-Up Work" §A.1, pre-existing, not introduced or
  worsened by this feature). Web is no better and no worse off *for data*
  after this feature than before it; it is strictly better *for layout*.
  **`/speckit-analyze` correctly flagged this as CRITICAL** per this
  command's own non-negotiable-constitution rule: the constitution's
  "Web is a fully supported target, not a stretch goal... is a Principle I
  defect, not an acceptable platform gap" wording is unconditional, and
  that defect is live right now, independent of this feature. This PASS is
  therefore scoped narrowly to "this feature's own diff does not violate
  or worsen the constitution" — it is **not** a claim that the repository
  as a whole is currently constitution-compliant on Web. That gap is
  tracked in spec.md §A with a required (not optional) follow-up
  (`web-platform-enablement`), which should start promptly. Platform-
  capability differences this feature does touch (none — it introduces no
  capability check) are N/A.
- **Security: N/A.** No secret, token, auth flow, or logging change; the
  security-relevant Web gaps (no app-level lock, experimental secure
  storage) are explicitly deferred to §A, unchanged by this feature.
- **Development Workflow: PASS (procedural).** Feature branch discipline
  followed per the session's own branch requirement (see Project Structure
  note below); `core/theme/`, `core/widgets/`, and `core/router/` are all
  shared `core/` utilities, so this PR's description will call out the
  breaking-adjacent nature of the `_AppShell`/`AppTheme` changes per the
  constitution's Development Workflow bullet (theming/breakpoint changes
  → Principle III; this is not a DI/database/sync change, so the
  Recommended Architecture/Offline-First cross-reference does not apply).

**Post-design re-check**: PASS for this feature's own scope. Phase 1
design introduces no new package, external service, network call, or
unapproved architecture exception. The one item worth naming plainly: the
Multi-Platform Support Web-data gap (above) **is** an open constitution
violation today, at the repository level — this feature does not create
or worsen it, and does not claim to resolve it; it is tracked, not hidden,
in spec.md §A, with the urgency `/speckit-analyze` confirmed.

## Project Structure

### Documentation (this feature)

```text
specs/20260925-024749-adaptive-layout-foundation/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md         # Phase 1 output (/speckit-plan command)
├── contracts/            # Phase 1 output (/speckit-plan command)
├── checklists/            # Spec quality checklist (/speckit-specify command)
└── tasks.md               # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
lib/
├── core/
│   ├── theme/
│   │   ├── app_layout.dart                # NEW: WindowSizeClass enum,
│   │   │                                    # windowSizeClassFor(width), shared
│   │   │                                    # breakpoint + content-max-width
│   │   │                                    # constants (constitution's amended
│   │   │                                    # theme/ bullet — Principle III)
│   │   └── app_theme.dart                  # MODIFIED: explicit
│   │                                        # visualDensity/materialTapTargetSize
│   │                                        # override in both AppTheme.light/.dark
│   │                                        # (research.md Decision 6)
│   ├── widgets/
│   │   └── adaptive_body.dart              # NEW: shared max-width + center
│   │                                        # wrapper (2 consumers at inception —
│   │                                        # qualifies for core/ from the start)
│   └── router/
│       └── app_router.dart                 # MODIFIED: _AppShell/_AppShellState —
│                                            # window-size-driven bar/rail switch,
│                                            # GlobalKey-stabilized navigationShell,
│                                            # shared destination-data list feeding
│                                            # both NavigationDestination and
│                                            # NavigationRailDestination (no route/
│                                            # path change — same 5 branches)
├── features/
│   └── expenses/
│       └── presentation/
│           ├── overview_screen.dart        # MODIFIED: wrap main content in
│           │                                # AdaptiveBody (FR-005/FR-006)
│           └── report_screen.dart          # MODIFIED: same
test/
├── flutter_test_config.dart                 # NEW: pins the default widget-test
│                                             # surface size to a compact reference
│                                             # width (research.md Decision 4) —
│                                             # first task, before any other change
├── unit/core/theme/
│   ├── app_layout_test.dart                 # NEW: windowSizeClassFor() boundary
│   │                                         # tests (599/600/839/840/1199/1200/
│   │                                         # 1599/1600)
│   └── app_theme_test.dart                  # existing file — + assertions that
│                                             # both themes' materialTapTargetSize/
│                                             # visualDensity are explicitly
│                                             # overridden (research.md Decision 6)
├── widget/core/router/
│   ├── app_shell_nav_bar_test.dart          # existing file — + expanded-width
│   │                                         # (rail) assertions, + a resize
│   │                                         # scenario proving GlobalKey
│   │                                         # reparenting preserves a descendant
│   │                                         # screen's local state (Clarification
│   │                                         # Q2)
│   └── app_shell_discard_prompt_test.dart   # existing file — + the same
│                                             # discard-prompt coverage triggered
│                                             # from the rail instead of the bar
├── widget/core/theme/
│   └── adaptive_input_test.dart             # NEW: tooltip-on-hover and
│                                             # keyboard-Tab/Enter coverage (User
│                                             # Story 3)
├── widget/core/widgets/
│   └── adaptive_body_test.dart              # NEW: below/at/above 840dp
└── widget/features/expenses/
    ├── overview_screen_test.dart            # existing file — + capped-width
    │                                         # assertion at ≥840dp
    └── report_screen_test.dart              # existing file — + same

# Also modified (User Story 3's tooltip audit — /speckit-analyze finding G1/G2):
#   lib/features/expense_control/presentation/widgets/expense_item_row.dart
#   lib/features/expense_control/presentation/widgets/expense_group_card.dart
#   lib/features/expenses/presentation/income_screen.dart
#   lib/features/expenses/presentation/expense_screen.dart
#   lib/features/account/presentation/sign_up_screen.dart
```

**Structure Decision**: No new feature directory and no new route. The
navigation-shell change stays in its existing `core/router/` location; the
two new shared primitives (`app_layout.dart`, `adaptive_body.dart`) go into
`core/theme/` and `core/widgets/` respectively, exactly where the
constitution's Recommended Architecture section already says shared,
multi-consumer infrastructure belongs — no precedent-setting exception
needed, unlike the Report feature's single-consumer usage-bar which had to
justify staying feature-local. `AppTheme`'s density/tap-target override is
a small, additive change to an already-existing file, not a new module.
This feature does not create `specs/20260925-024749-adaptive-layout-foundation`'s
git branch as a real git branch — see the session's branch note in
spec.md's header; all work stays on the session-designated
`claude/sweet-fermi-yd1qj8`.

## Phase 0: Research Summary

Research is recorded in [research.md](./research.md). Ten decisions were
made, several grounded directly against the Flutter SDK actually installed
in this session (not assumed from memory): `MediaQuery.sizeOf` (not
`LayoutBuilder`, not unscoped `MediaQuery.of(...).size`) as the single
width-measurement point, for scoped rebuilds; a `GlobalKey` on
`navigationShell`, owned by `_AppShellState` and created once (not
per-build, per the SDK's own `GlobalKey` "Pitfalls" documentation), so
Flutter reparents rather than disposes the currently-active screen when the
shell's structure changes between bottom-bar and rail layout — the concrete
mechanism behind Clarification Q2's "no remount" requirement;
`NavigationRailLabelType.all` (confirmed present in the installed SDK) for
Clarification Q1's "icon+label always visible" answer; an empirically
-confirmed finding that `flutter_test`'s own default surface size (800×600
logical pixels) already sits past this feature's 600dp breakpoint, making a
pinned `flutter_test_config.dart` a prerequisite, not a nice-to-have;
explicit `VisualDensity.standard`/`MaterialTapTargetSize.padded` in
`AppTheme` to override Flutter's own desktop-platform defaults (cited
against the installed SDK's `theme_data.dart`), resolving FR-007's
desktop tap-target requirement; tooltip text sourced from each control's
existing localized label where one exists, new ARB keys only where none
does; Flutter's default focus-traversal order (no custom policy) for
FR-009, since the affected screens are already simple, linearly-arranged
Material layouts; a single shared, plain-data destination list feeding
both `NavigationDestination` (bottom bar) and `NavigationRailDestination`
(rail) — confirmed to be two distinct SDK types — so the 5 destinations
can't drift out of sync between the two presentations; and the shared
breakpoint/max-width tokens' concrete location (`core/theme/app_layout.dart`)
and shape (a `WindowSizeClass` enum covering the constitution's full
5-value scale, even though this feature's own requirements only consume
two of its thresholds — the rest exist for other features to reuse without
redefining them).

## Phase 1: Design Summary

- [data-model.md](./data-model.md) defines the new, framework-independent
  value types this feature introduces (`WindowSizeClass` and its
  classification function, the shared layout-token constants, and the
  plain destination-data shape shared by both navigation widgets) — no
  persisted schema, no domain entity, no repository change.
- [contracts/adaptive-shell-ui.md](./contracts/adaptive-shell-ui.md)
  defines the internal contract: no new gateway/data contract (this
  feature reads nothing new); the presentation contract for
  `windowSizeClassFor`, `AdaptiveBody`, and the reworked `_AppShell`;
  explicit confirmation that no new route/path is introduced.
- [quickstart.md](./quickstart.md) lists manual verification steps
  (including a live-resize check and a state-preservation check for
  Clarification Q2) and the required automated regression coverage.
- `CLAUDE.md`'s plan reference is updated to point at this plan (Phase 1
  step 3), so the next session's context load reflects this feature
  instead of the now-shipped Report feature.

## Complexity Tracking

No constitution violations *caused by this feature's own design* require
justification here — nothing in this feature's approach trades away a
MUST rule for expedience. One pre-existing violation (the Multi-Platform
Support Web-data gap, Constitution Check above) is not this feature's to
justify away via Complexity Tracking, since this feature neither
introduces nor worsens it; it is tracked as required follow-up work in
spec.md §A instead, per `/speckit-analyze`'s C1 finding.
