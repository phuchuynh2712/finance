# Implementation Plan: Transaction History Screen Responsive Redesign

**Branch**: `20260928-081611-transaction-history-redesign` | **Date**: 2026-09-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/20260928-081611-transaction-history-redesign/spec.md`

## Summary

Cap Transaction History's month/filter controls and transaction list at the
shared `contentMaxWidth` token, centered, once the window reaches the
`expanded` breakpoint (840dp) — the same `AdaptiveBody` mechanism already
used by Home Overview and Monthly Report — and confirm (extending only
where a real gap is found) that every interactive control on the screen is
keyboard-traversable, shows a visible hover state, and is keyboard-
activatable. Unlike the Auth screens redesign this follows, this screen has
no form/submit flow, so there is no Enter-to-submit guard to build — User
Story 2 is expected to be mostly a verification pass against Flutter's
default button/focus behavior, per research.md.

**Scope note (read before assuming this touches only Transaction
History)**: this feature's own FR-004 (scroll position preserved across a
live resize) exposed a real, previously-latent bug in the shared
`AdaptiveBody` widget itself — crossing its activation threshold disposes
and remounts the entire child subtree, resetting scroll position (and any
other descendant State) to its initial value. This is fixed at the root,
inside `AdaptiveBody`, rather than patched only at Transaction History's
own call site — a deliberate choice made after presenting both options to
the user, who explicitly chose the root-cause fix over a narrower,
per-caller patch. **See research.md Decision 1a for the full investigation,
the empirical evidence, the rejected alternative (`PageStorageKey`) and why
it was rejected, and the consequence for the 4 Auth screens — read it
before touching `AdaptiveBody` again in a future feature.**

## Technical Context

**Language/Version**: Dart (project-pinned SDK, via `pubspec.yaml`), Flutter stable channel

**Primary Dependencies**: Flutter Material, `flutter_riverpod` (state), `intl` (date/number formatting), `lucide_icons` (icons) — all already in use by this screen; no new dependency introduced

**Storage**: N/A — this feature touches layout and input handling only; `transactionHistoryRecordsProvider` and its underlying repository are consumed unmodified

**Testing**: `flutter_test` widget tests (this repository's existing pattern — real `GoRouter`/`ProviderScope` harness, `tester.view.physicalSize` for breakpoint pumps, per research.md Decision 5 of the Auth screens redesign)

**Target Platform**: Android, iOS, Web (per constitution's Multi-Platform Support) — layout driven only by window size, never platform checks

**Project Type**: Mobile/Web Flutter app (existing single-project structure, no new top-level directory)

**Performance Goals**: No new performance target — this is a layout/input-handling change to an already-virtualized (`SliverList.builder`) screen; constitution's existing 60fps/scroll-jank budget applies unchanged

**Constraints**: Below the `expanded` breakpoint (840dp), FR-002 requires byte-for-byte behavioral parity with the screen's current, unmodified state — this bounds the change to additive width-capping and focus/hover wiring, never a restructure of the screen's existing widget tree below that breakpoint

**Scale/Scope**: Single screen (`lib/features/expenses/presentation/transaction_history_screen.dart`), 4 widget-test scenarios (2 per user story) matching the Auth screens redesign's per-screen test depth

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principle I (Code Quality)**: PASS. No new widget class introduced beyond
  what's needed to wrap existing content in `AdaptiveBody`; no business logic
  touched (`transaction_history.dart`'s pure view-building functions are
  unmodified). The `AdaptiveBody` fix (research.md Decision 1a) is a
  same-shape restructure of existing logic, not new complexity — it removes
  a conditional branch rather than adding one.
- **Principle II (Testing Standards)**: PASS. New widget tests will cover
  Transaction History itself at both a compact (<600dp) and an expanded
  (≥840dp) width, per Principle II's own breakpoint-coverage mandate for any
  screen with breakpoint-dependent layout (`/speckit-tasks`/`/speckit-
  implement` still owes this — not yet written as of this plan). No
  domain/business logic changes, so the 80% domain-coverage gate is not
  implicated. The `AdaptiveBody` fix's own regression coverage — 2 new
  scroll-preservation tests in `adaptive_body_test.dart`, plus the full
  existing suite (458/458) re-run across ALL 5 pre-existing callers
  (Overview, Report, Sign In, Sign Up, Forgot Password, Reset Password) —
  **was already written and verified during this plan's own Phase 0**, not
  deferred to `/speckit-tasks`, since the bug was found while verifying
  FR-004's feasibility.
- **Principle III (User Experience Consistency & Adaptive Design)**: PASS —
  this IS Principle III's Adaptive Layout mandate being applied to the one
  remaining screen that didn't yet have it. Reuses the existing shared
  `contentMaxWidth` token and `WindowSizeClass.expanded` breakpoint (no new
  token introduced) and the existing hover/focus/keyboard requirements for
  any screen reachable off a touch-only platform. The `AdaptiveBody` fix
  also directly serves this principle's state-preservation intent (FR-004)
  more correctly than the widget's previous implementation did.
- **Principle IV (Performance Requirements)**: PASS. `SliverList.builder`
  (lazy/virtualized rendering) is already in place and unmodified; the
  same-shape `AdaptiveBody` is O(1) constraint-only relayout on threshold
  crossing — strictly cheaper than the previous dispose-and-remount
  behavior, not a new cost.
- **Recommended Architecture**: PASS, with a noted scope expansion. This
  feature's change is NOT confined to `features/expenses/presentation/` —
  it also modifies the shared `core/widgets/adaptive_body.dart`. This is a
  deliberate, user-approved root-cause fix (research.md Decision 1a), not
  scope creep: the bug FR-004 exposed lives in the shared widget, and the
  constitution's own priority (correctness over minimizing an individual
  PR's footprint) supports fixing it there once rather than patching every
  current and future caller individually. No feature boundary is crossed in
  the sense the architecture principle actually cares about (no feature
  reaches into another feature's internals) — `core/widgets/` is exactly
  where shared presentation code is meant to live and be fixed.
- **Offline-First Data & Sync**: N/A — no data-layer change.
- **Multi-Platform Support**: PASS. Layout change is window-size-driven only
  (FR-005); no `Platform.is*`/`kIsWeb`/`defaultTargetPlatform` branch
  introduced, matching the Auth screens redesign's own verified precedent
  (`grep` check repeated in this feature's Polish phase).
- **Security**: N/A — no data, auth, or storage surface touched.
- **Development Workflow**: PASS. Feature branch already created;
  `flutter analyze` and the full test suite were both run clean during this
  plan's own Phase 0 (`AdaptiveBody` fix), and will be re-run at the end of
  `/speckit-implement` once Transaction History's own screen changes land.
  Per Development Workflow's own "Breaking changes to shared `core/`
  utilities REQUIRE explicit call-out in the PR description" rule AND this
  amendment's own new root-cause-fix bullet (constitution v1.7.0), the PR
  for this feature MUST explicitly call out the `AdaptiveBody` change, its
  cross-screen impact, and reference research.md Decision 1a — this is not
  optional given the constitution text itself, independent of this plan's
  own recommendation.

No violations — Complexity Tracking table is not needed. The `core/`
widget change is a scope expansion, disclosed and justified above, not a
constitution violation requiring a Complexity Tracking justification.

## Project Structure

### Documentation (this feature)

```text
specs/20260928-081611-transaction-history-redesign/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

