# Tasks: Monthly Report Screen

**Input**: Design documents from `specs/20260924-181441-report-monthly-summary/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md),
[research.md](./research.md), [data-model.md](./data-model.md),
[contracts/](./contracts/), and [quickstart.md](./quickstart.md)

**Tests**: Required by the project constitution for financial-figure
display, screen workflows, and the cross-feature domain method change.

**Organization**: Tasks are grouped by user story so each increment is
independently verifiable once the shared route/provider foundation is in
place.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel with tasks that modify different files after
  its stated dependencies are met.
- **[Story]**: The user story served by the task.

## Phase 1: Setup (Bottom-Nav Icon)

**Purpose**: Land the one standalone, non-story-specific requirement
(FR-001) before any story-specific work begins.

- [X] T001 Change the fourth `NavigationDestination`'s icon from
  `LucideIcons.history` to `LucideIcons.pieChart` (label and position
  unchanged) in `lib/core/router/app_router.dart`
- [X] T001b Add a widget test asserting the fourth `NavigationDestination`'s
  icon is `LucideIcons.pieChart` (existing assertions in this file only
  check label text, not icon identity — this is new coverage) in
  `test/widget/core/router/app_shell_nav_bar_test.dart` (depends on T001)

**Checkpoint**: The bottom-nav tab shows the pie-chart icon; existing
nav-bar tests still pass.

---

## Phase 2: Foundational (Route, Screen Shell, Month State)

**Purpose**: Make the Report screen reachable at `/history` and establish
the shared month-selection state every story reads, before any story adds
its own section content.

**⚠️ CRITICAL**: Complete this phase before beginning any user story.

- [X] T002 [P] Create `selectedReportMonthProvider`
  (`StateProvider.autoDispose<DateTime>`, seeded with
  `monthStart(DateTime.now())`, reusing `monthStart` from
  `lib/features/expenses/application/transaction_history.dart`) in new file
  `lib/features/expenses/presentation/report_providers.dart`
- [X] T003 [P] Create a minimal `ReportScreen` shell (`Scaffold`/`SafeArea`,
  fixed header with icon badge + "Báo cáo" title per FR-002, no content
  sections yet) in new file `lib/features/expenses/presentation/report_screen.dart`
- [X] T004 Change the `/history` `GoRoute`'s `builder` from
  `NotAvailablePlaceholderScreen(...)` to `reportRoute` (path
  unchanged — research.md Decision 12; wired through
  `expenses_routes.dart`'s `reportRoute`, not a direct `presentation/`
  import from `core/router/` — research.md Decision 15) in
  `lib/core/router/app_router.dart` (depends on T001 — same file — and T003)
- [X] T004b Add a full-shell widget test proving
  `selectedReportMonthProvider`'s selected month survives switching to a
  different bottom-nav tab and back (research.md Decision 3). This
  verifies the Foundational `.autoDispose` choice itself, not a
  spec.md-visible user story, so it belongs here rather than under a
  story label. Seed a non-default month via a `ProviderScope` override
  (`selectedReportMonthProvider.overrideWith((ref) => <a past month>)`) —
  matching the existing override-based seeding pattern already used
  elsewhere in this codebase (e.g. Overview's negative-balance banner
  test) — rather than depending on the not-yet-built prev/next buttons;
  pump the real `appRouterProvider`-backed shell (mirroring
  `test/widget/core/router/app_shell_nav_bar_test.dart`'s harness, since a
  bare `MaterialApp(home: ReportScreen())` has no second tab to switch to
  and cannot exercise `StatefulShellRoute.indexedStack`'s
  mount-preservation behavior at all), switch to a different tab via
  `NavigationBar.onDestinationSelected`, switch back, and assert the
  overridden month is still selected, in
  `test/widget/core/router/app_shell_nav_bar_test.dart` (depends on T002,
  T004)

**Checkpoint**: Selecting the fourth tab opens the new (still empty)
`ReportScreen` instead of the placeholder; a month is already selected
internally, defaulting to the current month, and is proven to survive a
tab switch.

---

## Phase 3: User Story 1 - See this month's income and expense totals (Priority: P1) 🎯 MVP

**Goal**: Show total income and total expense for the current calendar
month.

**Independent Test**: Open the Báo cáo tab and confirm it shows one income
total and one expense total, both computed only from the current month's
transactions.

### Tests for User Story 1

- [X] T005 [P] [US1] Add `computeReportTotals` unit tests (income-only fold,
  expense-only fold, mixed records, empty list → both zero) in new file
  `test/unit/features/expenses/application/report_summary_test.dart`
- [X] T006 [P] [US1] Add `ReportScreen` totals-section widget tests
  (loading, error + retry, zero-activity month showing "0 ₫", populated) in
  new file `test/widget/features/expenses/report_screen_test.dart` (depends
  on T003)

### Implementation for User Story 1

- [X] T007 [P] [US1] Create `ReportTotals` value type and
  `computeReportTotals(List<TransactionHistoryRecord> records)` pure
  function in new file
  `lib/features/expenses/application/report_summary.dart`
- [X] T008 [US1] Add Vietnamese and English ARB strings for the income and
  expense card labels and the totals-section retry/error text in
  `lib/core/l10n/app_vi.arb` and `lib/core/l10n/app_en.arb`
- [X] T009 [US1] Create `reportTotalsProvider`
  (`StreamProvider.autoDispose.family<ReportTotals, DateTime>`, built on
  the existing `transactionHistoryRecordsProvider(month)` +
  `computeReportTotals`) in
  `lib/features/expenses/presentation/report_providers.dart` (depends on
  T002 — same file — and T007)
- [X] T010 [US1] Add the two total cards to `ReportScreen`, wired to
  `reportTotalsProvider(selectedMonth)`, with `CircularProgressIndicator`
  loading and `EmptyStateView` retry-error states, in
  `lib/features/expenses/presentation/report_screen.dart` (depends on T003
  — same file — T008, T009)

**Checkpoint**: User Story 1 is fully functional and independently
testable — the Report tab shows correct totals for the current month, with
no navigation controls and no breakdown yet.

---

## Phase 4: User Story 2 - Browse totals for a different month (Priority: P2)

**Goal**: Let the user move to a previous or (bounded) next month and see
the totals update accordingly.

**Independent Test**: From the Report tab, navigate to the previous month
and confirm the totals change to match that month's transactions; confirm
the forward control cannot advance past the current month.

### Tests for User Story 2

- [X] T011 [P] [US2] Add `ReportScreen` month-navigation widget tests:
  previous/next controls update the displayed month and totals, and the
  forward control is disabled/blocked on the current month
  (`canAdvanceMonth`) in `test/widget/features/expenses/report_screen_test.dart`
  (same file as T006 — sequenced after it, not parallel with it).
  Cross-tab-switch persistence is covered separately by T004b, in a
  full-shell harness this in-isolation `ReportScreen` test cannot provide.

### Implementation for User Story 2

- [X] T012 [US2] Add previous/next `IconButton` month controls and a
  locale-aware month label (`intl`'s `DateFormat`) to `ReportScreen`,
  reading/writing `selectedReportMonthProvider` and reusing
  `previousMonth`/`nextMonth`/`canAdvanceMonth` from
  `lib/features/expenses/application/transaction_history.dart`, in
  `lib/features/expenses/presentation/report_screen.dart` (depends on T010
  — same file — and T002)

**Checkpoint**: User Stories 1 and 2 together are fully functional — a user
can browse any past month's totals.

---

## Phase 5: User Story 3 - See how much of each item's monthly budget was used (Priority: P2)

**Goal**: Show a flat, per-item breakdown for the selected month — name,
parent group, amount spent, and a usage indicator against that item's own
income allocation for the month.

**Independent Test**: Open the Report tab for a month with allocated and/or
spent items and confirm each qualifying item appears with the correct
name, group label, spent amount, and usage state (tracked / unused / not
allocated), while items with no activity that month do not appear.

### Tests for User Story 3

- [X] T013 [P] [US3] Add `ExpenseControlPlanService.groupNameFor` unit
  tests (a nested leaf returns its parent group's name; a standalone
  top-level leaf returns `null`; an id not present in the tree is handled
  without throwing) in existing file
  `test/unit/features/expense_control/expense_control_plan_service_test.dart`
- [X] T014 [P] [US3] Add `computeReportBreakdown` unit tests: per-item
  `spent`/`allocated` aggregation by `sourceItemId`; all three
  `ReportItemUsageState` branches (`notAllocated`, `unused`, `tracked`
  including `usagePercent` over 100); list-membership excludes an item with
  zero activity in both directions; result is sorted by `spent` descending;
  an item id no longer present in the current tree still appears using the
  transaction's own snapshotted `displayName` (data-model.md's archived-item
  fallback — not just the live-tree name-lookup path); and, given the same
  record list passed to both functions, `sum(breakdown.map((e) => e.spent))
  == computeReportTotals(records).totalExpense` and the equivalent
  income/`allocated` sum both hold (SC-005 — the two folds must never
  silently disagree) — in
  `test/unit/features/expenses/application/report_summary_test.dart`
  (same file as T005 — sequenced after it, not parallel with it)
- [X] T015 [P] [US3] Add `ReportScreen` breakdown-section widget tests: the
  three per-row states render correctly (including the "not allocated this
  month" indicator for `notAllocated`), an over-100%-usage row's bar
  visually caps at full width with the danger fill color while its
  percentage text shows the true value, the empty-month state shows an
  empty-state message instead of a list, and — using the already-built
  previous/next controls from T012 — navigating to a different month
  updates the breakdown list to that month's items, not just the totals
  cards (FR-016 covers both sections; T011 only proves the totals half
  since the breakdown section doesn't exist yet at that point in the
  build) in `test/widget/features/expenses/report_screen_test.dart` (same
  file as T006/T011 — sequenced after them, not parallel with them;
  depends on T012 for the nav controls this specific case drives)

### Implementation for User Story 3

- [X] T016 [P] [US3] Add `String? groupNameFor(List<ExpenseControlNode>
  tree, String leafId)` (returns the containing top-level node's name, or
  `null` for a standalone top-level leaf) to `ExpenseControlPlanService` in
  `lib/features/expense_control/domain/expense_control_plan_service.dart`
- [X] T017 [US3] Add `ReportItemEntry`, `ReportItemUsageState`
  (`notAllocated` / `unused` / `tracked`), and
  `computeReportBreakdown(List<TransactionHistoryRecord> records,
  List<ExpenseControlNode> tree)` (groups by `sourceItemId`, resolves
  name/group via `groupNameFor` when the item still exists in `tree`;
  otherwise falls back to that item's own snapshotted
  `TransactionHistoryRecord.displayName` with no group label —
  data-model.md's archived-item case, spec.md Assumptions — excludes
  zero-activity items, sorts by `spent` descending) to
  `lib/features/expenses/application/report_summary.dart` (same file as
  T007 — sequenced after it — and depends on T016)
- [X] T018 [P] [US3] Create a `ReportUsageBar` presentational widget (fill
  width = `min(usagePercent, 100)%`, fill color switches to the existing
  danger semantic color when `usagePercent > 100`, otherwise primary — per
  research.md Decision 7) in new file
  `lib/features/expenses/presentation/widgets/report_usage_bar.dart`
- [X] T019 [US3] Add Vietnamese and English ARB strings for the "CHI TIÊU
  THEO KHOẢN" section eyebrow, the "not allocated this month" row
  indicator, and the breakdown empty-state message in
  `lib/core/l10n/app_vi.arb` and `lib/core/l10n/app_en.arb` (same files as
  T008 — sequenced after it)
- [X] T020 [US3] Create `reportBreakdownProvider`
  (`StreamProvider.autoDispose.family<List<ReportItemEntry>, DateTime>`,
  combining `transactionHistoryRecordsProvider(month)` and
  `expenseControlTreeProvider` through `computeReportBreakdown`) in
  `lib/features/expenses/presentation/report_providers.dart` (same file as
  T009 — sequenced after it — and depends on T017)
- [X] T021 [US3] Add the item-breakdown section to `ReportScreen`, using
  `ReportUsageBar` per row, wired to `reportBreakdownProvider
  (selectedMonth)`, with `CircularProgressIndicator` loading,
  `EmptyStateView` retry-error, and empty-state-message states, in
  `lib/features/expenses/presentation/report_screen.dart` (depends on T012
  — same file — T018, T019, T020)

**Checkpoint**: All three user stories are independently functional; the
full Report screen matches contracts/report-ui.md end to end.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Verify the whole feature together and close out regression
coverage that spans more than one story.

- [X] T022 [P] Add an integration test confirming a newly recorded income
  allocation or expense (while on, or before returning to, the Report tab)
  is reflected in its totals and breakdown without a manual refresh, in
  new file `test/integration/report_flow_test.dart`
- [X] T023 Run the full manual verification flow in
  [quickstart.md](./quickstart.md) against a debug build — verified live on
  the Android emulator (API 37), signed in with the existing QA test
  account: pie-chart tab icon, real Report screen replacing the
  placeholder, current-month default, prev/next navigation (including
  forward correctly blocked on the current month and an empty prior month
  correctly showing the empty-state message), and a live income allocation
  recorded via Thu chi reflected in Báo cáo's totals and breakdown without
  any manual refresh — including the `notAllocated` state (a same-named
  but different-id leaf item correctly still unallocated), the `unused`
  state (newly-allocated, zero-spent items appearing at 0%), and the
  `tracked` state (a real usage-bar percentage, correctly computed from
  only this month's own allocation, not the item's lifetime balance)
- [X] T024 Run `dart format --output=none --set-exit-if-changed lib test`,
  `flutter analyze`, and the full `flutter test` suite; confirm `lib/`
  domain + data layer coverage has not dropped below 80% (Constitution
  Principle II)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately.
- **Foundational (Phase 2)**: Depends on Setup's T001 only for T004's
  same-file sequencing; T004b additionally depends on T002 and T004 within
  this same phase (it proves the phase's own `.autoDispose` decision, not
  a user-facing story) — BLOCKS all user stories.
- **User Stories (Phase 3+)**: All depend on Foundational (Phase 2)
  completion.
  - User Story 1 has no dependency on User Story 2 or 3.
  - User Story 2 builds its navigation controls onto User Story 1's
    already-rendered totals section (same file, sequenced after) but tests
    only navigation behavior, not totals correctness.
  - User Story 3 is independent of User Story 2 for every task except one:
    T015's month-navigation-updates-breakdown case needs T012's prev/next
    controls to already exist to drive it (the rest of US3 — T013, T014,
    T016, T017, T018, T019, T020, T021 — depends only on Foundational's
    `selectedReportMonthProvider` (T002) and screen shell (T003)). A second
    contributor can take the bulk of User Story 3 in parallel with User
    Story 2, but T015 itself must wait on T012, converging also where both
    stories touch `report_screen.dart`/`report_providers.dart`/the ARB
    files (noted per-task above).
- **Polish (Phase 6)**: Depends on all three user stories being complete.

### Within Each User Story

- Tests are written before their corresponding implementation tasks (TDD),
  per the Constitution's testing mandate.
- Pure application-layer logic (`report_summary.dart`,
  `expense_control_plan_service.dart`) before providers; providers before
  screen UI.
- Story complete and independently checkpointed before the next priority
  begins its UI-layer (same-file) tasks.

### Parallel Opportunities

- T002 and T003 (Foundational) — different files (T004b is not [P]: it
  depends on both T002 and T004).
- T005 and T006 (US1 tests) — different files.
- T013 and T014 (US3 tests) — different files; T015 is also a different
  file from both but is the one US3 task with a real cross-story
  dependency (needs T012), so treat it as the convergence point rather
  than a free-running parallel task.
- T016 and T018 (US3 impl) — different files, no dependency between them.
- Two contributors could take User Story 2 and the bulk of User Story 3
  (T013, T014, T016–T021 except T015) in parallel once Foundational is
  done; T015 specifically should be picked up only once T012 lands.

---

## Parallel Example: User Story 1

```powershell
# Launch both US1 tests together:
Task: "computeReportTotals unit tests in test/unit/features/expenses/application/report_summary_test.dart"
Task: "ReportScreen totals-section widget tests in test/widget/features/expenses/report_screen_test.dart"

# Then the one implementation task with no other-file dependency:
Task: "ReportTotals + computeReportTotals in lib/features/expenses/application/report_summary.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (nav icon).
2. Complete Phase 2: Foundational (route + shell + month state) — CRITICAL,
   blocks all stories.
3. Complete Phase 3: User Story 1 (totals).
4. **STOP and VALIDATE**: confirm totals for the current month render
   correctly, independent of navigation or breakdown.
5. Deploy/demo if ready.

### Incremental Delivery

1. Setup + Foundational → tab reachable, empty shell.
2. Add User Story 1 → totals visible → validate → demo (MVP).
3. Add User Story 2 → month browsing works → validate → demo.
4. Add User Story 3 → per-item breakdown complete → validate → demo.
5. Polish → integration coverage, full quickstart pass, format/analyze/
   coverage gate.

---

## Notes

- [P] tasks touch different files with no unmet dependency.
- [Story] label maps each task to its user story for traceability.
- No repository interface change and no persisted-schema change are needed
  anywhere in this task list (research.md Decision 1).
- Commit after each task or logical group; stop at any checkpoint to
  validate a story independently.
