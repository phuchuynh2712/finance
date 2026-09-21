# Implementation Plan: Income Entry & Automatic Allocation ("Thu nhập")

**Branch**: `20260920-212021-income-allocation` | **Date**: 2026-09-20 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/20260920-212021-income-allocation/spec.md`

## Summary

Replace "Thu chi"'s "Thu nhập" placeholder with a real income-entry screen: the user enters one or more named income line items, sums them into a total, and saves. On save, the total is distributed sequentially (in `sortOrder`, the same order Kiểm soát chi tiêu displays items) across every leaf item's saved formula (percentage of the total, or a fixed amount), added to each leaf's existing `balance`. If a leaf can't be fully covered by the income remaining at its turn, it receives whatever is left and the sequence stops — no item ever goes negative from this step. Any leftover after every formula has been applied lands on a single leaf item the user has separately marked as the "savings receiver" — a new boolean field on `ExpenseControlItem`, added to the existing create/edit dialog in Kiểm soát chi tiêu, enforced as at-most-one at the application layer only (no new data-layer constraint). This is the first feature to ever write a non-zero `ExpenseControlItem.balance`.

## Technical Context

**Language/Version**: Dart ^3.11.0 (per `pubspec.yaml`)

**Primary Dependencies**: Flutter 3.x, `flutter_riverpod` ^2.6.1, `drift` ^2.22.1, `go_router`, `lucide_icons`, `intl`

**Storage**: Drift (SQLite) — `ExpenseControlItems` gains an `is_savings_receiver` column (schema v3→v4); no new tables. Supabase gains the matching column via a new migration.

**Testing**: `flutter test` (unit + widget + integration), matching the existing project convention

**Target Platform**: Android/iOS (Flutter mobile app)

**Project Type**: Mobile app — single Flutter project, feature-first modules per Constitution

**Performance Goals**: Standard Flutter 60fps scrolling; allocation is a single O(leaves) pass over an already-in-memory list — no new performance-sensitive computation

**Constraints**: Allocation MUST be a pure, deterministic Dart function with no Flutter/Drift import (mirrors `ExpenseControlPlanService`'s existing architecture) so it is unit-testable without a UI or database. The savings-receiver uniqueness rule is enforced at the application layer only (spec.md Clarifications) — no new Drift/Supabase constraint, index, or sync-conflict-resolution logic for this field. No server-side balance reconciliation is (re)built in this feature (spec.md Assumptions, Complexity Tracking below).

**Scale/Scope**: One new screen (`IncomeScreen`), one new pure allocation function + its result type, one new repository method (bulk balance write), one new `ExpenseControlItem` field (+ Drift column + Supabase column + one new create/edit-dialog toggle), one re-pointed navigation entry (`SpendingScreen`'s "Thu nhập" button), ARB additions for the new screen's strings and the new toggle/warning text

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principle I (Code Quality)**: PASS. The allocation algorithm is a new pure-Dart function living in `lib/features/expense_control/domain/` (mirroring `ExpenseControlPlanService`'s existing pattern), not inside a controller or widget `build()`. No new lint exceptions anticipated.
- **Principle II (Testing Standards)**: PASS, with an explicit obligation. This is the first feature to write a real, non-zero `balance` — its allocation math (sequential distribution, insufficient-income truncation, leftover-to-receiver) is exactly the kind of financial calculation the Constitution calls out by name ("budget rules, currency/rounding") and MUST ship with unit tests covering every branch (fully covered, partially covered then truncated, exact-zero leftover, leftover-with-receiver, leftover-without-receiver) in the same PR. Widget tests cover the new `IncomeScreen` and the new savings-receiver toggle in the existing edit dialog. The data-layer balance write (data-model.md's `applyIncomeAllocation` contract) MUST use a single atomic `balance = balance + delta` SQL statement per item, not a read-then-write pair, precisely to satisfy this principle's "an unnoticed rounding or sign error erodes user trust immediately" rationale for a concurrent-write scenario, not just a single-user one.
- **Principle III (User Experience Consistency)**: PASS. Reuses the existing shared `CurrencyFormatter`, `AppTheme`/`AppSemanticColors` tokens, and `EmptyStateView`. Both light and dark mode addressed (reference package provides both). All new strings ship with `vi` (primary) and `en` translations in the same PR (FR-019).
- **Principle IV (Performance)**: PASS. Allocation is a single pass over the user's own (small, human-curated) list of budget items — no pagination, no background isolate work needed at this scale.
- **Recommended Architecture**: PASS. New domain logic stays in `lib/features/expense_control/domain/` (extends the existing module that already owns `ExpenseControlItem`/`ExpenseControlPlanService`), since the savings-receiver flag and the allocation algorithm both operate on that entity, not a new one. The income-entry screen itself is new presentation code under `lib/features/expenses/presentation/` (the existing home of `SpendingScreen`, which owns the "Thu nhập" entry point being replaced).
- **Offline-First Data & Sync**: PASS, with one explicitly recorded deviation — see Complexity Tracking below. The new balance write follows the existing outbox pattern (`_appendOutbox` in `ExpenseControlRepositoryImpl`) exactly as every other write in this repository already does. What does NOT happen in this feature: rebuilding server-authoritative reconciliation for `ExpenseControlItem.balance` (the Constitution's Offline-First section requires balances to reconcile against a server-recomputed source of truth; the only such mechanism that ever existed — built for the now-deleted `Envelope` model — was removed by the prior feature and nothing has replaced it since). This is a real, acknowledged gap this feature does not close.
- **Security**: PASS. No new external interface, no new secrets. The new `is_savings_receiver` column inherits `expense_control_items`' existing RLS policy automatically (RLS is per-table, not per-column, per this project's established pattern from the prior feature's migration).
- **Development Workflow**: PASS. Standard feature branch + PR flow. The Drift schema bump and the new `ExpenseControlRepository` method are called out in the PR description as breaking changes to shared `core/database/` and the `expense_control` domain's public contract, per the Constitution's explicit-call-out rule.

No violations requiring Complexity Tracking beyond the one explicitly documented deviation below (reconciliation gap) — the deviation is a *deferral*, not a rule broken in this feature's own code; nothing this feature does non-compliantly, it simply does not undertake a separate, larger effort the Constitution would otherwise imply is overdue.

## Project Structure

### Documentation (this feature)

```text
specs/20260920-212021-income-allocation/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md         # Phase 1 output (/speckit-plan command)
├── contracts/            # Phase 1 output (/speckit-plan command)
├── reference/             # Design handoff package, copied verbatim for long-term reference
│   ├── README.md
│   ├── thu-nhap-spec.md
│   ├── icons.json
│   ├── theme-tokens.json
│   ├── screen-light.png
│   └── screen-dark.png
└── tasks.md              # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

