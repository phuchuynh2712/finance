# Implementation Plan: Home Overview Screen

**Branch**: `20260924-095043-home-overview` | **Date**: 2026-09-24 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/20260924-095043-home-overview/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Replace the "Tổng quan" tab's current placeholder with a real, read-only home
dashboard shown immediately after sign-in. The screen combines a total
balance across all accounts, a negative-balance warning, a horizontally
scrollable accounts-at-a-glance list, and a chronological recent-transactions
list, all backed by existing local-first data with no new persisted schema.
Two small, additive gaps are filled to make this possible: a "most recent N
transactions" repository query (new method on the existing
`TransactionHistoryRepository` interface) and a compact currency formatter
(new method on the existing `CurrencyFormatter`).

## Technical Context

**Language/Version**: Dart 3.11 / Flutter (existing project)

**Primary Dependencies**: Flutter Material, flutter_riverpod, Drift/SQLite,
GoRouter, intl, lucide_icons, existing localization/theme/formatting helpers.
No new runtime package is required.

**Storage**: Existing local Drift/SQLite database only (`expense_control_items`,
`financial_transactions`). No schema change, no new table/column, no Supabase
migration — this feature is entirely read-only over data already persisted by
the Kế hoạch (formerly "Kiểm soát", see research.md Decision 10) and Thu chi
features.

**Testing**: `flutter analyze`, `dart format --output=none --set-exit-if-changed`,
focused unit/widget/integration tests, then `flutter test`.

**Target Platform**: Existing Android and iOS Flutter application.

**Project Type**: Feature-first mobile application.

**Performance Goals**: Total balance visible within 1 second of the tab
becoming visible using only local data (SC-001); recent-transactions query
uses a genuinely limited, indexed Drift query (`.limit(5)` on the existing
`(user_id, occurred_at)` index) rather than a wide fetch sliced client-side.
No dedicated SC-001 performance-regression test is included (unlike the
transaction-history feature's seeded 100-row filter benchmark for its
analogous SC-003): `OverviewSummaryService`'s total-balance computation is an
O(n) in-memory fold over `expenseControlTreeProvider`'s already-loaded root
list, where n is a user's account count — bounded and small in practice
(a personal-finance user manages a handful to a few dozen accounts, not
hundreds of transactions) — so there is no realistic data volume at which
this fold becomes the 1-second bottleneck. `OverviewSummaryService`'s unit
tests (tasks.md T006) already exercise the fold's correctness; a seeded
stress test would add maintenance cost without testing a genuine risk.

**Constraints**: Offline-first local reads only; read-only screen (no
mutation entry points); Vietnamese and English localization; established
light/dark design tokens; the header notification button must reconcile the
design's 44×44px visual with the constitution's ≥48×48dp touch-target
minimum (see research.md Decision 7); no raw financial values in logs; no
direct presentation dependency on another feature's internals.

**Scale/Scope**: One new full-screen tab content (replaces an existing
placeholder route); one new repository method; one new formatter method; one
new application-layer summary service and one new pure mapping function; no
new feature directory, no new route registration beyond the existing
`/overview` path's builder.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

- **Principle I — Code Quality: PASS.** `OverviewSummaryService` and the
  recent-transactions mapping function are plain, framework-independent Dart
  classes/functions outside any widget's `build()`; `OverviewScreen` stays
  state/rendering only, composing per-section `AsyncValue.when(...)` blocks.
- **Principle II — Testing Standards: PASS with required coverage.** Unit
  tests for `OverviewSummaryService` (fold + negative detection), for the new
  `watchRecent` repository method (limit, ordering, soft-delete exclusion),
  and for the relative-day pure function (injected `now`, no wall-clock
  reads); widget tests covering all four {accounts × transactions} empty/data
  combinations (SC-004) plus independent per-section loading/error/retry;
  integration coverage confirming a newly recorded transaction appears in
  Overview without a manual refresh. Existing domain/data coverage must not
  fall below 80%.
- **Principle III — UX Consistency: PASS, with one resolved tension.** Reuses
  `AppSemanticColors`, `CurrencyFormatter` (+ new `formatCompact`), ARB
  localization, `EmptyStateView`, Lexend theme. The header notification
  button's design-specified 44×44px visual is below the constitution's 48dp
  touch-target minimum; resolved by using a stock `IconButton`, whose default
  48dp minimum interactive dimension already covers this without any custom
  hit-area work (research.md Decision 7) — every other
  interactive element in this screen (account cards, transaction rows,
  "Xem tất cả" links) already exceeds 48dp from its own content/padding.
- **Principle IV — Performance: PASS.** Total-balance/negative computation
  folds an already-loaded in-memory list (no new query); the new
  `watchRecent(limit)` query is indexed and bounded at the database layer,
  not fetched-wide-then-sliced; the two independent data sources (the shared
  balance+accounts summary, and recent transactions) are each backed by their
  own provider so a slow or failed one never blocks the other's render
  (scoped rebuilds, not a single
  gating provider).
- **Clean Architecture: PASS.** New code lives in `lib/features/expenses/`
  (application + presentation only), importing only `expense_control`'s
  `domain/` (never its `presentation/`), matching
  `test/unit/architecture/architecture_boundary_test.dart`'s existing rule
  and the precedent already set by `balance_view_service.dart`. The
  greeting's display-name dependency is read from the core-level
  `authRepositoryProvider` (`core/auth/auth_state_provider.dart`), not from
  the `account` feature's presentation-layer `accountAuthActionsProvider` —
  the latter would have been a cross-feature presentation import and failed
  the architecture-boundary test (research.md Decision 6).
