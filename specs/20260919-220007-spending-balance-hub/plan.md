# Implementation Plan: Spending Balance Hub & Envelope Retirement ("Thu chi")

**Branch**: `20260919-220007-spending-balance-hub` | **Date**: 2026-09-20 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/20260919-220007-spending-balance-hub/spec.md`

## Summary

Two tightly coupled halves, both required for either to make sense:

1. **Spending Balance Hub**: Redesign the "Thu chi" tab into a read-only balance hub mirroring Kiểm soát chi tiêu's groups/children tree, showing each leaf item's actual current balance (a new `balance` field on `ExpenseControlItem`, defaulting to 0) and each group's balance as the live sum of its children. Two action buttons ("Thu nhập"/"Chi tiêu") and a "Xem lịch sử giao dịch" row scaffold placeholders for future features.
2. **Envelope Retirement**: Fully delete the legacy `Envelope` data model — the `Envelopes`, `AllocationEvents`, `AllocationEventLines`, `EnvelopeCoverages` tables (local + Supabase, including the `envelope_balances` view), `ExpenseEntry`/`ExpenseFormScreen`/`ExpenseFormController` (the old expense-recording flow, FK'd to `Envelope`), `OverviewScreen`'s old envelope-list content, `PlanScreen`/`PlanController`/`computeAllocationPreview` (income-allocation, unreachable once `OverviewScreen`'s FAB is removed), and the sync worker's `envelope_balances` reconciliation logic. `ExpenseControlItem` becomes the app's sole balance data model.

Bundled in the same feature: fix the bottom navigation bar so the selected tab is indicated by icon/label color alone, removing the pill/chip background.

## Technical Context

**Language/Version**: Dart ^3.11.0 (per `pubspec.yaml`)

**Primary Dependencies**: Flutter 3.x, `flutter_riverpod` ^2.6.1, `drift` ^2.22.1, `go_router`, `lucide_icons`, `intl`

**Storage**: Drift (SQLite) — `ExpenseControlItems` gains a `balance` column; `Envelopes`, `AllocationEvents`, `AllocationEventLines`, `EnvelopeCoverages` are dropped entirely (local + Supabase, including the `envelope_balances` view)

**Testing**: `flutter test` (unit + widget + integration), matching the existing project convention

**Target Platform**: Android/iOS (Flutter mobile app)

**Project Type**: Mobile app — single Flutter project, feature-first modules per Constitution

**Performance Goals**: Standard Flutter 60fps scrolling; no new performance-sensitive computation (tree building and sum aggregation already proven at Kiểm soát chi tiêu's scale)

**Constraints**: Must not add any control that writes to `allocationMethod`/`allocationValue` (formula fields stay read-only on "Thu chi"). Must not attempt to design or carry forward the "covering envelope"/"rounding receiver" mechanics — they are dropped, not ported (spec.md Clarifications); a future feature redesigns equivalents from scratch against `ExpenseControlItem` if needed. Must not attempt a real "Tổng quan" redesign — it gets the same interim placeholder as everything else in this feature (spec.md Assumptions).

**Scale/Scope**: One redesigned screen (`SpendingScreen`), one new DB column, four dropped local tables + one dropped Supabase view (in dependency-safe order), one new placeholder screen (reused 4× — Thu nhập/Chi tiêu/Lịch sử/Tổng quan), one deleted screen (`PlanScreen`) and its controller/algorithm, one deleted expense-recording flow (`ExpenseFormScreen`/`ExpenseFormController`/`ExpenseEntry`), one sync-worker code path removed, one theme fix affecting the shared `NavigationBar`, ARB cleanup for orphaned strings

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principle I (Code Quality)**: PASS. Business logic (balance aggregation) lives in a pure-Dart extension of the existing `ExpenseControlPlanService`. Deletion work (Envelope and friends) is subtractive — no new complexity, and removes several files' worth of business logic that will no longer need maintaining. No new lint exceptions anticipated.
- **Principle II (Testing Standards)**: PASS, with an explicit obligation. New behavior (balance display, group-sum aggregation, migration default-zero/drop, placeholder navigation, nav-bar color) MUST ship with unit tests (aggregation logic, migration) and widget tests (`SpendingScreen`, `NavigationBar` color assertions, placeholder screens) in the same PR. Deleting `Envelope`/`ExpenseEntry`'s ~8 test files alongside the code they cover is a clean removal, not a coverage regression (spec.md Assumptions) — the Constitution's 80% domain-layer bar applies to what remains after deletion, not to code being removed wholesale.
- **Principle III (User Experience Consistency)**: PASS. Reuses the existing shared `CurrencyFormatter`, `AppTheme`/`AppSemanticColors` tokens, and the existing expand/collapse tree pattern from Kiểm soát chi tiêu. Both light and dark mode addressed. All new/changed user-facing strings ship with both `vi` (primary) and `en` translations in the same PR; orphaned strings for deleted screens are removed in the same PR (FR-021), not left to rot.
- **Principle IV (Performance)**: PASS. Balance aggregation is an O(children) sum per group. Dropping four tables and their indexes is a one-time migration cost, not a runtime performance concern.
- **Recommended Architecture**: PASS. New domain logic (balance-sum aggregation) stays in `lib/features/expense_control/domain/`. The entire `lib/features/envelopes/` module and its `lib/features/expenses/` counterparts (`expense_entry.dart`, `expense_form_*`, `envelope_coverage.dart`, `compute_overspend.dart`) are deleted outright — this reduces the codebase's feature-module count rather than adding to it.
- **Offline-First Data & Sync**: PASS. `balance` is a plain column on `ExpenseControlItems`, already covered by that table's existing sync-outbox pattern. The sync worker's `Envelope`-reconciliation code path is removed (FR-019) since its target tables/view no longer exist — this is a subtraction, not a new sync path needing new offline-first design.
- **Security**: PASS. No new external interface, no new secrets. RLS already applies to `ExpenseControlItems`; the new `balance` column inherits its existing row-level policy. Dropping tables removes their RLS policies automatically (Postgres cascades this); no new policy needed for anything.
- **Development Workflow**: PASS. Standard feature branch + PR flow. Both the nav-bar color fix and the Envelope-table drop are called out in the PR description as breaking changes to shared `core/` and the local/remote schema, per the Constitution's explicit-call-out rule for such changes.

No violations requiring Complexity Tracking. The scope is large (an entire legacy module deleted) but is architecturally simple — subtraction plus one additive column plus one theme fix, not new abstractions.

## Project Structure

### Documentation (this feature)

```text
specs/20260919-220007-spending-balance-hub/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md         # Phase 1 output (/speckit-plan command)
├── contracts/            # Phase 1 output (/speckit-plan command)
├── reference/             # Design handoff package, copied verbatim for long-term reference
│   ├── README.md
│   ├── thu-chi-spec.md
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
│   │   ├── app_database.dart                           # MODIFY: schemaVersion 2→3; single migration step adds `balance` AND drops the four Envelope-related tables
│   │   ├── app_database.g.dart                          # REGENERATE: `build_runner` output, do not hand-edit
│   │   └── tables/
│   │       ├── expense_control_items_table.dart          # MODIFY: add `balance` column
│   │       ├── envelopes_table.dart                       # DELETE
│   │       ├── allocation_events_table.dart               # DELETE
│   │       ├── allocation_event_lines_table.dart          # DELETE
│   │       ├── envelope_coverages_table.dart              # DELETE
│   │       └── expense_entries_table.dart                 # DELETE
│   ├── router/app_router.dart                           # MODIFY: /spending route content; /overview → placeholder; remove any Plan route
│   ├── sync/sync_worker.dart                             # MODIFY: remove `_reconcileBalances()`'s envelope_balances read
│   ├── theme/app_theme.dart                             # MODIFY: NavigationBarThemeData — remove pill, color icon/label
│   ├── theme/app_colors.dart                             # MODIFY: add dark-mode active-icon accent color
│   └── l10n/app_vi.arb, app_en.arb                      # MODIFY: new strings (label, empty state, placeholders); DELETE orphaned Envelope-era strings
├── features/
│   ├── expense_control/
│   │   ├── domain/
│   │   │   ├── expense_control_item.dart                 # MODIFY: add `balance` field + copyWith
│   │   │   ├── expense_control_plan_service.dart         # MODIFY: add group-balance-sum computation
│   │   │   └── expense_control_repository.dart           # unchanged in shape
│   │   └── data/expense_control_repository_impl.dart     # MODIFY: map `balance` column ↔ entity
│   ├── expenses/
│   │   ├── domain/
│   │   │   ├── expense_entry.dart                         # DELETE
│   │   │   ├── expense_repository.dart                    # DELETE
│   │   │   ├── envelope_coverage.dart                     # DELETE
│   │   │   └── compute_overspend.dart                     # DELETE
│   │   ├── data/expense_repository_impl.dart              # DELETE
│   │   └── presentation/
│   │       ├── spending_screen.dart                       # REWRITE: new balance-hub UI per design
│   │       ├── expenses_providers.dart                    # DELETE
│   │       ├── expense_form_screen.dart                   # DELETE
│   │       ├── expense_form_controller.dart               # DELETE
│   │       └── widgets/                                   # NEW: balance group/item row widgets, purpose-built (not reusing ExpenseGroupCard — see research.md)
│   ├── envelopes/                                          # DELETE (entire directory: domain/, data/, presentation/)
│   └── history/presentation/history_placeholder_screen.dart  # MOVE + GENERALIZE → lib/core/widgets/not_available_placeholder_screen.dart
supabase/
└── migrations/
    └── <timestamp>_retire_envelope.sql                     # NEW: adds `balance` to expense_control_items; drops envelope_balances view, envelope_coverages, allocation_event_lines, allocation_events, expense_entries, envelopes (dependency-safe order)
