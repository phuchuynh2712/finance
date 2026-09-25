# Implementation Plan: Monthly Report Screen

**Branch**: `20260924-181441-report-monthly-summary` | **Date**: 2026-09-24 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/20260924-181441-report-monthly-summary/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Replace the "Báo cáo" (fourth) tab's current "not available" placeholder
with a real, read-only monthly report: total income and total expense for
a navigable calendar month, plus a flat, per-item breakdown showing each
item's spend this month and how much of that item's own monthly income
allocation has been used — computed entirely from the app's existing
`financial_transactions` log with no new persisted schema. The bottom
navigation's fourth tab icon also changes from a history/clock icon to a
pie-chart icon; its label and position are unchanged. Two small, additive
gaps are filled: a leaf-to-parent-group-name lookup (new method on the
existing `ExpenseControlPlanService`) and one new small presentational
usage-bar widget — no repository interface change is required.

## Technical Context

**Language/Version**: Dart 3.11 / Flutter (existing project)

**Primary Dependencies**: Flutter Material, flutter_riverpod, Drift/SQLite,
GoRouter, intl, lucide_icons (`pieChart` constant confirmed present at the
pinned `0.257.0` version), existing localization/theme/formatting helpers
(`CurrencyFormatter`, `formatPercent`). No new runtime package is required.

**Storage**: Existing local Drift/SQLite database only
(`financial_transactions`, `expense_control_items`). No schema change, no
new table/column, no Supabase migration — this feature is entirely
read-only over data already persisted by the income-allocation and
expense-recording features.

**Testing**: `flutter analyze`, `dart format --output=none
--set-exit-if-changed`, focused unit/widget/integration tests, then
`flutter test`.

**Target Platform**: Existing Android and iOS Flutter application.

**Project Type**: Feature-first mobile application.

**Performance Goals**: Both totals and the item breakdown visible within 2
seconds of the tab becoming visible (SC-001), using the already-indexed,
already-bounded `watchTransactionHistory(start, end)` query (one calendar
month's range) — not a new or wider query. The breakdown's aggregation is
an O(n) in-memory fold over one month's already-loaded transaction list,
where n is a user's monthly transaction count — bounded and small in
practice for a personal-finance user, matching the same reasoning already
accepted for the Home Overview feature's analogous fold.

**Constraints**: Offline-first local reads only; read-only screen (no
mutation entry points); Vietnamese and English localization; established
light/dark design tokens (including the danger-semantic overspend color);
the month-navigation buttons' 44×44px visual must reconcile with the
constitution's ≥48×48dp touch-target minimum (resolved identically to the
Home Overview feature's header button, via a stock `IconButton`'s default
48dp minimum — research.md); no raw financial values in logs; no direct
presentation dependency on another feature's internals beyond the already-
approved `expense_control` `domain/`-layer imports.

**Scale/Scope**: One new full-screen tab content (replaces an existing
placeholder route, same path); one new domain method
(`ExpenseControlPlanService.groupNameFor`); one new application-layer pure
module (`report_summary.dart`); two new presentation-layer providers
(`selectedReportMonthProvider`, plus the `reportTotalsProvider`/
`reportBreakdownProvider` family pair); one new small presentational
widget (usage bar); one changed icon constant in the existing router; no
new feature directory, no new route registration beyond the existing
`/history` path's builder, no repository interface change.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

- **Principle I — Code Quality: PASS.** `report_summary.dart`'s
  `computeReportTotals`/`computeReportBreakdown` and the new
  `ExpenseControlPlanService.groupNameFor` are plain, framework-independent
  Dart functions/methods outside any widget's `build()`; `ReportScreen`
  stays state/rendering only, composing two independent
  `AsyncValue.when(...)` sections.
- **Principle II — Testing Standards: PASS with required coverage.** Unit
  tests for `groupNameFor` (nested leaf, standalone top-level leaf, unknown
  id), for both pure computation functions (income/expense fold, per-item
  aggregation, all three `ReportItemUsageState` branches including
  `usagePercent > 100`, list-membership exclusion, sort order); widget
  tests covering totals/breakdown independently for loading/error/empty/
  data, the three per-row states, overspend bar capping, and month-
  selection persistence across a tab switch (research.md Decision 3);
  integration coverage confirming a newly recorded transaction is
  reflected in the Report tab without a manual refresh. Existing
  domain/data coverage must not fall below 80%.