Single Flutter project, feature-first modules (existing structure, per Constitution). This feature touches:

```text
lib/
├── core/
│   ├── database/
│   │   ├── app_database.dart                           # MODIFY: schemaVersion 3→4; new migration step adds `is_savings_receiver`
│   │   ├── app_database.g.dart                          # REGENERATE: `build_runner` output, do not hand-edit
│   │   └── tables/
│   │       └── expense_control_items_table.dart          # MODIFY: add `isSavingsReceiver` column
│   └── l10n/app_vi.arb, app_en.arb                      # MODIFY: new strings (income screen, savings-receiver toggle/warning)
├── features/
│   ├── expense_control/
│   │   ├── domain/
│   │   │   ├── expense_control_item.dart                 # MODIFY: add `isSavingsReceiver` field + copyWith
│   │   │   ├── expense_control_repository.dart            # MODIFY: new method for bulk balance write
│   │   │   ├── income_allocation_service.dart             # NEW: pure allocation algorithm (domain, no Flutter/Drift)
│   │   │   └── expense_control_plan_service.dart          # MODIFY (maybe): validate at-most-one-receiver, if colocated here
│   │   ├── data/expense_control_repository_impl.dart      # MODIFY: map `isSavingsReceiver` column ↔ entity; implement bulk balance write
│   │   └── presentation/
│   │       ├── expense_control_form_controller.dart       # MODIFY: stage/validate the savings-receiver toggle (uniqueness check, auto-clear-on-child warning)
│   │       └── widgets/                                    # MODIFY: add the toggle to the existing item create/edit dialog
│   └── expenses/
│       └── presentation/
│           ├── spending_screen.dart                        # MODIFY: "Thu nhập" button navigates to IncomeScreen, not the placeholder
│           ├── income_screen.dart                           # NEW: the income-entry screen
│           ├── income_providers.dart                        # NEW: Riverpod wiring for the income screen/controller
│           └── widgets/                                     # NEW: income-source-row widget, purpose-built per reference/thu-nhap-spec.md
supabase/
└── migrations/
    └── <timestamp>_income_allocation.sql                     # NEW: adds `is_savings_receiver` to expense_control_items
test/
├── unit/features/expense_control/
│   ├── income_allocation_service_test.dart                  # NEW: every allocation branch (full coverage, truncation, receiver, no receiver, group-child auto-clear)
│   ├── expense_control_repository_impl_test.dart            # MODIFY: bulk balance write, isSavingsReceiver round-trip
│   └── expense_control_form_controller_test.dart             # MODIFY: uniqueness validation, auto-clear warning
├── widget/features/expenses/
│   ├── income_screen_test.dart                                # NEW
│   └── spending_screen_test.dart                              # MODIFY: "Thu nhập" now navigates to IncomeScreen
└── widget/features/expense_control/
    └── expense_control_screen_test.dart                       # MODIFY: dialog now includes the savings-receiver toggle
```

**Structure Decision**: The savings-receiver flag and the allocation algorithm both live in `lib/features/expense_control/domain/` — they operate entirely on `ExpenseControlItem`, the entity that module already owns, not on anything belonging to `expenses/`. The income-entry *screen* lives in `lib/features/expenses/presentation/` alongside `SpendingScreen`, since that's the module that already owns the "Thu nhập" entry point and routing context this feature replaces. No new feature directory is created; this is additive to two existing modules, following the same split the previous "Thu chi" feature used (balance-hub UI in `expenses/`, balance-bearing domain logic in `expense_control/`).

## Complexity Tracking

> Documenting one explicit, justified deviation — not a rule violated in this feature's own code, but a Constitution expectation this feature knowingly does not fulfill.

| Deviation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|---------------------------------------|
| No server-authoritative reconciliation for `ExpenseControlItem.balance`, despite the Constitution's Offline-First section requiring balances to reconcile against a server-recomputed source of truth | Building real reconciliation requires a new Postgres view/function deriving balance from a transaction log that does not yet exist (this feature doesn't create one — see spec.md's "Allocation Result… no separate allocation-event record is created"), plus new sync-worker logic to consume it — a distinct, larger effort than this feature's stated scope (income entry + allocation) | Deferring reconciliation entirely (this feature's choice) was preferred over either (a) blocking this feature until reconciliation is rebuilt — which would indefinitely stall a Priority-1 user-facing capability for an infrastructure concern with no more urgency now than it had immediately after the prior feature deleted the only reconciliation mechanism that existed — or (b) building a minimal ad hoc reconciliation just for this feature, which risks producing a shape a future, more complete transaction-log feature will need to redo entirely. Explicitly flagged (spec.md Assumptions, this table) rather than silently ignored, per the user's own prior-feature precedent for handling exactly this kind of gap. |