test/
├── unit/features/expense_control/                          # NEW/MODIFY: balance aggregation, migration
├── unit/features/expenses/domain/compute_overspend_test.dart          # DELETE
├── unit/features/envelopes/domain/compute_allocation_preview_test.dart # DELETE
├── widget/features/expenses/spending_screen_test.dart       # REWRITE
├── widget/features/expenses/expense_form_screen_test.dart   # DELETE
├── widget/features/envelopes/overview_screen_test.dart      # REWRITE (now tests the placeholder)
├── widget/features/envelopes/plan_screen_test.dart          # DELETE
├── widget/core/widgets/not_available_placeholder_screen_test.dart  # NEW
├── widget/core/router/app_shell_nav_bar_test.dart            # MODIFY: assert no pill, icon/label color
└── integration/allocate_spend_cover_flow_test.dart           # DELETE
```

**Structure Decision**: `balance` is added to the existing `ExpenseControlItem` entity, not a new entity — the same reasoning as before applies (spec.md Assumptions: same tree, not a parallel hierarchy). The `lib/features/envelopes/` module is deleted in its entirety (domain, data, presentation) since nothing in it is being carried forward per the Clarifications' explicit decisions. `lib/features/expenses/` is kept as a directory (it still owns the "Thu chi" route) but has its old Envelope-coupled contents (`expense_entry.dart`, `expense_form_*`, `expense_repository_impl.dart`, `expenses_providers.dart`, `compute_overspend.dart`, `envelope_coverage.dart`) deleted, leaving only the rewritten `spending_screen.dart` and its new supporting widgets. The placeholder screen is generalized from `HistoryPlaceholderScreen` and moved to `lib/core/widgets/` (research.md Decision 4) since it's now used by four different entry points (Thu nhập, Chi tiêu, Lịch sử giao dịch, Tổng quan) across at least two features.