- **Principle III — UX Consistency: PASS.** Reuses `AppSemanticColors`
  (including the existing danger/success tokens for the overspend bar
  color), `CurrencyFormatter`, `formatPercent` (an already-established,
  already-used shared percent formatter — research.md Decision 8, correcting
  an initial research-pass miss), ARB localization, `EmptyStateView`, Lexend
  theme, and the source design's light/dark tokens (`reference/theme-
  tokens.json`). The month-navigation buttons' design-specified 44×44px
  visual is below the constitution's 48dp touch-target minimum; resolved
  identically to the Home Overview feature's header button — a stock
  `IconButton`'s default 48dp minimum interactive dimension already covers
  this with no custom hit-area work.
- **Principle IV — Performance: PASS.** Totals and breakdown both read from
  the same already-indexed, month-bounded `watchTransactionHistory` query
  (no new or wider query); the two derived views are independent providers
  so a slow/failed one never blocks the other's render (scoped rebuilds,
  matching the Home Overview precedent exactly — research.md Decision 4).
- **Clean Architecture: PASS.** New application/presentation code lives in
  `lib/features/expenses/`, importing only `expense_control`'s `domain/`
  (never its `presentation/`) — the one cross-feature addition
  (`groupNameFor`) is a new method on a `domain/`-layer class already
  established as a legitimate cross-feature dependency by the Home Overview
  feature's precedent (`ExpenseControlPlanService.computeItemBalance`).
  `expenseControlTreeProvider` is imported from its actual `core/di/`
  location, not from `expense_control/presentation/`, so no boundary rule
  is newly stressed.
- **Offline-First and Security: PASS.** Every read is local-first (existing
  Drift-backed streams); no new Supabase call, no new persisted table, so
  no new RLS surface; no raw financial values or tokens are newly logged.

**Post-design re-check**: PASS. Research and contracts introduce no new
package, external service, network API, or unapproved architecture
exception; the one design/constitution numeric tension found (touch
target) has the same already-decided resolution as precedent, not an open
violation.

## Project Structure

### Documentation (this feature)

```text
specs/20260924-181441-report-monthly-summary/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
├── reference/            # Design handoff package (screens, tokens, icons) — kept as long-term reference
├── checklists/           # Spec quality checklist (/speckit-specify command)
└── tasks.md              # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
lib/
├── core/
│   ├── router/app_router.dart                       # 4th tab icon → LucideIcons.pieChart;
│   │                                                  # /history GoRoute builder → reportRoute
│   │                                                  # (imports only expenses_routes.dart, never
│   │                                                  #  presentation/ directly — architecture_boundary_test.dart)
│   ├── formatting/percent_formatter.dart             # formatPercent() — reused, unchanged
│   ├── formatting/currency_formatter.dart            # reused, unchanged
│   └── l10n/app_vi.arb, app_en.arb                   # + new report* keys
├── features/
│   ├── expense_control/
│   │   └── domain/expense_control_plan_service.dart  # + groupNameFor(tree, leafId)
│   └── expenses/
│       ├── expenses_routes.dart                       # existing file — + reportRoute(context, state),
│       │                                               # mirroring overviewRoute/spendingRoute exactly
│       ├── application/
│       │   └── report_summary.dart                   # new: ReportTotals, ReportItemEntry,
│       │                                              # ReportItemUsageState, computeReportTotals(),
│       │                                              # computeReportBreakdown()
│       └── presentation/
│           ├── report_providers.dart                 # new: selectedReportMonthProvider,
│           │                                          # reportTotalsProvider, reportBreakdownProvider
│           │                                          # (reuses existing transactionHistoryRecordsProvider
│           │                                          #  and expenseControlTreeProvider — no repository change)
│           ├── report_screen.dart                     # new: replaces the /history placeholder
│           └── widgets/
│               └── report_usage_bar.dart               # new: feature-local (Constitution: core/ only
│                                                        # once ≥2 features need it — research.md Decision 10)
test/
├── unit/features/expense_control/
│   └── expense_control_plan_service_test.dart          # existing file — + groupNameFor tests
├── unit/features/expenses/application/
│   └── report_summary_test.dart                        # new
├── widget/features/expenses/
│   └── report_screen_test.dart                         # new
├── widget/core/router/
│   └── app_shell_nav_bar_test.dart                      # existing file — + pie-chart icon assertion
└── integration/
    └── report_flow_test.dart                            # new: record transaction → reflected in Report
