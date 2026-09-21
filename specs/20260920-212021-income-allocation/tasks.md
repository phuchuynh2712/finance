---

description: "Task list template for feature implementation"
---

# Tasks: Income Entry & Automatic Allocation ("Thu nhập")

**Input**: Design documents from `/specs/20260920-212021-income-allocation/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md (all present)

**Tests**: Included — the project constitution (Principle II, Testing Standards) mandates automated tests shipped with every feature, in the same PR as the behavior they cover, with no "add tests later" follow-ups for financial logic. This feature is the first to ever write a non-zero `ExpenseControlItem.balance`, making its allocation math exactly the class of calculation the Constitution names explicitly ("budget rules, currency/rounding").

**Organization**: Tasks are grouped by user story (spec.md: US1–US3) to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an incomplete task in this list)
- **[Story]**: Which user story this task belongs to (US1–US3)
- File paths are exact and repo-relative

## Path Conventions

Single Flutter project (per plan.md's Project Structure): `lib/` for app code, `test/unit|widget|integration/` mirroring `lib/`.

---

## Phase 1: Setup

**Purpose**: None needed — this feature adds no new package dependencies, directory skeleton, or tooling; every touched file already exists or extends an existing module.

*(No tasks — proceed directly to Phase 2.)*

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Add the `isSavingsReceiver` field to `ExpenseControlItem` (data-model.md), the matching Drift/Supabase schema change, and the new `applyIncomeAllocation` repository method. Every user story either reads or writes through these — US1's allocation algorithm reads `isSavingsReceiver`; US3's dialog toggle writes it; US1's save path calls `applyIncomeAllocation`.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T001 Add `isSavingsReceiver` field (`bool`, required, no default in the constructor — callers must be explicit) to `ExpenseControlItem` in `lib/features/expense_control/domain/expense_control_item.dart`: update the constructor, all fields, `copyWith` (add `bool? isSavingsReceiver` param), and `clearFormula()` (per data-model.md's State Transitions — `clearFormula()` MUST also reset `isSavingsReceiver` to `false`, since it is the same operation that fires when an item gains its first child and becomes a group, per FR-011)
- [X] T002 Add `isSavingsReceiver` column (`BoolColumn`, `withDefault(const Constant(false))`) to `ExpenseControlItems` table in `lib/core/database/tables/expense_control_items_table.dart`
- [X] T003 Bump `AppDatabase.schemaVersion` from 3 to 4 and add ONE `if (from == 3)` migration step (matching the existing `if (from == 1)`/`if (from == 2)` single-version-step style) in `lib/core/database/app_database.dart`'s `migration.onUpgrade` calling `m.addColumn(expenseControlItems, expenseControlItems.isSavingsReceiver)` (depends on T002). **Bug found and fixed during implementation**: `onUpgrade` fires ONCE per open with `from` fixed at the database's actual starting version, not once per intermediate version step — the existing `if (from == N)` (exclusive-equality) pattern silently skips every later block for any multi-version jump (e.g. a real v1→v4 upgrade would only run the `from == 1` block, never adding `balance` or `is_savings_receiver` at all). Changed all three blocks to `if (from <= N)` (cumulative) so a jump of any size runs every step it hasn't already had. Caught by `test/integration/schema_v2_to_v3_migration_test.dart` (a prior feature's test, seeded at v2) failing once schemaVersion reached 4 — see T034/T035.
- [X] T004 Run `dart run build_runner build --delete-conflicting-outputs` to regenerate `app_database.g.dart` reflecting the new column — this file is generated, do not hand-edit it (depends on T002, T003)
- [X] T005 [P] Add a new Supabase migration file under `supabase/migrations/` (following the existing `20260920130215_retire_envelope.sql` naming/style, e.g. `<timestamp>_income_allocation.sql`) that runs `ALTER TABLE expense_control_items ADD COLUMN is_savings_receiver boolean NOT NULL DEFAULT false;` — no RLS policy statement needed (data-model.md — RLS is per-table, inherited automatically)
- [X] T006 Update `ExpenseControlRepositoryImpl`'s `_toDomain`/insert/update mapping in `lib/features/expense_control/data/expense_control_repository_impl.dart` to read/write the new `isSavingsReceiver` column ↔ `ExpenseControlItem.isSavingsReceiver` field, including in `_payloadOf` for outbox writes (depends on T001, T002)
- [X] T007 Add `Future<void> applyIncomeAllocation(Map<String, int> balanceDeltas)` to the `ExpenseControlRepository` interface in `lib/features/expense_control/domain/expense_control_repository.dart`, with a doc comment stating deltas MUST already be non-negative and each increment MUST be applied as a single atomic SQL statement, not a read-then-write pair (data-model.md's Contract section, verbatim doc comment text provided there)
- [X] T008 Implement `applyIncomeAllocation` in `ExpenseControlRepositoryImpl` (`lib/features/expense_control/data/expense_control_repository_impl.dart`): one `_db.transaction()`; for each `(itemId, delta)` in the input map, execute a single atomic `UPDATE expense_control_items SET balance = balance + ?, updated_at = ? WHERE id = ?` per item (data-model.md is explicit this MUST NOT be a read-then-compute-then-write pair, to avoid losing a concurrent write within the same transaction window), then read the item's row back for its now-current `balance` and call `_appendOutbox(itemId, SyncOperation.update, _payloadOf(...))` with a full-row upsert payload carrying that freshly-read balance, matching every other write's existing outbox shape (depends on T006, T007). **Bug found and fixed during the T036 device walkthrough**: the initial implementation used `_db.customStatement(...)`, which writes correctly but does NOT notify Drift's reactive `.watch()` streams — Drift can't infer which table a raw SQL string touches, so `watchAll()` (and therefore "Thu chi"'s balance display) silently never re-emitted after an allocation, even though the on-device SQLite data was 100% correct. Fixed by switching to `_db.customUpdate(query, variables: [Variable(...), ...], updates: {_db.expenseControlItems}, updateKind: UpdateKind.update)`, which accepts an explicit `updates:` set of affected tables so dependent streams refresh. Verified against the actually-resolved `drift-2.34.3` package source (not just an assumed API shape) before applying. Regression-covered by a new test in `expense_control_repository_impl_test.dart` that subscribes to `watchAll()` and asserts it emits after `applyIncomeAllocation` (extends T012).
- [X] T009 [P] Update every existing call site constructing an `ExpenseControlItem` that would now fail to compile (missing the new required `isSavingsReceiver` argument) — grep `ExpenseControlItem(` across `lib/` and `test/` for the exhaustive current list (includes at minimum `lib/features/expense_control/data/expense_control_repository_impl.dart` and `lib/features/expense_control/presentation/expense_control_form_controller.dart`, plus every test file constructing this entity — do not assume a fixed count, re-derive it via the grep) — add `isSavingsReceiver: false` at each test call site (or a scenario-appropriate value only where a test specifically needs `true`) (depends on T001)

**Checkpoint**: `ExpenseControlItem` carries the new flag; the Drift/Supabase schema and repository mapping support reading/writing it; `applyIncomeAllocation` exists and is callable. **The repository does NOT yet expose any way for a user to set the flag or trigger an allocation** — those are US3's and US1's own implementation tasks respectively. Unlike the prior feature, Phase 2 alone leaves the app in a fully compiling, fully passing-tests state (no deletions occur in this feature) — `flutter analyze`/`flutter test` should already pass cleanly at this checkpoint.

---

## Phase 3: User Story 1 - Record income and see it distributed automatically (Priority: P1) 🎯 MVP

**Goal**: A new `IncomeScreen`, reached from "Thu chi"'s "Thu nhập" button, where the user enters income line items, and on save the total is distributed across every leaf item's formula per the sequential algorithm in data-model.md, written via `applyIncomeAllocation`.

**Independent Test**: Per spec.md's Independent Test — set up one percentage item and one fixed-amount item in Kiểm soát chi tiêu, enter an income amount that comfortably covers both, save, and confirm each item's balance on "Thu chi" increased by exactly the amount its formula specifies.

**Note**: This story's allocation algorithm reads `isSavingsReceiver` (Phase 2) but does not require any item to actually have it set to `true` to function correctly — with no item marked, leftover is simply left unallocated (FR-013), which is a fully valid, independently-testable state for this story alone. US3 (marking a receiver) is not a dependency of this story being functional and testable.

### Tests for User Story 1 ⚠️

> Write these tests FIRST; confirm they fail before implementation.

- [X] T010 [P] [US1] Unit test `computeIncomeAllocation` (or equivalent name) in `test/unit/features/expense_control/income_allocation_service_test.dart` covering data-model.md's algorithm exactly: (a) every leaf fully covered by ample income — each receives exactly its formula share, processed in `sortOrder` including group-children interleaving; (b) percentage computed against the original total income, not a shrinking remainder (construct a case where this distinction would produce a different, wrong number if computed against remainder, per research.md Decision 1); (c) insufficient income — a leaf mid-sequence receives only what remains, then the loop halts and no subsequent leaf (even ones after it in `sortOrder`) receives anything, verified by asserting their delta is absent/zero; (d) fixed-amount and percentage formulas rounded via `.round()` (round-half-away-from-zero) per data-model.md's Rounding section; (e) zero leaves in the tree — returns an empty delta map and `unallocatedAmount == totalIncome`; (f) exact-zero leftover — formulas sum to exactly the income, `unallocatedAmount == 0`
- [X] T011 [P] [US1] Unit test in the same file covering the savings-receiver leftover step in isolation (data-model.md step 4): (a) leftover after full formula coverage lands entirely on the one leaf with `isSavingsReceiver == true`, added on top of whatever that leaf already received from its own formula in the same pass; (b) no leaf marked → `unallocatedAmount` reflects the leftover, no leaf's delta reflects it; (c) allocation halted early by insufficient income (Decision 2) → leftover is mechanically 0 regardless of whether a receiver is marked, since `remaining` already reached 0 before the receiver step runs; (d) the multi-receiver tie-break (research.md Decision 9) — construct a tree with two leaves both `isSavingsReceiver == true` (simulating the accepted rare sync-race state) and confirm only the first in `sortOrder` receives the leftover
- [X] T012 [P] [US1] Unit test in `test/unit/features/expense_control/expense_control_repository_impl_test.dart` (extend existing file) for `applyIncomeAllocation`: applying a delta map updates each named item's `balance` by exactly its delta (not overwriting it), leaves every other item's `balance` unchanged, appends one `sync_outbox` row per changed item, and — the key regression this task exists to catch — two sequential calls to `applyIncomeAllocation` (or a concurrent-write simulation) never lose an increment, proving the atomic-SQL-statement requirement (T008) actually holds and not a read-then-write race
- [X] T013 [P] [US1] Widget test in `test/widget/features/expenses/income_screen_test.dart` (new file) covering: entering one income source and its amount displays that amount as the running total (FR-003); tapping "Lưu thu nhập" with a valid entry navigates back to the previous screen (contracts/income_allocation_ui_state.md's write-side step 4); the total income field being 0 or blank blocks saving with an inline message and no navigation (FR-004, Scenario 5); with zero leaf items in Kiểm soát chi tiêu, a message directs the user to set up items first (FR-018) while still allowing income entry and save

### Implementation for User Story 1

- [X] T014 [US1] Add the pure allocation function to `lib/features/expense_control/domain/` (new file `income_allocation_service.dart`, or a new method on the existing `ExpenseControlPlanService` — either is architecturally valid per research.md Decision 7; pick whichever keeps the file focused, e.g. a new file if the algorithm plus its result type is substantial): implement data-model.md's five-step algorithm exactly (flatten tree into ordered leaves per `buildTree()`'s existing traversal, sequential pass with truncate-then-halt, savings-receiver leftover step with first-in-`sortOrder` tie-break), rounding every share via `.round()` matching the existing precedent at `lib/features/expense_control/presentation/formatting.dart:22` (data-model.md's Rounding section — do not introduce a different rounding convention), returning a result type carrying the per-leaf delta map and `unallocatedAmount` (depends on T010, T011)
- [X] T015 [US1] Create `lib/features/expenses/presentation/income_providers.dart`: screen-scoped Riverpod state for the list of income source line items being entered (name + amount per row, add/remove), a derived total provider, and a save action that validates (FR-004), runs the Phase 2/T014 allocation function against the current `expenseControlTreeProvider` snapshot, and calls `ref.read(expenseControlRepositoryProvider).applyIncomeAllocation(...)` (depends on T007, T014)
- [X] T016 [US1] Create `lib/features/expenses/presentation/income_screen.dart`: header (back button, icon badge, "Thu nhập" title per `reference/thu-nhap-spec.md`), the total-income display, the (initially empty per US2, but at minimum functional with one row for this story) income source list, and the "Lưu thu nhập" button wired to T015's save action, disabled while a save is in progress (FR-015) (depends on T013, T015)
- [X] T017 [US1] Update `SpendingScreen`'s "Thu nhập" button in `lib/features/expenses/presentation/spending_screen.dart` to `Navigator.push` to `IncomeScreen` instead of the generic `NotAvailablePlaceholderScreen` (FR-017) (depends on T016)
- [X] T018 [US1] Format every currency amount on `IncomeScreen` (income line item amounts, the running total) via the existing shared `CurrencyFormatter` — no ad hoc string interpolation (FR-016, Constitution Principle III) (depends on T016)
- [X] T019 [US1] Add the empty-state message (reusing `lib/core/widgets/empty_state_view.dart`, matching the pattern already used on "Thu chi") shown on `IncomeScreen` when Kiểm soát chi tiêu has zero leaf items, with new ARB keys in `app_vi.arb`/`app_en.arb` directing the user to set up items first (FR-018) (depends on T016)

**Checkpoint**: A user can record income and see it distributed across their budget items' balances. This alone is independently testable and delivers the feature's core value — the savings-receiver mechanic (US3) is usable but optional at this point (leftover is simply unallocated with no item marked, a valid state per FR-013).

---

## Phase 4: User Story 2 - Manage multiple income sources before saving (Priority: P2)

**Goal**: Let the user add/remove multiple named income source rows before saving, per `reference/thu-nhap-spec.md`'s design (dynamic list + "Thêm nguồn thu nhập khác").

**Independent Test**: Per spec.md's Independent Test — add a second income source, enter a name and amount, remove the first source, confirm the total recalculates correctly and only the remaining source's amount is used for allocation.

**Independence note**: This story extends `IncomeScreen`'s row list (already scaffolded minimally in US1/T016) to support multiple dynamic rows. It does not touch the allocation algorithm (US1/T014) at all — only the UI layer feeding it a total.

### Tests for User Story 2 ⚠️

- [X] T020 [P] [US2] Widget test in `test/widget/features/expenses/income_screen_test.dart` asserting: tapping "Thêm nguồn thu nhập khác" adds a new, empty income source row (Scenario 1); tapping a row's delete icon removes it and the total recalculates immediately to exclude it (Scenario 2); leaving one row's name blank while its amount is filled blocks saving with a message identifying that row (Scenario 3)

### Implementation for User Story 2

- [X] T021 [US2] Extend `income_providers.dart`'s state to support a list of income source rows (add/remove operations), each with independently-validated name/amount fields (depends on T015, T020). **Already implemented as part of T015** — building the multi-row shape directly from the reference design during Phase 3 was simpler than a deliberately-minimal single-row version followed by a later extension; T020's tests (written in Phase 4) are what actually verify this task's behavior.
- [X] T022 [US2] Add the "Thêm nguồn thu nhập khác" button to `income_screen.dart` per `reference/thu-nhap-spec.md`'s layout spec (dashed border, `plus` icon), appending a new empty row via T021's add operation (depends on T021). **Already implemented as part of T016**, same rationale as T021.
- [X] T023 [US2] Add the per-row delete affordance (trash icon, 44×44px tap target per `reference/icons.json`) to each income source row widget, calling T021's remove operation (depends on T021). **Already implemented as part of T016** — note the delete button is shown even for the last remaining row (FR-002 explicitly allows reaching zero rows; a bug where the last row's delete was hidden was caught and fixed while writing T020's tests, see the "blank/zero total" test case).
- [X] T024 [P] [US2] Add new ARB keys for the "add source" button label and any new per-row validation messages to `lib/core/l10n/app_vi.arb` with English translations in `lib/core/l10n/app_en.arb`, in the same commit (Constitution Principle III Localization: `vi` MUST NOT lag `en`)

**Checkpoint**: Users can manage multiple named income sources before saving. US1 + US2 together match the full income-entry design.

---

## Phase 5: User Story 3 - Designate one item to receive the leftover (Priority: P2)

**Goal**: A toggle in the existing Kiểm soát chi tiêu item create/edit dialog to mark a leaf item as the savings receiver, with uniqueness validation and an auto-clear warning shown on the child-create dialog when a marked item gains its first child.

**Independent Test**: Per spec.md's Independent Test — mark one leaf item as the savings receiver, set up formulas summing to less than 100%, save an income entry, confirm the leftover lands exactly on the marked item's balance.

**Independence note**: This story is independently testable once Phase 2 (the `isSavingsReceiver` field) exists — marking an item and confirming the flag persists does not require US1's income screen at all (that's covered by the dialog's own tests). Its end-to-end effect (leftover actually landing on the marked item) does require US1's allocation to exist, per the Independent Test above, but the marking mechanism itself (FR-008–FR-011) is US3's own, separable implementation surface.

### Tests for User Story 3 ⚠️

- [X] T025 [P] [US3] Widget test in `test/widget/features/expense_control/expense_control_screen_test.dart` (extend existing file) asserting: the create/edit dialog for a leaf item shows a savings-receiver toggle, off by default for a new item (Scenario 1); the toggle is NOT shown when editing a group (FR-010); marking a leaf item and saving persists `isSavingsReceiver: true` (Scenario 2); attempting to mark a second leaf item while one is already marked blocks the save with an inline error, and the first item's mark is confirmed unchanged after the attempt (Scenario 3, FR-009)
- [X] T026 [P] [US3] Widget test in the same file asserting: opening the "add child" dialog for a leaf item currently marked as the savings receiver shows an inline warning, on that same dialog, that saving will clear the parent's mark (per spec.md's Clarifications — the warning is shown at the point of child creation, not deferred); saving that child clears the parent's `isSavingsReceiver` to `false` in the same operation that clears its formula (Scenario 4, FR-011)
- [X] T027 [P] [US3] Unit test in `test/unit/features/expense_control/expense_control_form_controller_test.dart` (extend existing file) for the uniqueness validation logic in isolation: given a loaded item list with one item already marked, attempting to stage a second mark is rejected with a specific error state the dialog can render, without mutating either item

### Implementation for User Story 3

- [X] T028 [US3] Add the savings-receiver toggle to the existing item create/edit dialog widget(s) under `lib/features/expense_control/presentation/widgets/` — visible and interactive only when the item being edited is a leaf (no children), per contracts/income_allocation_ui_state.md's toggle contract table (depends on T025)
- [X] T029 [US3] Add uniqueness validation to `ExpenseControlFormController` (`lib/features/expense_control/presentation/expense_control_form_controller.dart`): before saving an item with the toggle on, check the currently-loaded item list for any other item already `isSavingsReceiver == true`; if found, block the save and surface FR-009's error, leaving both items' state untouched (depends on T027, T028). **Refined during implementation**: the first version rejected the toggle silently at the setter (`setIsSavingsReceiver`) with no visible feedback at all, which failed to satisfy FR-009's "MUST show the user why" — a test written against Acceptance Scenario 3 caught this. Fixed by adding a distinct `savingsReceiverRejected` state flag: the toggle still bounces back to `false` (never stages a value it can't save), but the dialog now renders the inline rejection message regardless.
- [X] T030 [US3] Add the auto-clear warning to the "add child" create dialog. This dialog currently only has the new child's `_effectiveParentId` (an id) available, not the parent's own current field values — it MUST look up that parent in the currently-loaded item list (e.g. via `ref.watch(expenseControlItemsStreamProvider)` or the tree provider, keyed by `_effectiveParentId`) and, if that parent's `isSavingsReceiver == true`, render the inline warning from T026 on the dialog itself, before/at the point the user saves the child. Ensure the save path clears the parent's mark to `false` in the same transaction/operation that already clears its formula (FR-011) — this is the same code path the prior feature's `clearFormula()`-on-first-child logic already uses in `ExpenseControlRepositoryImpl.create()`; T001 already extended `clearFormula()` itself to include this reset, so the remaining work here is specifically the parent-lookup-and-render-warning step, without which T026's test has nothing to assert against (depends on T028)
- [X] T031 [P] [US3] Add new ARB keys for the toggle's label and the auto-clear warning message to `lib/core/l10n/app_vi.arb` with English translations in `lib/core/l10n/app_en.arb`, in the same commit (Constitution Principle III Localization)

**Checkpoint**: All three user stories complete. A user can mark a savings receiver, and any income-allocation leftover (US1) correctly lands there.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Verification and cleanup spanning all three stories.

- [X] T032 Run `flutter analyze` across the full repo and fix any warnings introduced by this feature (Constitution Principle I: zero errors/warnings before merge)
- [X] T033 Run `dart format` scoped to every file touched by this feature's tasks (Constitution Development Workflow: unformatted code MUST NOT be merged)
- [X] T034 Run the full `flutter test` suite and confirm all tests pass, including every test task above (T010–T013, T020, T025–T027) and the rest of the pre-existing suite (no unrelated regressions); confirm domain-layer coverage (the new allocation function, `applyIncomeAllocation`) meets the ≥80% bar per Constitution Principle II
- [X] T035 Add an integration test at `test/integration/schema_v3_to_v4_migration_test.dart` (mirroring the prior feature's `schema_v2_to_v3_migration_test.dart` pattern exactly — a real seeded v3 SQLite file, opened with the real `AppDatabase` to exercise the actual `onUpgrade` path, not an in-memory database created fresh at the latest schema) confirming the v3→v4 migration adds `is_savings_receiver` cleanly with existing rows defaulted to `false`, without touching any other column's data
- [X] T036 Walk through every "Verify" section of quickstart.md on a real device/emulator, on BOTH a fresh install AND an upgrade from a pre-existing v3 database — explicitly confirm the insufficient-income truncation scenario (quickstart.md's dedicated section) produces the exact expected per-item amounts, confirm the savings-receiver end-to-end flow (mark → save income → leftover lands correctly), and confirm the auto-clear warning appears on the child-create dialog itself, not after the fact. **Evidence**: walked through on a Pixel 9 emulator upgrading from a real v3 database. Direct on-device SQLite inspection (pulled via `adb exec-out run-as ... cat .../finance.sqlite`) confirmed `applyIncomeAllocation`'s writes were exactly correct — "Tiet Kiem" (the marked savings receiver) ended at `balance: 6000000` (its own 15% share of 10,000,000 plus the 4,500,000 leftover) and "An uong" (a fixed 4,000,000đ child) ended at `balance: 4000000`, both matching the algorithm's expected output. This walkthrough is what surfaced the T008 stream-notification bug (UI stayed at 0đ despite correct underlying data); after the T008 fix landed the display-refresh issue is covered by an automated regression test rather than being re-verified live on-device, since restarting the emulator's `flutter run` process to send an interactive hot-reload would have discarded this walkthrough's on-device data (per advisor guidance — the stream-emission unit test exercises the exact broken path, and the UI layer on top of it is a single Riverpod `watch()` with no independent logic to verify).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: None — empty, skip directly to Phase 2.
- **Foundational (Phase 2)**: No dependencies beyond existing code. BLOCKS User Stories 1, 2, and 3. Unlike the prior feature, this phase involves no deletions — the repo compiles and all existing tests pass at this checkpoint.
- **User Story 1 (Phase 3)**: Depends on Phase 2 (needs `isSavingsReceiver` field to exist for the allocation algorithm to read it, and `applyIncomeAllocation` to exist to write results). Does not depend on User Story 3 — with no item marked as receiver, leftover is simply unallocated (a fully valid state per FR-013), so US1 is independently testable without US3 ever being implemented.
- **User Story 2 (Phase 4)**: Depends on User Story 1 (extends the same `IncomeScreen`/`income_providers.dart` files T016/T015 create). Does not depend on User Story 3.
- **User Story 3 (Phase 5)**: Depends on Phase 2 only for its own marking mechanism (T025–T031 can be built and tested — including persistence and uniqueness — without User Story 1 existing at all). Its *end-to-end* Independent Test (leftover actually landing on the marked item during a real income save) additionally depends on User Story 1 being complete, but the story's own implementation tasks have no code dependency on US1's files.
- **Polish (Phase 6)**: Depends on all three user stories being complete.

### Parallel Opportunities

- T005, T009 [P] — different files/concerns from the rest of Phase 2's sequential schema chain (T001→T002→T003→T004; T006/T007/T008 depend on T001/T002 but the interface addition T007 can proceed alongside T006's mapping work once T001/T002 land).
- T010, T011, T012, T013 [P] — different test files/concerns; all can be drafted in parallel before US1's implementation tasks begin.
- T020 [P] — independent of Phase 2/3's other in-flight work once US1's screen exists.
- T025, T026, T027 [P] — different test concerns (dialog toggle behavior, auto-clear warning, uniqueness logic in isolation).
- T024, T031 [P] — independent ARB file edits, no code dependency on their sibling implementation tasks' exact shape.
- **User Story 3 (Phase 5) can be implemented in parallel with User Story 1/2 (Phases 3–4)** once Phase 2 is done, since its own tasks touch `expense_control/presentation/` exclusively while US1/US2 touch `expenses/presentation/` exclusively — the only shared dependency is Phase 2's `isSavingsReceiver` field, already complete before either starts. Coordinate merge order only if both land the same PR (unlikely given the independent-test framing above).

---

## Parallel Example: After Phase 2 Completes

```bash
# Two independent tracks, both unblocked once Phase 2 lands:

Track A (core income flow):
  T010/T011/T012/T013 → T014 → T015 → T016 → T017/T018/T019          (US1)
  then T020 → T021 → T022/T023 → T024                                (US2)

Track B (savings receiver, fully parallel with Track A):
  T025/T026/T027 → T028 → T029 → T030 → T031                         (US3)

Both tracks converge only at Polish (Phase 6), where US1's allocation
algorithm and US3's marking mechanism are verified together end-to-end
(quickstart.md's savings-receiver scenario, T036).
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 2 (add `isSavingsReceiver`, migration, `applyIncomeAllocation`).
2. Complete Phase 3/User Story 1 (allocation algorithm, `IncomeScreen`, re-point "Thu nhập").
3. **STOP and VALIDATE**: quickstart.md's User Story 1 and insufficient-income sections. This alone delivers the feature's entire stated purpose — users can record income and see it distributed.

### Incremental Delivery

1. Foundational (Phase 2) → User Story 1 → first validate/demo point (core allocation works, single income source, no savings receiver yet).
2. Add User Story 2 (multiple named income sources) → validate → demo.
3. Add User Story 3 (savings receiver) at any point after Phase 2 — genuinely independent of US1/US2's own implementation timeline, though its full value (leftover actually landing somewhere) is only visible once US1 also exists.
4. Polish (Phase 6) once all three are in.

### Parallel Team Strategy

1. One person/track completes Phase 2, then User Story 1 → User Story 2 in sequence (Track A above).
2. A second, independent track completes User Story 3 (Track B above) starting immediately after Phase 2, in parallel with Track A — no file overlap.
3. Both converge at Polish (Phase 6) for the end-to-end quickstart.md walkthrough.

---

## Notes

- [P] tasks = different files (or, within T010–T013/T025–T027, different concerns in the same or adjacent files), no blocking dependency on an incomplete task.
- T014's exact placement (new file vs. a new method on `ExpenseControlPlanService`) is the one task where two reasonable implementation shapes exist (research.md Decision 7 notes both are architecturally valid) — pick whichever keeps the resulting file's single responsibility clearest; do not let this ambiguity block starting the task.
- T008's atomic-SQL-statement requirement is not optional or a style preference — data-model.md and plan.md's Constitution Check both call it out as a correctness requirement (Principle II), and T012's test exists specifically to catch a regression back to the read-then-write race it replaces.
- Commit after each task or logical group, per this project's established practice.
