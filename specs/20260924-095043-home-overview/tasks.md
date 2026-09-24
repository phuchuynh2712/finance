# Tasks: Home Overview Screen

**Input**: Design documents from `specs/20260924-095043-home-overview/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md),
[research.md](./research.md), [data-model.md](./data-model.md),
[contracts/](./contracts/), and [quickstart.md](./quickstart.md)

**Tests**: Required by the project constitution for financial-figure display,
screen workflows, and cross-feature repository changes.

**Organization**: Tasks are grouped by user story so each increment is
independently verifiable once the shared repository extension is in place.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel with tasks that modify different files after
  its stated dependencies are met.
- **[Story]**: The user story served by the task.

## Phase 1: Setup (Tab Label Fix)

**Purpose**: Land the one standalone, non-blocking requirement (FR-015) that
other requirements reference by name, before any story-specific work begins,
and keep the existing test suite green afterward.

- [X] T001 Rename the `tabExpenseControl` bottom-navigation label from
  "Kiểm soát"/"Control" to "Kế hoạch"/"Plan" (label only — no route, class,
  or provider name changes) in `lib/core/l10n/app_vi.arb` and
  `lib/core/l10n/app_en.arb`
- [X] T001b Update the 3 existing tests that reference the old label so the
  suite keeps passing after T001's rename: fix the expected English value in
  `test/unit/core/l10n_expense_control_en_test.dart`, update the hardcoded
  `_tabLabels` list in `test/widget/core/router/app_shell_nav_bar_test.dart`,
  and update every `find.text('Kiểm soát')` lookup and surrounding comment in
  `test/widget/core/router/app_shell_discard_prompt_test.dart` to
  `'Kế hoạch'` (depends on T001) — note: `spending_screen_test.dart` and
  `income_screen_test.dart` reference an unrelated "Kiểm soát chi tiêu"
  empty-state string, not `tabExpenseControl`, and are unaffected

**Checkpoint**: The bottom-nav label reads "Kế hoạch"/"Plan" everywhere it's
used, and the pre-existing test suite (nav bar labels, discard-prompt
navigation, l10n) still passes against the new label.

---

## Phase 2: Foundational (Recent-Transactions Repository Extension)

**Purpose**: Extend the cross-feature `TransactionHistoryRepository` contract
with a most-recent-N query before any Overview UI consumes it, and keep the
existing transaction-history test suite compiling.

**⚠️ CRITICAL**: Complete this phase before beginning User Story 2 work
(User Story 1 does not depend on it).

- [X] T002 [P] Add `Stream<List<TransactionHistoryRecord>> watchRecent({required int limit})` to the `TransactionHistoryRepository` interface in `lib/features/expense_control/domain/transaction_history_repository.dart`
- [X] T003 [P] Implement `watchRecent` in `ExpenseControlRepositoryImpl` using the existing `where`/`orderBy` chain plus Drift's `.limit(limit)`, dropping the date-range clause, in `lib/features/expense_control/data/expense_control_repository_impl.dart` (depends on T002)
- [X] T004 [P] Add a `watchRecent` implementation to the existing hand-written `_HistoryRepository` fake so it keeps compiling once the interface gains the method, in `test/widget/features/expenses/transaction_history_screen_test.dart` (depends on T002)
- [X] T005 [P] Add `watchRecent` regression tests (returns at most `limit` rows, newest-first, excludes soft-deleted rows, not bounded by any calendar month) in `test/unit/features/expense_control/expense_control_repository_impl_test.dart` (depends on T003)

**Checkpoint**: The repository can serve "most recent N transactions across
all accounts" independent of any month boundary; the existing
transaction-history widget test suite still compiles and passes.

---

## Phase 3: User Story 1 - See total balance and warnings at a glance (Priority: P1) 🎯 MVP

**Goal**: Replace the Overview placeholder with a real screen showing the
combined total balance (compact + full) and a negative-balance warning whose
"Xem chi tiết →" action opens that account's transactions.

**Independent Test**: Sign in with a user who has at least one account with a
negative balance; verify the total balance card and the negative-balance
warning both render correctly, and "Xem chi tiết →" opens the transaction
history filtered to that account's expenses.

### Tests for User Story 1

- [X] T006 [P] [US1] Add `OverviewSummaryService` tests (total-balance fold, negative-account detection, and agreement with `ExpenseControlPlanService.computeItemBalance`'s group-vs-leaf rule) in `test/unit/features/expenses/application/overview_summary_service_test.dart` — this correctness coverage plus the fold's O(n)-over-a-small-account-count shape is what satisfies SC-001 without a dedicated performance-regression task (see plan.md's Performance Goals)
- [X] T007 [P] [US1] Add `CurrencyFormatter.formatCompact` tests (≥1,000,000 "X,Y triệu ₫" rendering for `vi`, below-threshold fallback to `format()`, `en` always falling back to `format()`) in `test/unit/core/formatting/currency_formatter_test.dart`
- [X] T008 [P] [US1] Add `OverviewScreen` widget tests for the total-balance card (loading, error+retry, zero-balance, populated) and the negative-balance banner (hidden when no account is negative, shown and naming the account otherwise, "Xem chi tiết →" pushes `TransactionHistoryScreen` with the filter provider overridden to `TransactionHistoryFilter.group(accountName)`) in `test/widget/features/expenses/overview_screen_test.dart`

### Implementation for User Story 1

- [X] T009 [P] [US1] Create `OverviewAccountSummary` and `OverviewSummary` value types plus `OverviewSummaryService` (folds `expenseControlTreeProvider`'s root nodes via the existing `ExpenseControlPlanService.computeItemBalance`) in `lib/features/expenses/application/overview_summary_service.dart`
- [X] T010 [P] [US1] Add `formatCompact(int amountInVnd)` to `CurrencyFormatter` in `lib/core/formatting/currency_formatter.dart` (additive; no existing call site changes)
- [X] T011 [US1] Add Vietnamese and English ARB strings for the total-balance card and negative-balance banner (label, warning text, "Xem chi tiết" action, retry/error text) in `lib/core/l10n/app_vi.arb` and `lib/core/l10n/app_en.arb` (depends on T001 for the shared file's current state)
- [X] T012 [US1] Create `overviewSummaryProvider` wiring `expenseControlTreeProvider` through `OverviewSummaryService` in `lib/features/expenses/presentation/overview_providers.dart` (new file) (depends on T009)
- [X] T013 [US1] Build the `OverviewScreen` shell (`Scaffold`/`SafeArea`, scrollable body) with the total-balance card and negative-balance banner sections, `CircularProgressIndicator` loading and `EmptyStateView` retry-error states, and "Xem chi tiết →" navigating via a `ProviderScope` override (`selectedTransactionHistoryFilterProvider.overrideWith((ref) => TransactionHistoryFilter.group(accountName))`) around a pushed `TransactionHistoryScreen`, in `lib/features/expenses/presentation/overview_screen.dart` (depends on T010, T011, T012)
- [X] T014 [US1] Replace the `/overview` route's `NotAvailablePlaceholderScreen` builder with `OverviewScreen` in `lib/core/router/app_router.dart` (depends on T013)

**Checkpoint**: User Story 1 is independently usable — opening the app shows
a real total balance and a working negative-balance warning. Other Overview
sections may still be absent from the screen until later stories land.

---

## Phase 4: User Story 2 - Scan accounts and recent activity without switching tabs (Priority: P2)

**Goal**: Add the accounts-at-a-glance horizontal list and the
recent-transactions list, each with its own empty state and "Xem tất cả"
entry point.

**Independent Test**: With sample data seeded (multiple accounts, multiple
transactions), verify the accounts list and recent-transactions list both
render with correct amounts, without needing User Story 1's banner present.

### Tests for User Story 2

- [X] T015 [P] [US2] Add relative-day bucketing tests (today / yesterday / N days ago, against an injected reference date, no `DateTime.now()` calls) in `test/unit/features/expenses/application/overview_recent_transactions_test.dart`
- [X] T016 [P] [US2] Extend `OverviewScreen` widget tests: accounts section (populated list with each card's balance color reflecting negative/positive/zero per FR-004, empty state, "Xem tất cả" navigates to the Kế hoạch tab) and recent-transactions section (rows with relative time and signed/colored amounts, empty state, "Xem tất cả" pushes an unfiltered `TransactionHistoryScreen`) in `test/widget/features/expenses/overview_screen_test.dart`

### Implementation for User Story 2

- [X] T017 [P] [US2] Create `OverviewRelativeDay` and `OverviewTransactionItem` plus the pure `buildOverviewRecentItems(records, {required now})` mapping function in `lib/features/expenses/application/overview_recent_transactions.dart`
- [X] T018 [US2] Add `overviewRecentTransactionsProvider` (`StreamProvider` watching `transactionHistoryRepositoryProvider.watchRecent(limit: 5)`) to `lib/features/expenses/presentation/overview_providers.dart` (depends on T017, and on Phase 2's T002/T003)
- [X] T019 [P] [US2] Add Vietnamese and English ARB strings for the accounts section, recent-transactions section, both "Xem tất cả" actions, and the relative-time labels ("Hôm nay"/"Hôm qua"/"{n} ngày trước") in `lib/core/l10n/app_vi.arb` and `lib/core/l10n/app_en.arb`
- [X] T020 [US2] Add the accounts horizontal-scroll section (icon/name/balance cards with balance color reflecting `OverviewAccountSummary.isNegative`/positive/zero via `AppSemanticColors` per FR-004, `EmptyStateView` when empty, "Xem tất cả" via `context.go('/expense-control')`) and the recent-transactions section (rows via `buildOverviewRecentItems`, localized relative-time label, signed/colored amount, `EmptyStateView` when empty, "Xem tất cả" pushing a plain `TransactionHistoryScreen`) to `lib/features/expenses/presentation/overview_screen.dart`, rendering both lists with `ListView.builder`/`SliverList.builder` (not eager `Column`/`.map()`) per constitution Principle IV (depends on T018, T019, and User Story 1's T013)

**Checkpoint**: User Stories 1 and 2 together deliver the full read-only
dashboard except the personalized header (greeting/bell).

---

## Phase 5: User Story 3 - Personalized greeting on entry (Priority: P3)

**Goal**: Greet the signed-in user by name (with the established email-prefix
fallback) and complete the header with a working notification entry point.

**Independent Test**: Sign in with an account that has a display name set,
and separately with one that does not; verify the header shows the display
name in the first case and the email-prefix fallback in the second.

### Tests for User Story 3

- [X] T021 [P] [US3] Extend `OverviewScreen` widget tests: header greeting text with a display name, header greeting falling back to the email prefix when no display name is set, and the bell button pushing the "not available yet" placeholder screen in `test/widget/features/expenses/overview_screen_test.dart`

### Implementation for User Story 3

- [X] T022 [P] [US3] Add Vietnamese and English ARB strings for the greeting (with a `{name}` placeholder and matching `@overviewGreeting` metadata) and the notification button's semantic label in `lib/core/l10n/app_vi.arb` and `lib/core/l10n/app_en.arb`
- [X] T023 [US3] Wire the header row's greeting (`authRepositoryProvider.currentDisplayName`, falling back to `currentEmail?.split('@').first ?? ''`) and a stock `IconButton` bell (default constraints — no custom sizing, per research.md Decision 7) pushing `NotAvailablePlaceholderScreen`, in `lib/features/expenses/presentation/overview_screen.dart` (depends on T013, T022)

**Checkpoint**: All three user stories are independently testable; the
Overview screen now matches the full spec.

---

## Phase 6: Polish and Cross-Cutting Verification

**Purpose**: Confirm quality gates, the four empty/data combinations, both
themes, both locales, and the complete critical workflow.

- [X] T024 [P] Add an integration test confirming a newly recorded income or expense transaction is reflected in Overview's total balance and recent-transactions list without a manual refresh, in `test/integration/overview_flow_test.dart`
- [X] T025 [P] Add SC-004's four {has accounts / no accounts} × {has transactions / no transactions} combinations, light/dark theme rendering, and the notification button's ≥48dp tap-target verification to `test/widget/features/expenses/overview_screen_test.dart`
- [X] T026 [P] Regenerate localization output after all ARB changes in `lib/core/l10n/app_localizations.dart`, `app_localizations_en.dart`, and `app_localizations_vi.dart`
- [X] T027 Run formatting and static analysis for `lib/` and `test/` using `dart format --output=none --set-exit-if-changed lib test` and `flutter analyze`
- [X] T028 Run focused unit, widget, and integration suites listed in `specs/20260924-095043-home-overview/quickstart.md`
- [X] T029 Run the complete Flutter suite and manually verify the Quickstart visual flow in `specs/20260924-095043-home-overview/quickstart.md` — `flutter test` (355 tests) passes in full; manually verified live on the Pixel_9 emulator against the real Supabase QA test account (`test.biometric.qa@example.com`): total balance card (compact+full, live update), negative-balance banner (appearance, color, "Xem chi tiết →" opening transaction history pre-filtered to the correct group), accounts list (color-by-sign, "Xem tất cả" → Kế hoạch tab), recent-transactions list (relative-day labels, "Xem tất cả" → unfiltered history), notification bell → placeholder, reactive update with no manual refresh after recording a real expense, light and dark theme rendering — all matched the design reference exactly

---

## Dependencies and Execution Order

### Phase Dependencies

- **Phase 1** starts immediately, no dependencies. T001b depends on T001
  (its assertions target the label T001 produces).
- **Phase 2** has no dependency on Phase 1 and could run in parallel with it,
  but is required before User Story 2 (not User Story 1). T002 must land
  before T003 and T004; T005 depends on T003.
- **US1** depends only on Phase 1 (for T011's ARB file state) — not on Phase
  2. T006-T008 can proceed in parallel; T009-T010 can proceed in parallel;
  T011 follows T001; T012 follows T009; T013 follows T010-T012; T014 follows
  T013.
- **US2** depends on US1's screen file (T013) and on Phase 2's repository
  method (T002-T003). T015-T016 can proceed in parallel; T017 has no
  dependency and can start anytime; T018 follows T017 and Phase 2; T019 has
  no dependency; T020 follows T018-T019 and US1's T013.
- **US3** depends on US1's screen file (T013). T021 can be drafted anytime;
  T022 has no dependency; T023 follows T013 and T022.
- **Polish** depends on all three user stories being complete; T024-T026 can
  run in parallel, followed by T027-T029.

### User Story Dependencies

- **US1 (P1)**: Requires only the Setup phase's tab-rename ARB state; does
  not require the Phase 2 repository extension.
- **US2 (P2)**: Extends US1's screen/providers files; requires Phase 2's
  `watchRecent` to exist.
- **US3 (P3)**: Extends US1's screen file; independent of US2 except for
  sharing that same screen file.

### Parallel Opportunities

- T002, T003, and T004 all stem from the same interface addition but touch
  three different files once T002 lands.
- T006, T007, and T008 are three separate test files within US1.
- T009 and T010 are separate application/core files within US1.
- T015 and T016 are separate test files within US2; T017 has no blocking
  dependency and can be implemented alongside US1 if capacity allows.
- T024, T025, and T026 are independent final verification/generation tasks.

## Parallel Example: User Story 1

```text
Task: "Add OverviewSummaryService tests in test/unit/features/expenses/application/overview_summary_service_test.dart"
Task: "Add CurrencyFormatter.formatCompact tests in test/unit/core/formatting/currency_formatter_test.dart"
Task: "Add OverviewScreen widget tests for the balance card and warning banner in test/widget/features/expenses/overview_screen_test.dart"
Task: "Create OverviewSummaryService in lib/features/expenses/application/overview_summary_service.dart"
Task: "Add formatCompact to lib/core/formatting/currency_formatter.dart"
```

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (tab rename).
2. Complete Phase 3: User Story 1 (Phase 2 is not required for US1).
3. **STOP and VALIDATE**: Test User Story 1 independently — total balance and
   negative-balance warning both work from a cold app launch.
4. Deploy/demo if ready — the accounts list, recent-transactions list, and
   personalized greeting can follow as separate increments.

### Incremental Delivery

1. Setup + User Story 1 → total balance and warning are live (MVP!).
2. Add Phase 2 + User Story 2 → accounts list and recent activity appear.
3. Add User Story 3 → the header is fully personalized.
4. Polish validates both themes, both locales, and full regression coverage.