```

**Structure Decision**: Retain the existing Flutter feature-first layout.
`expense_control` gains one additive domain method (`groupNameFor`)
alongside its existing tree-shape methods; `expenses` gains the Report
application/presentation code, following the exact precedent already set
by `overview_summary_service.dart`/`overview_screen.dart` in the same
directories. No new feature directory, no new route path, no
`TransactionHistoryRepository` interface change.

## Phase 0: Research Summary

Research is recorded in [research.md](./research.md). Fourteen decisions
were made: reusing `watchTransactionHistory` with no repository change; a
new, screen-scoped month-selection provider (distinct from the pushed
`TransactionHistoryScreen`'s own, to avoid cross-contaminating the two
screens' independent month selections) while reusing the existing month-
math helpers as-is; confirming (not silently inheriting) that
`.autoDispose` correctly persists the selected month across tab switches
given the `StatefulShellRoute.indexedStack` shell's mount-preserving
behavior, resetting only on sign-out; splitting totals and breakdown into
two independent providers so a slow/failed one never blocks the other,
mirroring the Home Overview feature's precedent exactly; the month-
isolated (no-rollover) usage-percentage computation already agreed during
specification, now grounded against the actual `financial_transactions`
write paths; the "not allocated this month" distinct state for the zero-
allocation-but-spent case; a concrete overspend contract (bar fill capped
at 100%, danger-color fill, uncapped percentage text); a correction to an
initial automated research pass's incorrect claim that `formatPercent` is
unused (it is already used in `app_router.dart`'s discard-prompt dialog);
a new pure `groupNameFor` method placed on the existing
`ExpenseControlPlanService` rather than relying on `displayGroupName`
(which is asymmetric between income and expense transactions today); the
new usage-bar widget staying feature-local per the constitution's "core/
only once ≥2 features need it" rule; confirmation that `LucideIcons.pieChart`
exists at the pinned package version; the route path staying `/history`
with only its builder changing; a descending-by-spent default sort order;
and keeping the source design's "CHI TIÊU THEO KHOẢN" section header
copy, still accurate under the flat per-item presentation.

## Phase 1: Design Summary

- [data-model.md](./data-model.md) defines the read-only, derived value
  types (`ReportTotals`, `ReportItemEntry`, `ReportItemUsageState`) and
  their relationship to existing entities — no persisted schema changes.
- [contracts/report-ui.md](./contracts/report-ui.md) defines the internal
  application/UI contract: gateway contracts, presentation inputs/outputs,
  per-section and per-row state outcomes, error contract, and navigation
  contract (none — this screen introduces no outbound navigation).
- [quickstart.md](./quickstart.md) lists manual verification steps and the
  required automated regression coverage.
- Design reference package already copied to [reference/](./reference/)
  during specification (README, detailed layout spec, icon mapping, theme
  tokens, light/dark screenshots) — its originally-specified grouped/
  expandable breakdown presentation was superseded during specification by
  the flat, per-item, budget-usage approach (spec.md Assumptions); the
  reference material is kept for the parts that still apply (header, month
  selector, total cards, overall structure) and as long-term design-history
  reference, per the user's explicit request to preserve it.

## Complexity Tracking

No constitution violations or complexity exceptions are required. The one
numeric tension identified (44px design touch target vs. 48dp constitution
minimum) is resolved by Flutter's `IconButton` default minimum interactive
dimension already meeting 48dp, identically to the precedent already set
by the Home Overview feature — not by deviating from either requirement.