- **Offline-First and Security: PASS.** Every read is local-first
  (existing Drift-backed streams); no new Supabase call, no new persisted
  table, so no new RLS surface; no raw financial values or tokens are newly
  logged (reuses existing formatting/error patterns).

**Post-design re-check**: PASS. Research and contracts introduce no new
package, external service, network API, or unapproved architecture
exception; the one design/constitution numeric tension found (touch target)
has a standard, already-decided resolution rather than an open violation.

## Project Structure

### Documentation (this feature)

```text
specs/20260924-095043-home-overview/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
├── reference/           # Design handoff package (screens, tokens, icons) — kept as long-term reference
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
lib/
├── core/
│   ├── auth/auth_state_provider.dart              # authRepositoryProvider (reused, unchanged)
│   ├── formatting/currency_formatter.dart         # + formatCompact()
│   ├── l10n/app_vi.arb, app_en.arb                # tabExpenseControl label only (FR-015) + new overview* keys
│   └── router/app_router.dart                     # /overview builder → OverviewScreen
├── features/
│   ├── expense_control/
│   │   ├── data/expense_control_repository_impl.dart      # + watchRecent()
│   │   └── domain/transaction_history_repository.dart     # + watchRecent() signature
│   └── expenses/
│       ├── application/
│       │   ├── overview_summary_service.dart      # new: OverviewSummary, OverviewAccountSummary
│       │   └── overview_recent_transactions.dart  # new: OverviewTransactionItem, OverviewRelativeDay, mapping fn
│       └── presentation/
│           ├── overview_providers.dart            # new: providers wiring the above for the screen
│           │                                       # (negative-balance banner action wraps the pushed
│           │                                       #  TransactionHistoryScreen in a ProviderScope override —
│           │                                       #  see research.md Decision 9 — no change to
│           │                                       #  transaction_history_providers.dart itself)
│           └── overview_screen.dart               # new: replaces the /overview placeholder
test/
├── unit/features/expense_control/                 # watchRecent behavior
├── unit/features/expenses/application/             # OverviewSummaryService, relative-day mapping
├── widget/features/expenses/
│   ├── overview_screen_test.dart                  # new: OverviewScreen, all state/data combinations
│   └── transaction_history_screen_test.dart        # existing — its hand-written `_HistoryRepository`
│                                                     # fake must add a `watchRecent` implementation once
│                                                     # that method is added to `TransactionHistoryRepository`,
│                                                     # or the file stops compiling
└── integration/                                    # record-transaction → reflected in Overview
```

**Structure Decision**: Retain the existing Flutter feature-first layout.
`expense_control` gains one additive domain method (`watchRecent`) alongside
its existing `watchTransactionHistory`; `expenses` gains the Overview
application/presentation code, following the exact precedent already set by
`balance_view_service.dart` and `transaction_history.dart` in the same
directories. No new feature directory, no new route, no new shared widget.

## Phase 0: Research Summary

Research is recorded in [research.md](./research.md). Nine decisions were
made: feature-directory placement, total-balance/negative computation
(reusing `ExpenseControlPlanService.computeItemBalance` per root rather than
adding a new domain method), a new indexed+limited `watchRecent` query rather
than a wide-range client-side slice, relative-day bucketing kept out of the
application layer's string ownership, an additive `formatCompact` currency
method, a corrected core-level provider for the greeting's display name
(avoiding a cross-feature presentation-layer import that would have failed
the architecture-boundary test), a resolution for the 44px-vs-48dp touch
target tension (resolved by Flutter's own `IconButton` default, not a custom
technique), reuse of the existing `EmptyStateView`/loading patterns, and
navigation targets for every "Xem tất cả"/bell action — reusing
already-registered routes or existing push patterns. The negative-balance
banner's target was revised after user feedback: it opens the
transaction-history screen pre-filtered to that account's group (via a
`ProviderScope` override, reusing the already-existing
`TransactionHistoryFilter.group`), not the Kế hoạch tab, since a negative
balance is explained by recorded spending, not by the allocation plan
(Decision 9). The Kế hoạch tab itself is renamed from its prior label
"Kiểm soát" — a label-only ARB change confirmed to touch exactly one string
(Decision 10).

## Phase 1: Design Summary

- [data-model.md](./data-model.md) defines the read-only, derived value types
  (`OverviewAccountSummary`, `OverviewSummary`, `OverviewRelativeDay`,
  `OverviewTransactionItem`) and their relationship to existing entities —
  no persisted schema changes.
- [contracts/overview-ui.md](./contracts/overview-ui.md) defines the internal
  application/UI contract: gateway contracts, presentation inputs/outputs,
  per-section state outcomes, error contract, and navigation contract.
- [quickstart.md](./quickstart.md) lists manual verification steps and the
  required automated regression coverage.
- Design reference package copied to [reference/](./reference/) for
  long-term use (README, detailed layout spec, icon mapping, theme tokens,
  light/dark screenshots).

## Complexity Tracking

No constitution violations or complexity exceptions are required. The one
numeric tension identified (44px design touch target vs. 48dp constitution
minimum) is resolved by Flutter's `IconButton` default minimum interactive
dimension already meeting 48dp (research.md Decision 7), not by deviating
from either requirement.
