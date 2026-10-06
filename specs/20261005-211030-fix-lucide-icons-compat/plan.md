# Implementation Plan: Restore Buildability — Fix Icon Library Incompatibility

**Branch**: `20261005-211030-fix-lucide-icons-compat` | **Date**: 2026-10-05 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from
`specs/20261005-211030-fix-lucide-icons-compat/spec.md`

## Summary

`lucide_icons 0.257.0` (the newest release, published June 2023) extends
`IconData`, which is a `final class` on the installed Flutter 3.47.5, so the
app does not compile and 22 test files cannot load. A version bump is
impossible, so the dependency is replaced (research.md Decision 1).

Approach: depend on **`lucide_flutter` ^1.47.0** (research.md Decision 2 —
52/52 icons covered under their current names, same `LucideIcons.*` constants,
20 KB total icon-font payload on web), imported through **one re-export file**
`lib/core/theme/app_icons.dart` (Decision 3) so the next swap touches a single
file. No call site is renamed — upstream aliases share codepoints with renamed
icons (Decision 4). The same change commits the toolchain drift the new
Flutter introduces (lock file, `analysis_options.yaml`) and, as a separate
mechanical commit, brings the format gate to green (Decision 5). The plan
workflow also points `CLAUDE.md` at this plan (Decision 8).

Both full-coverage packages were trialled in throwaway copies of the repo:
release web build OK, `flutter analyze` unchanged (2 existing infos), full
suite **508 passed / 0 failed** (baseline on `master`: 287 passed, 22 files
unloadable, no build).

**Added during verification (2026-10-06)**: a fifth change set, User Story 4 /
FR-012 — the router now listens to `isSignedInProvider` so a single sign-in
navigates (research.md Decision 9). It is a one-line behavior change in
`lib/core/router/app_router.dart` plus a `@visibleForTesting` provider and two
regression tests; it is independent of the icon swap and is kept as its own
change set.

## Technical Context

**Language/Version**: Dart 3.13.4 / Flutter 3.47.5 stable (installed
baseline); the declared SDK floor `^3.11.0` is unchanged — `lucide_flutter`
requires Dart `^3.8.1`.

**Primary Dependencies**: `lucide_flutter ^1.47.0` replaces `lucide_icons
^0.257.0` (MIT; font-based plain `const IconData`; family `LucideIcons`).
No other dependency is changed deliberately; toolchain-forced lock updates
observed on 2026-10-05 (exact set may shift if newer pub releases appear):
`intl` 0.20.3, `matcher` 0.12.20, `meta` 1.19.0, `test_api` 0.7.12,
`vector_math` 2.4.3.

**Storage**: N/A — no schema or data change. Persisted `icon_key` /
`display_icon_key` text values must keep resolving (contracts/
persisted-icon-keys.md).

**Testing**: `flutter test` (existing suite + 2 small additions: icon-key
contract test, import-seam architecture rule), `flutter analyze`, `dart
format --output=none --set-exit-if-changed lib test`, debug and release web
builds (the release build also feeds the payload check); manual light/dark
visual review (quickstart.md).

**Target Platform**: Android, iOS, Web (unchanged). Verified on **Web** in
this environment; Android/iOS builds are attempted and recorded, and may be
blocked by this machine's incomplete toolchains (research.md Decision 7).

**Project Type**: Flutter mobile + web app (single project, feature-first
layout).

**Performance Goals**: Web icon-font payload < 100 KB (SC-007; measured
20,400 B). No runtime change: tree-shaking still applies because icons remain
`static const IconData`.

**Constraints**: No layout, copy, navigation, data-model, or sync change
(FR-008); the team does not draw, trace or edit glyphs (spec Clarifications);
icons render with no network access (FR-010).

**Scale/Scope**: 1 dependency swap; 1 new 6-line file; 28 files change one
import line (18 `lib/`, 10 `test/`); 2 tests added/extended; toolchain-drift
reconciliation (`pubspec.lock`, `analysis_options.yaml`); 11 files reformatted
mechanically in a separate commit; 1 line in `CLAUDE.md`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

- **I. Code Quality — PASS.** `flutter analyze` stays at the existing 2 infos
  (both `onReorder`, unrelated; fixing them is out of scope per spec). No dead
  code or TODO is added. The format check, red on `master` today, is brought
  to green (FR-011). The new file is a single re-export with no logic.
