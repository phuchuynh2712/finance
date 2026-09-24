# Tasks: Transaction History

**Input**: Design documents from `specs/20260924-071637-transaction-history/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md),
[research.md](./research.md), [data-model.md](./data-model.md),
[contracts/](./contracts/), and [quickstart.md](./quickstart.md)

**Tests**: Required by the project constitution for financial data behavior,
screen workflows, and migration regressions.

**Organization**: Tasks are grouped by user story so each increment is
independently verifiable once the shared transaction-snapshot foundation is in
place.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel with tasks that modify different files after its
  stated dependencies are met.
- **[Story]**: The user story served by the task.

## Phase 1: Setup (Shared Test and Schema Preparation)

**Purpose**: Establish the regression-test seams and remote migration file used
by all user stories.

- [X] T001 Create legacy-schema upgrade coverage for transaction snapshots in `test/unit/core/database/app_database_migration_test.dart`
- [X] T002 [P] Add Supabase snapshot columns plus `updated_at`/`deleted_at` with preserved RLS/index behavior in `supabase/migrations/20260924_transaction_history_snapshots.sql`

---

## Phase 2: Foundational (Transaction Snapshot and History Contract)

**Purpose**: Create the immutable transaction data and application boundary that
all history workflows require.

**⚠️ CRITICAL**: Complete this phase before beginning user-story UI work.

- [X] T003 Add immutable display snapshot columns and `updatedAt`/`deletedAt` sync metadata to `lib/core/database/tables/financial_transactions_table.dart`
- [X] T004 Implement schema version upgrade, cumulative snapshot/timestamp backfill, null tombstones, and Archived Item fallback in `lib/core/database/app_database.dart`
- [X] T005 Create the pure owner-domain `TransactionHistoryRecord` in `lib/features/expense_control/domain/transaction_history_record.dart`
- [X] T006 Extend the financial-transaction repository contract with bounded user/month `TransactionHistoryRecord` reads in `lib/features/expense_control/domain/expense_control_repository.dart`
- [X] T007 Add Spending-specific transaction-history view mapping, filters, grouping, totals, and month-boundary helpers in `lib/features/expenses/application/transaction_history.dart`
- [X] T008 Update snapshot/timestamp capture, outbox serialization, tombstone-aware user/month ordered query, and owner-domain record mapping in `lib/features/expense_control/data/expense_control_repository_impl.dart`
- [X] T009 Expose owner-domain history records through the application facade and map them to Spending inputs in `lib/features/expenses/application/expense_control_gateway.dart`
- [X] T010 [P] Add snapshot/timestamp creation, outbox payload, tombstone-aware bounded query, ordering, and backfill/fallback regression tests in `test/unit/features/expense_control/expense_control_repository_impl_test.dart`
- [X] T011 [P] Add pure month bounds, expense-total, date-grouping, and filter tests in `test/unit/features/expenses/application/transaction_history_test.dart`

**Checkpoint**: Financial transaction snapshots migrate and synchronize safely;
the Spending feature has a testable, persistence-free history read contract.

---

## Phase 3: User Story 1 - Review Monthly Transactions (Priority: P1) 🎯 MVP

**Goal**: Open history from Spending and review current-month, date-grouped
transactions with correct immutable labels and expense total.

**Independent Test**: With known current-month income and expense transactions,
open history from Spending and identify every row's date, snapshot label,
classification/icon, signed amount, and expense-only total.

### Tests for User Story 1

- [X] T012 [P] [US1] Add localized history labels and state-message coverage in `test/unit/core/l10n_transaction_history_test.dart`
- [X] T013 [P] [US1] Add current-month history rendering, signed amount, total, loading, empty, error, retry, and back-navigation widget tests in `test/widget/features/expenses/transaction_history_screen_test.dart`
- [X] T014 [P] [US1] Add recorded-income/expense-to-current-history integration coverage in `test/integration/transaction_history_flow_test.dart`

### Implementation for User Story 1

- [X] T015 [P] [US1] Add Vietnamese and English transaction-history labels, semantics, empty/error/retry messages, and Archived Item translation in `lib/core/l10n/app_vi.arb` and `lib/core/l10n/app_en.arb`
- [X] T016 [US1] Create scoped history async-state providers for current month, All filter, retry, and reactive gateway data in `lib/features/expenses/presentation/transaction_history_providers.dart`
- [X] T017 [US1] Build the no-bottom-navigation transaction-history screen with fixed header, monthly expense total, date-grouped lazy rows, semantic signed amounts, and async states in `lib/features/expenses/presentation/transaction_history_screen.dart`
- [X] T018 [US1] Add the full-screen history route and replace the Spending placeholder action with navigation in `lib/core/router/app_router.dart` and `lib/features/expenses/presentation/spending_screen.dart`

**Checkpoint**: User Story 1 is independently usable from Spending for the
current month, including no data and recoverable failure states.

---

## Phase 4: User Story 2 - Browse Another Month (Priority: P2)

**Goal**: Move between non-future months while preserving correct history
contents and expense total.

**Independent Test**: Starting with transactions in adjacent months, select
previous and next month controls and confirm the selected month, list, and
expense total update; the current month cannot advance to the future.

### Tests for User Story 2

- [X] T019 [P] [US2] Add selected-month transitions and future-month guard tests in `test/unit/features/expenses/application/transaction_history_test.dart`
- [X] T020 [P] [US2] Add previous/next month control and preserved-state widget tests in `test/widget/features/expenses/transaction_history_screen_test.dart`

### Implementation for User Story 2

- [X] T021 [US2] Add selected-month state transitions and current-month guard to `lib/features/expenses/presentation/transaction_history_providers.dart`
- [X] T022 [US2] Add localized selected-month display and accessible previous/next controls to `lib/features/expenses/presentation/transaction_history_screen.dart`

**Checkpoint**: User Stories 1 and 2 are independently testable; browsing a
past month never exposes a future month or stale current-month results.

---

## Phase 5: User Story 3 - Filter Monthly History (Priority: P3)

**Goal**: Filter a selected month's history by All, snapshot-derived budget
group, or Income, including groups that were later deleted.

**Independent Test**: For a month containing multiple expense groups and
income, select each filter and confirm only matching rows remain, one filter
is active, and a no-match selection keeps the chosen filter/month.

### Tests for User Story 3

- [X] T023 [P] [US3] Add group, Income, All, deleted-group, and no-match filter tests in `test/unit/features/expenses/application/transaction_history_test.dart`
- [X] T024 [P] [US3] Add horizontal single-select filter-chip and retained-empty-filter widget tests in `test/widget/features/expenses/transaction_history_screen_test.dart`

### Implementation for User Story 3

- [X] T025 [US3] Add active-filter state and selected-month snapshot-group derivation to `lib/features/expenses/presentation/transaction_history_providers.dart`
- [X] T026 [US3] Add horizontal accessible All/group/Income filter controls and filtered-list rendering to `lib/features/expenses/presentation/transaction_history_screen.dart`

**Checkpoint**: All three stories are independently testable with snapshot-based
history that remains reviewable after source item changes or deletion.

---

## Phase 6: Polish and Cross-Cutting Verification

**Purpose**: Confirm quality gates, accessibility, localization, format, and
the complete critical workflow.

- [X] T027 [P] Add light/dark, long localized label, 48dp target, and semantics regression coverage in `test/widget/features/expenses/transaction_history_screen_test.dart`
- [X] T028 [P] Regenerate localization and Drift outputs after schema/ARB changes in `lib/core/l10n/app_localizations.dart` and `lib/core/database/app_database.g.dart`
- [X] T029 Run formatting and static analysis for `lib/` and `test/` using `dart format --output=none --set-exit-if-changed lib test` and `flutter analyze`
- [X] T030 Run focused unit, widget, and integration suites listed in `specs/20260924-071637-transaction-history/quickstart.md`
- [ ] T031 Run the complete Flutter suite and manually verify the Quickstart visual flow in `specs/20260924-071637-transaction-history/quickstart.md`
- [X] T032 [P] Add a seeded 100-row filter performance regression that asserts SC-003's 1-second threshold in `test/widget/features/expenses/transaction_history_performance_test.dart`

---

## Dependencies and Execution Order

### Phase Dependencies

- **Phase 1** starts immediately. T002 can proceed in parallel with T001.
- **Phase 2** depends on Phase 1. T003 and T005/T007 can begin after the
  migration shape is agreed; T004 depends on T003; T006 depends on T005;
  T008 depends on T003-T007; T009 depends on T006/T008; T010-T011 verify the
  completed foundation.
- **US1** depends on Phase 2 and is the MVP. T012-T015 can proceed in parallel;
  T016 follows T007/T009; T017 follows T015-T016; T018 follows T017.
- **US2** depends on US1's shared screen/provider implementation. T019-T020
  can run in parallel before T021-T022.
- **US3** depends on US1's shared screen/provider implementation. T023-T024
  can run in parallel before T025-T026.
- **Polish** depends on all selected user stories; T027, T028, and T032 can run in
  parallel, followed by T029-T031.

### User Story Dependencies

- **US1 (P1)**: Requires only the foundational transaction-history contract.
- **US2 (P2)**: Extends US1's selected-month screen state; it does not change
  snapshot persistence.
- **US3 (P3)**: Extends US1's history result; it is independent of US2 except
  for sharing the selected-month state holder.

### Parallel Opportunities

- T001 and T002 modify independent local/remote migration surfaces.
- T010 and T011 cover separate repository and application-layer files.
- T012, T013, and T014 are separate test files after their implementation
  seams are defined.
- T019/T020 and T023/T024 are parallel test work within their respective
  story phases.
- T027, T028, and T032 are independent final verification/generation tasks.

## Parallel Example: User Story 1

```text
Task: "Add localized history labels and state-message coverage in test/unit/core/l10n_transaction_history_test.dart"
Task: "Add current-month history widget coverage in test/widget/features/expenses/transaction_history_screen_test.dart"
Task: "Add record-to-history integration coverage in test/integration/transaction_history_flow_test.dart"
Task: "Add history ARB strings in lib/core/l10n/app_vi.arb and lib/core/l10n/app_en.arb"
```

## Implementation Strategy

### MVP First

1. Complete Phases 1 and 2, including migration, snapshot writing, outbox
   payloads, and the history read contract.
2. Complete US1 and verify current-month navigation from Spending, date groups,
   expense total, immutable labels, and async states.
3. Run the US1 focused tests before adding month browsing or filters.

### Incremental Delivery

1. Foundation plus US1 delivers a reliable current-month history view.
2. US2 adds time navigation without changing financial write behavior.
3. US3 adds focused review filters from immutable snapshot values.
4. Polish validates both themes, both locales, migration safety, and full
   regression coverage.