`data-model.md` and `quickstart.md` are omitted — this feature introduces no
new entity, data flow, or setup step beyond what's already documented for
the app as a whole, matching the auth-screens-responsive feature's own
precedent for a layout-only change. `contracts/` is included because
`AdaptiveBody`'s shared API contract (already extended once, by
auth-screens-responsive) is worth documenting if this feature needs a
further extension — confirmed or ruled out in Phase 0.

### Source Code (repository root)

```text
lib/
├── core/
│   └── widgets/
│       └── adaptive_body.dart                          # MODIFIED: root-cause fix for the scroll/state-loss bug (research.md Decision 1a) — same-shape Center>ConstrainedBox on both sides of activatesAt, maxWidth becomes double.infinity below threshold instead of returning child unwrapped
└── features/
    └── expenses/
        └── presentation/
            └── transaction_history_screen.dart          # MODIFIED: wrap month/filter controls + transaction list in AdaptiveBody

test/
└── widget/
    ├── core/
    │   └── widgets/
    │       └── adaptive_body_test.dart                              # MODIFIED (existing file): add scroll/state-preservation regression coverage for the Decision 1a fix
    └── features/
        ├── expenses/
        │   ├── transaction_history_screen_test.dart                 # MODIFIED (existing file): add width-cap + keyboard/hover coverage
        │   └── transaction_history_performance_test.dart            # UNTOUCHED — reviewed in Phase 0/2, confirmed no overlap (pure-Dart performance test, no widget tree)
        └── account/
            ├── sign_in_screen_test.dart                             # REVIEWED, not expected to need edits — regression-checked against the AdaptiveBody fix (research.md Decision 1a's vertical-centering consequence)
            ├── sign_up_screen_test.dart                             # REVIEWED, not expected to need edits — same reason
            ├── forgot_password_screen_test.dart                     # REVIEWED, not expected to need edits — same reason
            └── reset_password_screen_test.dart                      # REVIEWED, not expected to need edits — same reason
```

**Structure Decision**: Single Flutter project, existing feature-first
layout (constitution's Recommended Architecture). This feature's primary
work is one presentation-layer file
(`lib/features/expenses/presentation/transaction_history_screen.dart`) plus
its test counterpart — no new `core/` module, no new feature directory, and
(unlike the Auth screens redesign) no `core/theme/app_layout.dart` change,
since this screen reuses the existing default `contentMaxWidth`/`expanded`
activation rather than introducing a new token. **In addition**, per the
Constitution Check and research.md Decision 1a above, this feature also
modifies the shared `core/widgets/adaptive_body.dart` to fix a root-cause
scroll/state-loss bug that FR-004 exposed — this is a deliberate,
user-approved scope expansion (constitution's Development Workflow section,
v1.7.0), not an oversight, and its own dedicated regression coverage
(`adaptive_body_test.dart` plus a visual re-check of all 4 Auth screens) is
part of this feature's own task list, not deferred to a later feature.

## Complexity Tracking

Not applicable — the Constitution Check above has no violations to justify.
