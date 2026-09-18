# Implementation Plan: Expense Control

**Branch**: `20260904-144604-expense-control` | **Date**: 2026-09-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/20260904-144604-expense-control/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Add a "Kiểm soát" (Expense Control) screen — the app's new 2nd tab — where users define a written spending plan: expense items that are either a percentage of income or a fixed amount, optionally grouped one level deep, with a live-updating allocation summary and blocking validation on the 100%-budget rule (strictly <100% whenever a fixed item exists). This refactors/replaces the existing "Khoản" (Envelope) feature (its data is discarded, not migrated) and expands bottom navigation from 4 to 5 tabs. Technical approach: one new self-referencing Drift table (`ExpenseControlItems`) synced via the existing outbox/Supabase pattern, a pure-Dart domain service owning the leaf/group and percentage-budget business rules, and a Riverpod-driven presentation layer under a new `features/expense_control/` module — following the same layering already established by `features/envelopes/`.

## Technical Context

**Language/Version**: Dart (SDK `^3.11.0`), Flutter stable.

**Primary Dependencies**: `flutter_riverpod` (state/DI), `go_router` (routing, `StatefulShellRoute.indexedStack`), `drift` + `drift_flutter` + `sqlite3_flutter_libs` (local DB), `supabase_flutter` (sync target), `lucide_icons` (icon set — reused for the predefined icon picker, research.md §2), `intl` (locale-aware formatting), bundled Lexend font (already wired into `AppTheme`, no new font dependency). No new packages required for this feature.

**Storage**: Drift/SQLite locally (source of truth, offline-first), synced to Supabase Postgres via the existing outbox pattern (`SyncWorker`); new table `expense_control_items` (contracts/schema.sql).

**Testing**: `flutter_test` (unit + widget), integration tests under `test/integration/`, mirroring the existing `test/unit/`, `test/widget/`, `test/integration/` split.

**Target Platform**: Mobile (Android/iOS) via Flutter — same as the rest of the app.

**Project Type**: Mobile app (single Flutter project, feature-first modules under `lib/features/`).

**Performance Goals**: Consistent with Constitution Principle IV — 60fps scrolling/collapse-expand animation, virtualized lists even though item counts are small (personal expense plans, expected low tens of items).