- **II. Testing Standards — PASS.** Every existing test keeps its intent (only
  an import line changes in 10 files). Two tests are added: the persisted
  icon-key contract (FR-005) and the import-seam rule. No coverage-gated
  domain/data code changes.
- **III. UX Consistency & Adaptive Design — PASS, explicitly protected.**
  FR-004/FR-007 keep icon concept, 2px line style, size, tooltips/semantics and
  ≥48×48dp targets; the visual review covers light and dark and the compact
  bar / wide rail. No hard-coded color or layout is touched.
- **IV. Performance — PASS.** SC-007 caps the shipped icon-font payload;
  choosing `lucide_flutter` over `lucide_icons_flutter` avoids shipping ~2.9
  MB of unused weight fonts to every web and mobile bundle.
- **Recommended Architecture — PASS.** The icon package is third-party
  presentation infrastructure isolated behind one `core/theme/` re-export
  (the constitution's plugin-wrapper isolation rule); features still import
  only `core/`. Placement rationale (research.md Decision 3): icons are
  design-system tokens consumed app-wide through the theme, so `core/theme/`
  fits; the existing `core/widgets/expense_control_icons.dart` is a different
  concern (a persisted-key lookup for one feature's data) and stays put.
- **Offline-First Data & Sync — PASS (N/A).** No data path, outbox, or pull
  behavior changes; persisted icon keys are untouched.
- **Multi-Platform Support — PASS.** Web is verified here (debug and release
  builds + suite). Android and iOS builds are attempted during implementation
  (tasks.md T015) and their outcome recorded; if this machine's incomplete
  toolchains block them, that is reported as BLOCKED rather than claimed as
  verified (Decision 7).
- **Security — PASS.** Dependency hygiene is honored: maintenance status,
  license (MIT), release cadence and adoption were reviewed and recorded
  (research.md Decision 2), and `pub outdated` informed the choice. Adoption is
  low; the risk and its one-file mitigation are documented, not hidden.
- **Development Workflow — PASS, and applied.** A real bug found in shared
  `core/` code during this feature (first sign-in not navigating) is fixed at
  its root rather than worked around (research.md Decision 9), with regression
  tests. Spec FR-008 was amended with that one exception.
- **Development Workflow (process) — PASS.** Work is on a feature branch; analyze, format
  check and the full suite are part of the verification. Breaking change to a
  shared `core/` surface (a new import path for icons used app-wide) **MUST be
  called out in the PR description**. The format-only commit is kept separate
  so it can be reviewed or dropped independently.

**Post-design re-check**: PASS. Phase 1 added no new package, entity, or
external service; the only new code is the re-export and two tests.

## Project Structure

### Documentation (this feature)

```text
specs/20261005-211030-fix-lucide-icons-compat/
├── plan.md                              # This file
├── research.md                          # Phase 0: 8 decisions, measured evidence
├── data-model.md                        # Phase 1: import seam, persisted keys, 52-icon inventory
├── quickstart.md                        # Phase 1: 7 verification scenarios
├── contracts/
│   └── persisted-icon-keys.md           # Phase 1: stored icon-key contract
├── checklists/
│   └── requirements.md                  # Spec quality checklist
├── verification/                        # Implementation evidence: old-vs-new icon comparison (images + README)
└── tasks.md                             # Phase 2 (/speckit-tasks — not created here)
```

### Source Code (repository root)

```text
pubspec.yaml                             # MODIFIED: lucide_icons -> lucide_flutter ^1.47.0
pubspec.lock                             # MODIFIED: package swap + toolchain-forced updates
analysis_options.yaml                    # MODIFIED: analyzer exclude block the toolchain adds
CLAUDE.md                                # MODIFIED: plan pointer -> this plan.md

lib/core/theme/
└── app_icons.dart                       # NEW: export 'package:lucide_flutter/lucide_flutter.dart' show LucideIcons;

lib/core/router/app_router.dart          # MODIFIED: import line + US4 fix (listen to isSignedInProvider; refresh provider public for tests)
lib/core/widgets/expense_control_icons.dart                       # MODIFIED: import line only
lib/features/account/account_routes.dart                          # MODIFIED: import line only
lib/features/account/presentation/{account_screen,sign_in_screen,sign_up_screen}.dart
lib/features/expense_control/presentation/expense_control_screen.dart
lib/features/expense_control/presentation/widgets/{allocation_summary_banner,expense_group_card,expense_item_row}.dart
lib/features/expenses/expenses_routes.dart
lib/features/expenses/presentation/{expense_screen,income_screen,overview_screen,report_screen,spending_screen,transaction_history_screen}.dart
lib/features/expenses/presentation/widgets/balance_group_card.dart
                                         # all MODIFIED: import line only (18 files in lib/)

test/unit/architecture/architecture_boundary_test.dart            # MODIFIED: + icon-seam rule
test/unit/core/router/app_router_refresh_test.dart                # NEW: US4 regression (router refresh timing)
test/unit/core/widgets/expense_control_icons_test.dart            # NEW: pins 16 keys + circle fallback
test/widget/core/router/app_shell_nav_bar_test.dart               # MODIFIED: import line only
test/widget/core/theme/adaptive_input_test.dart                   # MODIFIED: import line only
test/widget/core/widgets/not_available_placeholder_screen_test.dart
test/widget/features/expense_control/{expense_control_screen_test,expense_group_card_test}.dart
test/widget/features/expenses/{expense_screen,income_screen,overview_screen,report_screen,spending_screen}_test.dart
                                         # all MODIFIED: import line only (10 files in test/)

# Separate mechanical commit (FR-011) — `dart format` output only, no behavior change:
lib/core/database/app_database.dart
lib/core/sync/{initial_pull_complete_provider,pull_service,remote_row_writer}.dart
test/unit/core/database/app_database_migration_test.dart
test/unit/core/sync/{conflict_resolution,initial_pull_complete_provider,pull_service_provider,pull_service,remote_row_writer,sync_worker}_test.dart
```

**Structure Decision**: No new feature directory; this is a cross-cutting
dependency fix. The only new library file lives in `core/theme/` beside the
other design tokens, and every importer reaches the package through it.

## Phase 0: Research Summary

See [research.md](./research.md) — 8 decisions: root cause and why no bump can
fix it (1); package choice with a three-way measured comparison (2); the
single import seam (3); icon identity preserved through shared-codepoint
aliases, with the 12 renamed icons tabulated (4); toolchain-drift
reconciliation incl. the pre-existing format failures (5); test strategy (6);
verification scope and platform statement (7); the `CLAUDE.md` pointer and a
correction to an earlier mistaken statement about what it contained (8).

## Phase 1: Design Summary

- [data-model.md](./data-model.md): no data change; documents the import seam,
  the persisted icon identifiers, and the 52-icon usage inventory that
  FR-004/SC-004 are checked against.
- [contracts/persisted-icon-keys.md](./contracts/persisted-icon-keys.md): the
  16-key + fallback contract for locally stored and synced icon keys — the one
  external-facing interface touched.
- [quickstart.md](./quickstart.md): seven scenarios mapping every success
  criterion to a command or a screen-by-screen visual check.

## Suggested Implementation Order (input for `/speckit-tasks`)

1. **Foundational**: swap the dependency, add `app_icons.dart`, run `pub get`
   (lock and analysis-options drift is kept, FR-006).
2. **US1 (MVP)**: add the import-seam test first (it fails), point the 28 files
   at the seam, then analyze, debug + release web build, attempted Android/iOS
   builds, full tests, clean-tree check — and the mechanical `dart format`
   change set (FR-011), kept as its own commit. The format gate is part of US1
   because the constitution forbids merging with it red, so US1 is only
   mergeable once it is green.
3. **US2**: add the icon-key contract test; payload check; light/dark visual
   review and persisted-icon check (Scenarios 4–6).
4. **US3**: verify the `CLAUDE.md` pointer (Scenario 7) — already rewritten by
   this plan step.
5. **Final pass**: re-run Scenarios 1–3 end to end and prepare the PR
   call-outs.

## Complexity Tracking

No constitution violations. Two choices worth a reviewer's attention are
recorded as decisions, not hidden complexity: the one-line re-export seam
(Decision 3; the alternative is 28 direct imports of a third-party package,
which is how a single abandoned dependency just broke the whole app) and the
separately committed format reconciliation (Decision 5; touches 11 files
outside the icon scope but is mechanical and droppable).
