# Tasks: Expense Transaction Recording

**Input**: Design documents from `specs/20260921-202232-expense-transaction/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/expense_transaction_ui_state.md, quickstart.md

**Tests**: Included — Constitution Principle II requires tests in the same PR as the behavior they cover, and this feature directly touches money-math correctness (balance mutation), which the Constitution calls non-negotiable.

**Organization**: Tasks are grouped by user story (US1 Record expense, US2 Live preview, US3 Scan-a-receipt tab) per spec.md's priorities, after a Setup and Foundational phase. FR-013 (income-allocation history) has no numbered user story in spec.md — it is cross-cutting infrastructure with no UI of its own, so its tasks live in the Foundational phase (Phase 2), independently testable on its own per quickstart.md's "Cross-cutting: income allocation now also produces history" section.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Maps the task to US1/US2/US3, or none for Setup/Foundational/Polish
- File paths are exact, per plan.md's Project Structure

---

## Phase 1: Setup

**Purpose**: No new dependencies are needed for this feature (drift, uuid, riverpod, lucide_icons are all already project dependencies) — this phase only confirms the project is ready for the schema change.

- [X] T001 Confirm `flutter pub get` and `dart run build_runner build --delete-conflicting-outputs` both run cleanly on the current `master`-based branch state before any schema changes are made (baseline sanity check — no new dependency to add)

**Checkpoint**: Clean baseline confirmed.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The `financial_transactions` table (Drift + Supabase), the migration that creates it, the promoted-public leaf-flattening helper, and the FR-013 income-history extension — everything every user story phase depends on, plus the one piece of this feature (FR-013) with no user story of its own. Must complete before US1/US2/US3.

**⚠️ CRITICAL**: No user story work can begin until T002–T005 are complete. T006/T007 (leaf-flattening) and T009 (FR-013's test) can proceed in parallel with US1 once their own prerequisites land. **T008 (FR-013's implementation) is the one exception**: although it touches a different repository method (`applyIncomeAllocation`, not `recordExpense`) than US1's own T013, T013 reuses the `_payloadOfTransaction` helper T008 introduces rather than duplicating it — so T008 MUST complete before T013 (US1) can start, even though both are grouped here primarily because FR-013 has no user story of its own.

- [X] T002 Define `TransactionDirection` enum (`income`, `expense`) and the `FinancialTransactions` Drift table in `lib/core/database/tables/financial_transactions_table.dart`: columns `id` (TextColumn, PK), `userId` (TextColumn), `expenseControlItemId` (TextColumn, no Drift-level FK per research.md Decision 2), `direction` (`textEnum<TransactionDirection>()`), `amount` (IntColumn), `occurredAt` (DateTimeColumn), `createdAt` (DateTimeColumn, `withDefault(currentDateAndTime)`) — mirror `expense_control_items_table.dart`'s exact column-declaration style (`@DataClassName`, `primaryKey` override). Add a `@TableIndex` on `(userId, occurredAt)` mirroring that table's own `_user_id_idx` pattern (research.md Decision 1)
- [X] T003 Bump `AppDatabase.schemaVersion` from `4` to `5` and add `if (from <= 4) { await m.createTable(financialTransactions); }` to `onUpgrade` in `lib/core/database/app_database.dart`, following the already-fixed cumulative-`<=` pattern (research.md Decision 7 — do NOT regress to `==`). Register `FinancialTransactions` in the `@DriftDatabase(tables: [...])` annotation (depends on T002)
- [X] T004 Run `dart run build_runner build --delete-conflicting-outputs` to regenerate `app_database.g.dart` reflecting the new table — this file is generated, do not hand-edit it (depends on T002, T003)
- [X] T005 [P] Add a new Supabase migration file under `supabase/migrations/` (e.g. `<timestamp>_financial_transactions.sql`, following `expense_control_items`' own migration as the model — research.md Decision 1/2): `create table financial_transactions` with snake_case columns matching T002, `user_id uuid not null references auth.users (id)`, `expense_control_item_id uuid not null references expense_control_items (id)` (a real Postgres FK, unlike the Drift side), `direction text not null check (direction in ('income', 'expense'))`, `amount integer not null check (amount > 0)` (research.md Decision 3), `occurred_at timestamptz not null`, `created_at timestamptz not null default now()`; `create index` on `user_id` and on `(user_id, occurred_at)`; `enable row level security` + one `for all using (auth.uid() = user_id) with check (auth.uid() = user_id)` policy — no table ships without RLS (Constitution: Security)
- [X] T006 [P] Promote `ExpenseControlPlanService._flattenLeaves` to a public method (rename to `flattenLeaves`, or add a thin public wrapper) in `lib/features/expense_control/domain/expense_control_plan_service.dart` so the "Chi tiêu" screen's presentation layer can call it for its leaf-item picker (research.md Decision 8, data-model.md's note) — verify `computeIncomeAllocation`'s existing internal call site still compiles unchanged
- [X] T007 [P] Unit test the renamed/wrapped public leaf-flattening method in `test/unit/features/expense_control/expense_control_plan_service_test.dart`: same assertions the existing private-method-via-`computeIncomeAllocation` tests already cover (leaf ordering, group-child interleaving), now calling the public entry point directly (depends on T006)
- [X] T008 [US-FR013] Extend `ExpenseControlRepositoryImpl.applyIncomeAllocation` in `lib/features/expense_control/data/expense_control_repository_impl.dart`: inside its EXISTING `_db.transaction()` (do not wrap in a second transaction), for each non-zero `(itemId, delta)` entry in `balanceDeltas`, insert one `FinancialTransactions` row (`direction: income`, `amount: delta`, `occurredAt`: a single `DateTime.now()` captured once before the loop and reused for every row in this call — research.md Decision 4) AND append one `sync_outbox` row for that new `financial_transactions` row (same `_appendOutbox` helper, `entityTable: 'financial_transactions'`). **Add a `_payloadOfTransaction(FinancialTransactionRow row)` (or equivalently named) helper alongside the existing `_payloadOf(item)`**, returning a snake_case `Map<String, dynamic>` matching T005's Postgres columns exactly (`id`, `user_id`, `expense_control_item_id`, `direction`, `amount`, `occurred_at`, `created_at`) — do NOT reuse the existing `expense_control_items`-shaped `_payloadOf` for this table's outbox rows, its shape does not match. The method's public signature (`Future<void> applyIncomeAllocation(Map<String, int> balanceDeltas)`) MUST NOT change (research.md Decision 6 — verified no caller, including `IncomeFormController.save()`, needs to change) (depends on T002–T005)
- [X] T009 [US-FR013] Unit test the extended `applyIncomeAllocation` in `test/unit/features/expense_control/expense_control_repository_impl_test.dart`: a call with N non-zero deltas produces exactly N new `financial_transactions` rows, each `direction: income`, each `amount` matching its delta, all sharing one identical `occurredAt`; a call with some zero-delta entries produces no rows for those entries; the atomicity guardrail — simulate a failure partway through (mirroring the existing concurrent-`applyIncomeAllocation` race test's structure) and assert NEITHER the balance change NOR the history row persists, never one without the other (FR-013, SC-004) (depends on T008)

**Checkpoint**: `financial_transactions` table exists and migrates cleanly; income allocations now also produce atomic history rows (FR-013 fully done and independently verified); the leaf-flattening helper is public and reusable. User story implementation can now begin.

---

## Phase 3: User Story 1 - Record an expense against a budget item (Priority: P1) 🎯 MVP

**Goal**: A working "Chi tiêu" screen (Nhập tay tab) that atomically decrements a picked leaf item's balance and records one expense transaction row, reachable from Thu chi instead of the placeholder.

**Independent Test**: Per spec.md — from Thu chi, tap "Chi tiêu", enter an amount, pick a budget item, tap "Lưu giao dịch", verify on Thu chi that the item's balance decreased by exactly that amount.

### Tests for User Story 1 ⚠️

> Write these tests FIRST; confirm they fail before implementation.

- [X] T010 [P] [US1] Unit test `ExpenseControlRepositoryImpl.recordExpense` in `test/unit/features/expense_control/expense_control_repository_impl_test.dart`: decrements the picked item's balance by exactly `amount`, leaves every other item's balance untouched; creates exactly one new `financial_transactions` row (`direction: expense`, matching `amount`, an `occurredAt` at call time); appends one `sync_outbox` row for the changed `expense_control_items` row AND one for the new `financial_transactions` row; ALLOWS the balance to go negative without throwing or blocking (FR-010); atomicity — mirroring `applyIncomeAllocation`'s own concurrent-write test pattern, prove the balance decrement and the history-row insert always land together, never one without the other (FR-009, SC-002)
- [X] T011 [P] [US1] Widget test in `test/widget/features/expenses/expense_screen_test.dart` (new file): entering an amount and picking a leaf item enables "Lưu giao dịch"; tapping it calls `recordExpense` with the entered amount and picked item id, then navigates back (pops); leaving the amount blank/zero blocks save with an inline message (FR-008 Scenario 3); a valid amount with no item picked blocks save with an inline message identifying the missing pick (FR-008 Scenario 4); only leaf items appear in the "Trừ vào khoản nào" list, group items never do (FR-011); a brand-new user with zero leaf items sees the `EmptyStateView` empty state instead of an empty scrollable list (Edge Cases). **Additionally covers 3 spec.md Edge Cases not otherwise tested**: (a) rapidly tapping "Lưu giao dịch" twice calls `recordExpense` at most once — the button is disabled once submitting starts (Edge Cases, double-tap); (b) entering digits via the keypad renders the amount display grouped/formatted (e.g. "50000" → "50.000" via `CurrencyFormatter`), not raw unformatted digits (Edge Cases, live formatting); (c) entering an amount and picking an item, then tapping back without saving, calls `recordExpense` zero times and leaves the picked item's balance unchanged (Edge Cases, navigate-away discards)

### Implementation for User Story 1

- [X] T012 [US1] Add `Future<void> recordExpense({required String itemId, required int amount})` to the `ExpenseControlRepository` interface in `lib/features/expense_control/domain/expense_control_repository.dart`, with a doc comment stating `amount` MUST be `> 0`, the balance is allowed to go negative and this method never blocks/throws for that reason (FR-010), per contracts/expense_transaction_ui_state.md's repository contract (depends on T002–T005)
- [X] T013 [US1] Implement `recordExpense` in `ExpenseControlRepositoryImpl` (`lib/features/expense_control/data/expense_control_repository_impl.dart`): one `_db.transaction()` containing (a) an atomic `customUpdate` decrementing the item's balance by `amount` (same `customUpdate`-not-`customStatement` requirement as `applyIncomeAllocation`, for Drift stream-invalidation — research.md Decision 5), (b) an insert into `FinancialTransactions` (`direction: expense`, the given `amount`, `occurredAt: DateTime.now()`), (c) one `_appendOutbox` call for the changed `expense_control_items` row, (d) one `_appendOutbox` call for the new `financial_transactions` row, using the SAME `_payloadOfTransaction` helper introduced in T008 (do not duplicate it) (depends on T012, T010, T008)
- [X] T014 [US1] Create `lib/features/expenses/presentation/expense_providers.dart`: a Riverpod state notifier for the "Chi tiêu" screen's manual-entry state (accumulated keypad amount, picked leaf item id, submitting flag, error state), mirroring `income_providers.dart`'s `IncomeFormController` shape; a save action that validates (FR-008), calls `recordExpense`, and exposes a `saved` flag the screen reacts to by popping (contracts/expense_transaction_ui_state.md's write side) (depends on T012)
- [X] T015 [US1] Create `lib/features/expenses/presentation/expense_screen.dart`: header (back button, danger-soft icon badge with `LucideIcons.arrowDownCircle`, "Chi tiêu" title, per `reference/chi-tieu-spec.md`), the segmented tab control (Nhập tay / Quét hoá đơn — US3 populates the second tab later; stub it as an empty container for now), the "Nhập tay" tab's large formatted amount display, the custom numeric keypad (12 keys: 0-9, decimal separator, backspace — `GridView` 3 columns per `reference/chi-tieu-spec.md`), the horizontally scrollable leaf-item picker (using T006's public `flattenLeaves`, filtering to leaves only per FR-011, showing name + parent group name), and the "Lưu giao dịch" button wired to T014's save action, disabled while submitting. Styling throughout (colors, spacing, icons, typography) MUST use the app's existing `AppColors`/`AppSemanticColors` design token system, not new/hard-coded values — matching the reference mockup's intent even where an exact token name differs (FR-015) (depends on T006, T011, T014)
- [X] T016 [US1] Update `SpendingScreen`'s "Chi tiêu" button in `lib/features/expenses/presentation/spending_screen.dart` to `Navigator.push` to `ExpenseScreen` instead of calling `_openPlaceholder(...)` (FR-001), following the exact same pattern already used by the "Thu nhập" button's `onPressed` (depends on T015)

**Checkpoint**: Expense recording is fully functional end-to-end, atomic, allows negative balances, and is independently testable/demoable — this alone is a shippable MVP increment.

---

## Phase 4: User Story 2 - Live preview of the resulting balance (Priority: P2)

**Goal**: The "Nhập tay" tab shows a live, color-coded preview of the picked item's balance after the pending transaction, updating immediately as the amount or picked item changes.

**Independent Test**: Per spec.md — on "Chi tiêu", change the amount or the picked item and confirm the preview banner's text and color update immediately, without needing to save first.

### Tests for User Story 2 ⚠️

> Write these tests FIRST; confirm they fail before implementation.

- [X] T017 [P] [US2] Extend `test/widget/features/expenses/expense_screen_test.dart`: with an item picked and a valid amount entered, the preview banner shows "Sau giao dịch này, "[tên khoản]" còn lại **[số tiền]**" using the item's current balance minus the amount; changing the amount or the picked item updates the banner immediately (no save needed); the banner uses neutral styling when the result is `>= 0` and danger styling when `< 0`; no banner is shown at all when the amount is blank/zero or no item is picked (FR-005–FR-007, US2 Scenarios 1–4)

### Implementation for User Story 2

- [X] T018 [US2] Add the derived preview banner to `lib/features/expenses/presentation/expense_screen.dart`'s "Nhập tay" tab: computed from `pickedItem.balance - amount` (screen-local/provider-derived state, no repository call — this is pure UI, contracts/expense_transaction_ui_state.md's read side), rendered only when both amount and picked item are present, styled via `AppSemanticColors`' existing neutral/danger tokens (no new color introduced — research.md Decision 11's dark-mode guidance applies here) (depends on T015, T017)

**Checkpoint**: Live preview is fully functional and independently testable/demoable alongside US1.

---

## Phase 5: User Story 3 - Scan-a-receipt tab (UI scaffold only) (Priority: P3)

**Goal**: The "Quét hoá đơn" tab renders the reference design's static camera-frame placeholder, "Chụp hoá đơn" button, and (after tapping it) a hard-coded mock "recognized" result with its own leaf-item picker — producing a real expense transaction on "Xác nhận & lưu", with no real camera/OCR logic anywhere.

**Independent Test**: Per spec.md — tap "Quét hoá đơn", confirm the camera-frame placeholder and button render; tap "Chụp hoá đơn", confirm the static mock card appears; pick an item and tap "Xác nhận & lưu", confirm a real expense transaction is created using the mock's hard-coded amount.

### Tests for User Story 3 ⚠️

> Write these tests FIRST; confirm they fail before implementation.

- [X] T019 [P] [US3] Extend `test/widget/features/expenses/expense_screen_test.dart`: tapping the "Quét hoá đơn" tab replaces the manual-entry content with the camera-frame placeholder and "Chụp hoá đơn" button (US3 Scenario 1); tapping "Chụp hoá đơn" shows the static mock "recognized" card with its own leaf-item picker, no real image capture occurs (US3 Scenario 2); picking an item and tapping "Xác nhận & lưu" calls `recordExpense` with the mock's hard-coded amount and the picked item id, producing the same save/navigate behavior as US1 — the mock's merchant text is never passed to `recordExpense` (US3 Scenario 3, Clarifications)

### Implementation for User Story 3

- [X] T020 [US3] Implement the "Quét hoá đơn" tab in `lib/features/expenses/presentation/expense_screen.dart`: the camera-frame placeholder (dashed border, `LucideIcons.camera`, per `reference/chi-tieu-spec.md`), the "Chụp hoá đơn" button (`LucideIcons.scanLine`) that reveals a static mock "Đã nhận diện" card (hard-coded amount, `LucideIcons.checkCircle2` badge, per the reference design — no real capture logic), a leaf-item picker reusing the same picker component/logic as the "Nhập tay" tab (T015, FR-012 — not a hard-coded target), and an "Xác nhận & lưu" button calling the same save action as T014's `recordExpense` path with the mock's hard-coded amount and the picker's picked item (depends on T013, T014, T015, T019)

**Checkpoint**: All three user stories are complete; the "Chi tiêu" screen fully matches the reference mockup's two-tab design.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Cross-story verification the individual story checkpoints don't cover on their own.

- [X] T021 [P] Integration test in `test/integration/schema_v4_to_v5_migration_test.dart`: seed a real v4 database (mirroring the existing `schema_v3_to_v4_migration_test.dart`'s structure and its v2→v4 cumulative-jump regression case), upgrade to v5, confirm `financial_transactions` is created cleanly with existing `expense_control_items` data untouched; include a direct v3→v5 (or lower) jump case proving the cumulative `<=` migration pattern still holds with this new step added (research.md Decision 7)
- [X] T022 Run `flutter analyze` and fix any issues; run `dart format` across all touched files (Constitution: Code Quality, Development Workflow)
- [X] T023 Run the full `flutter test` suite and confirm no regressions in previously-passing tests (especially `spending_screen_test.dart`'s existing "Chi tiêu" placeholder assertions, which must be updated to expect real navigation instead)
- [X] T024 Extend `test/widget/features/expenses/spending_screen_test.dart`: the "Chi tiêu" button now navigates to the real `ExpenseScreen`, not a placeholder — mirroring the existing test that already proves this for the "Thu nhập" button (FR-001)
- [X] T025 Walk through every scenario in `quickstart.md` on a real device/emulator, including the negative-balance scenario, the empty-leaf-items scenario, the "Quét hoá đơn" mock flow, and dark mode — confirm the preview banner's dark-mode danger styling uses the app's actual tokens, not the reference mockup's literal (light-looking) screenshot color (research.md Decision 11)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories. T002→T003→T004→T005 must be sequential (schema definition → version bump → codegen → Supabase mirror all touch the same conceptual schema change in order); T006/T007 (leaf-flattening) can run in parallel with T002–T005 (different files entirely); T008/T009 (FR-013) depend on T002–T005 (need the table to exist) but not on T006/T007. **T008 also gates US1's T013** (Phase 3), since T013 reuses T008's `_payloadOfTransaction` helper — T008 is not purely a Phase-2-internal, US1-independent task despite living in this phase (see Phase 3's own dependency note and Parallel Opportunities below).
- **User Story 1 (Phase 3)**: Depends on Foundational (T002–T006, AND T008 specifically for T013 — see above). No dependency on US2/US3.
- **User Story 2 (Phase 4)**: Depends on US1 (T015 — the preview banner is added to the same screen file US1 creates, and needs the picked-item/amount state US1's provider already holds). Not independently buildable before US1 exists, unlike a typical "no dependency on other stories" case — noted here as this feature's one instance of a story building directly on the previous story's own screen file, matching spec.md's own framing of US2 as "a refinement of US1's data."
- **User Story 3 (Phase 5)**: Depends on US1 (T013's `recordExpense`, T014's save action, T015's screen file and picker component) — FR-012 explicitly reuses "the same save behavior as FR-009" and "the same kind of picker used on the Nhập tay tab."
- **Polish (Phase 6)**: Depends on all three user stories being complete.

### Parallel Opportunities

- T002 and (once landed) T006/T007 can proceed in parallel — different files.
- T005 (Supabase migration) can be written in parallel with T003/T004 (Drift side) — different files, same logical schema, no code dependency between them.
- T009 (FR-013's test) can proceed in parallel with all of Phase 3 (US1) once T008 lands. T008 itself must land before T013, since T013 now reuses T008's `_payloadOfTransaction` helper rather than duplicating it (see T008/T013's remediated descriptions) — T008 is therefore no longer fully parallel with Phase 3, only with the parts of Phase 3 that don't touch `expense_control_repository_impl.dart` (T010's test can still be written in parallel; T013 cannot start until T008 is done).
- T010 and T011 (US1 tests) can run in parallel — different files.
- T021 (migration integration test) can run in parallel with any Polish-phase task — self-contained.

---

## Parallel Example: Foundational Phase

```bash
Task: "Define FinancialTransactions Drift table in lib/core/database/tables/financial_transactions_table.dart"
Task: "Promote ExpenseControlPlanService._flattenLeaves to public in lib/features/expense_control/domain/expense_control_plan_service.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 (Setup) + Phase 2 (Foundational — including FR-013's income-history extension, since it has no story of its own and is simplest to finish once).
2. Complete Phase 3 (US1 — record an expense, no preview banner yet).
3. **STOP and VALIDATE**: run quickstart.md's US1 section + the FR-013 cross-cutting section on-device.
4. This alone is a demoable increment: the app gains its first real expense-recording capability, and income allocations already produce matching history — both halves of spec.md's core motivation (a future Report feature having real data) are satisfied even before US2/US3 land.

### Incremental Delivery

1. Setup + Foundational (including FR-013) → foundation ready, income history already flowing.
2. US1 (Record expense) → validate independently → demoable MVP.
3. US2 (Live preview) → validate — builds directly on US1's screen file.
4. US3 (Scan-a-receipt scaffold) → validate — reuses US1's save path and picker.
5. Polish (Phase 6) → full regression pass + quickstart.md walkthrough, including dark mode.

---

## Notes

- [P] tasks touch different files with no completed-task dependency between them.
- [Story] labels map every user-story-phase task back to spec.md's US1/US2/US3 for traceability; `[US-FR013]` marks the one cross-cutting requirement with no numbered story of its own.
- T002→T003→T004→T005 is a strict sequence within Foundational — do not parallelize the Drift-side steps against each other, even though T005 (Supabase) can run alongside T003/T004.
- Commit after each task or logical group, per the Development Workflow section of the Constitution.
- Every write task in this feature (T008, T013) MUST keep the balance mutation and the history-row insert inside the SAME `_db.transaction()` — this is not a style preference, it is FR-009/FR-013's explicit atomicity requirement, and research.md Decision 6 documents exactly what a well-intentioned future refactor could break if this is missed.