**Constraints**: Offline-first (all reads/writes succeed immediately against local DB, per Constitution); ≥48×48dp touch targets (mockup's 44px is superseded per spec.md Assumptions); bilingual (`vi` default, `en`) for every new string (FR-021).

**Scale/Scope**: 4 user stories (P1–P3), 1 new DB table, 1 new feature module, 5-tab navigation change (2 renames + 1 new placeholder tab + 1 new real tab), ~23 functional requirements.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle / Section | Compliance plan |
|---|---|
| I. Code Quality | New module follows `presentation/domain/data` layering (see Project Structure). All percentage-budget/leaf-group business rules live in a pure-Dart domain service, never in `build()` — research.md §5. `flutter analyze` must pass with zero warnings; no lint suppressions planned. The old `/envelopes` CRUD screen and its now-orphaned providers are deleted (not left unrouted) once Kiểm soát replaces it, per the "no dead code" rule (research.md §12). |
| II. Testing Standards | Domain service (tree-building, totals, FR-007/008/012 validation incl. the pending-edit overlay, leaf⇄group transitions, 1-level nesting cap) gets unit tests targeting ≥80% coverage; repository tests cover `saveFormulas`/`reorderTopLevel` batch persistence. Widget tests for the empty state, group card, child row, icon picker, "Lưu công thức" blocking/commit behavior, and screen-level rebuild-on-edit behavior. One integration test covering create → group → inline-edit → save-formula → reorder → delete (quickstart.md). |
| III. UX Consistency | Reuses existing `ThemeData`/`AppSemanticColors` tokens (no hardcoded colors — the mockup's blue/warning/border tokens already map onto `primarySoft`/`warning`/`warningSoft`/`border1`/`border2`). Both themes verified. New reusable `core/widgets/empty_state_view.dart` (research.md §6) instead of a bespoke local pattern. All new strings ship with `vi` + `en` ARB entries in the same PR (FR-021). Touch targets ≥48dp (spec.md Assumptions already reconciles the mockup's 44px). Financial figures go through the existing `core/formatting/currency_formatter.dart`, never ad hoc interpolation (research.md §10). Every icon-only control carries a `Semantics` label for screen-reader reachability (research.md §11). Structural CRUD stays immediate everywhere (matching every other screen in the app); only the inherently whole-plan percentage check is deferred behind the mockup's single "Lưu công thức" button, rather than inventing a bespoke batch-save pattern (research.md §9). |
| IV. Performance | Lists use `ListView.builder`; Riverpod providers scoped narrowly (per-item/derived-totals providers) so unrelated edits don't rebuild the whole tree; `expense_control_items_user_id_idx` index added (mirrors `envelopes_user_id_idx`); Drift `watch()` queries stay off the UI thread as already guaranteed by the existing `AppDatabase` setup. |
| Recommended Architecture | New feature-first module `lib/features/expense_control/{presentation,domain,data}`; DI via Riverpod providers (`expenseControlRepositoryProvider`, mirroring `envelopeRepositoryProvider`); no cross-feature internal imports. |
| Offline-First Data & Sync | New table follows the outbox pattern (`entityTable: 'expense_control_items'`) exactly like `EnvelopeRepositoryImpl`; `SyncWorker`'s outbox drain is already generic and needs no code change, only the new Supabase table (contracts/schema.sql). No new reconciliation view is needed — this feature stores no computed balance, per spec.md ("this feature does not track real income"). |
| Security | New Supabase table ships with RLS enabled and an owner-only policy (contracts/schema.sql), matching every existing table. No secrets/tokens involved. |
| Governance / Complexity | No principle violations identified; Complexity Tracking table below is empty. |

**Result**: PASS — no unjustified complexity, proceeding to Phase 0/1 artifacts.

## Project Structure

### Documentation (this feature)

```text
specs/20260904-144604-expense-control/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   ├── expense_control_repository.md
│   └── schema.sql
├── reference/            # Mockup handoff, already copied (icons.json, theme-tokens.json, kiem-soat-spec.md)
├── checklists/requirements.md
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

Single Flutter project, feature-first modules (Constitution's Recommended Architecture) — same layout `features/envelopes/` already uses. This feature adds one new module, touches shared `core/` files, and renames/adds bottom-nav destinations.

```text
lib/
├── core/
│   ├── database/
│   │   ├── app_database.dart                          # MODIFIED: register ExpenseControlItems, schemaVersion 1→2; MigrationStrategy currently has only `beforeOpen` — add an `onUpgrade` handler (from == 1) that soft-deletes existing Envelopes rows (research.md §3)
│   │   └── tables/
│   │       └── expense_control_items_table.dart        # NEW
│   ├── l10n/
│   │   ├── app_vi.arb                                  # MODIFIED: tabExpenseControl, tabHistory (new); tabSpending/tabAccount values renamed (research.md §7); + all new screen strings
│   │   └── app_en.arb                                  # MODIFIED: same keys, English
│   ├── router/
│   │   └── app_router.dart                             # MODIFIED: 4 branches → 5 (insert Kiểm soát, insert Lịch sử/Báo cáo placeholder, REMOVE the old /envelopes branch + destination — research.md §12)
│   └── widgets/
│       └── empty_state_view.dart                        # NEW, reusable (research.md §6)
├── features/
│   ├── expense_control/                                 # NEW feature module
│   │   ├── domain/
│   │   │   ├── expense_control_item.dart                # Entity
│   │   │   ├── expense_control_repository.dart           # Interface incl. saveFormulas/ExpenseFormulaEdit (contracts/expense_control_repository.md)
│   │   │   └── expense_control_plan_service.dart         # Tree-building, totals, FR-007/008/012 validation (with optional pending-edit overlay), leaf⇄group rules, 1-level nesting guard
│   │   ├── data/
│   │   │   └── expense_control_repository_impl.dart      # Drift-backed, outbox writes (mirrors EnvelopeRepositoryImpl), incl. saveFormulas batch commit
│   │   └── presentation/
│   │       ├── expense_control_screen.dart                # Header, banner, group/leaf list, empty state, "Lưu công thức" button
│   │       ├── expense_control_providers.dart              # Riverpod: repository, watchAll stream, derived totals/tree, autoDispose pending-formula-edits provider (research.md §9)
│   │       ├── expense_control_form_controller.dart         # Create-item + name/icon/description-edit form state + validation wiring (formula editing is inline, not through this controller — research.md §9)
│   │       └── widgets/
│   │           ├── expense_group_card.dart
│   │           ├── expense_item_row.dart
│   │           ├── icon_picker.dart                        # Predefined lucide_icons set (research.md §2)
│   │           └── allocation_summary_banner.dart
│   ├── history/                                          # NEW placeholder feature (research.md §8)
│   │   └── presentation/
│   │       └── history_placeholder_screen.dart
│   └── envelopes/                                        # domain/data UNCHANGED (still backs "Thu chi"/"Hồ sơ", research.md §12); the dedicated CRUD screen (envelopes_screen.dart, envelope_form_screen.dart) and its now-orphaned providers are REMOVED — Kiểm soát replaces its purpose (FR-020); underlying data emptied by the schemaVersion 2 migration
└── main.dart

test/
├── unit/features/expense_control/
│   ├── expense_control_plan_service_test.dart            # FR-007/008/012, leaf⇄group transitions, totals, nesting cap
│   ├── expense_control_form_controller_test.dart          # FR-006/017, create/edit validation
│   └── expense_control_repository_impl_test.dart          # saveFormulas/reorderTopLevel batch persistence
├── widget/features/expense_control/
│   ├── expense_control_screen_test.dart                   # incl. empty-state (FR-023), "Lưu công thức" flow
│   ├── expense_group_card_test.dart
│   └── icon_picker_test.dart
├── widget/core/router/
│   └── app_shell_test.dart                                # 5-tab nav, old /envelopes branch removed
└── integration/
    └── expense_control_flow_test.dart                     # create → group → inline-edit formula → "Lưu công thức" → reorder → delete, per quickstart.md

supabase/migrations/
└── <timestamp>_expense_control_items.sql                  # Applies contracts/schema.sql
```

**Structure Decision**: Single Flutter project (mobile app), no new top-level directories — this feature is entirely additive within the existing `lib/core/` + `lib/features/` layout. `features/expense_control/` is a brand-new feature-first module following the same `presentation/domain/data` split as `features/envelopes/`; `features/envelopes/` itself is left as-is (its screens are out of scope, per Assumptions) aside from the shared `AppDatabase` migration that empties its data. `features/history/` is a second, intentionally minimal new module for the placeholder tab (research.md §8).

## Complexity Tracking

No Constitution Check violations — table intentionally left empty.
