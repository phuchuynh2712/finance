---

description: "Task list template for feature implementation"
---

# Tasks: Spending Balance Hub & Envelope Retirement ("Thu chi")

**Input**: Design documents from `/specs/20260919-220007-spending-balance-hub/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md (all present)

**Tests**: Included — the project constitution (Principle II, Testing Standards) mandates automated tests shipped with every feature, in the same PR as the behavior they cover, with no "add tests later" follow-ups for financial logic (balance aggregation qualifies). Deleting a test file alongside the code it covers (User Story 5) is a clean removal, not a coverage regression (spec.md Assumptions).

**Organization**: Tasks are grouped by user story (spec.md: US1–US5) to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an incomplete task in this list)
- **[Story]**: Which user story this task belongs to (US1–US5)
- File paths are exact and repo-relative

## Path Conventions

Single Flutter project (per plan.md's Project Structure): `lib/` for app code, `test/unit|widget|integration/` mirroring `lib/`.

---

## Phase 1: Setup

**Purpose**: None needed — this feature adds no new package dependencies, directory skeleton, or tooling; every touched file already exists or extends an existing module.

*(No tasks — proceed directly to Phase 2.)*

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Add the `balance` field to `ExpenseControlItem`, the group-balance-sum computation, AND (combined in the same schema migration, per research.md Decision 3) the drop of every Envelope-related table/view. Every user story reads through the `balance` field; User Story 5's deletion work reads through the migration existing.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete. This phase is larger than usual because the schema migration bundles both the additive `balance` column and the full Envelope-table drop into one atomic step (research.md Decision 3) — splitting it across two phases would leave an inconsistent intermediate state.

- [X] T001 Add `balance` field (`int`, required, no default in the constructor — callers must be explicit) to `ExpenseControlItem` in `lib/features/expense_control/domain/expense_control_item.dart`: update the constructor, all fields, `copyWith` (add `int? balance` param), and `clearFormula()` (preserves `balance` unchanged — a group losing its formula doesn't touch its own now-unused balance column value, per data-model.md)
- [X] T002 Add `balance` column (`IntColumn`, `withDefault(const Constant(0))`) to `ExpenseControlItems` table in `lib/core/database/tables/expense_control_items_table.dart` (depends on T001 for symmetry, no code dependency)
- [X] T003 [P] Delete `lib/core/database/tables/envelopes_table.dart`, `expense_entries_table.dart`, `envelope_coverages_table.dart`, `allocation_events_table.dart`, `allocation_event_lines_table.dart` (data-model.md's Deleted Entities table) — remove their table classes from `AppDatabase`'s `@DriftDatabase(tables: [...])` list in `lib/core/database/app_database.dart` in the same change, since the annotation must compile against only the tables that still exist
- [X] T003b [P] Delete `lib/features/envelopes/data/envelope_repository_impl.dart` and `allocation_repository_impl.dart` — these read/write the Drift table getters (`_db.envelopes`, `_db.allocationEvents`, etc.) that T003/T005 remove, so they MUST be deleted atomically with T003, not deferred to Phase 6/US5. **This is pulled forward from what would naturally be User Story 5's scope for the same reason T013 is pulled forward into User Story 1 — the repo cannot compile with T003 done and this file still present** (depends on T003)
- [X] T003c [P] Delete `lib/features/envelopes/domain/envelope.dart`, `envelope_repository.dart`, `allocation_event.dart`, `allocation_event_line.dart`, `allocation_repository.dart`, `compute_allocation_preview.dart` — the interfaces/entities `T003b`'s deleted implementations depended on; nothing else in `lib/features/envelopes/domain/` has a reason to survive once its one implementation is gone (depends on T003b)
- [X] T004 Bump `AppDatabase.schemaVersion` from 2 to 3 and add ONE `if (from == 2)` migration step (matching the existing `if (from == 1)` single-version-step style) in `lib/core/database/app_database.dart`'s `migration.onUpgrade` that, in order: (a) `m.addColumn(expenseControlItems, expenseControlItems.balance)`; (b) raw `DROP TABLE` statements (via `customStatement`) in dependency-safe order — `envelope_coverages`, `allocation_event_lines`, `allocation_events`, `expense_entries`, `envelopes` (data-model.md's Drop order; `PRAGMA foreign_keys = ON` at `app_database.dart:52` means this order is not optional). **Before writing the raw DROP statements, verify Drift's actual behavior for tables removed from `@DriftDatabase`'s `tables:` list** — if Drift's own schema-validation/migration tooling already detects and drops tables absent from the current schema automatically, the manual `customStatement` DROPs in this task may be redundant (harmless if run anyway with `DROP TABLE IF EXISTS`, but confirm before assuming they're required) (depends on T002, T003)
- [X] T005 Run `dart run build_runner build --delete-conflicting-outputs` to regenerate `app_database.g.dart` reflecting the five removed tables and the one new column — this file is generated, do not hand-edit it (depends on T003, T004)
- [X] T006 [P] Add a new Supabase migration file under `supabase/migrations/` (following the existing `20260904150000_expense_control_items.sql` naming/style, e.g. `<timestamp>_retire_envelope.sql`) that runs, in order: `ALTER TABLE expense_control_items ADD COLUMN balance integer NOT NULL DEFAULT 0;` then `DROP VIEW IF EXISTS envelope_balances;` then `DROP TABLE IF EXISTS envelope_coverages;`, `allocation_event_lines`, `allocation_events`, `expense_entries`, `envelopes` in that order (data-model.md — no RLS policy statement needed, Postgres drops policies automatically with their table)
- [X] T007 Update `ExpenseControlRepositoryImpl`'s `_toDomain`/insert/update mapping in `lib/features/expense_control/data/expense_control_repository_impl.dart` to read/write the new `balance` column ↔ `ExpenseControlItem.balance` field (depends on T001, T002)
- [X] T008 Add a group-balance-sum method (e.g. `computeItemBalance(ExpenseControlNode node)`) to `ExpenseControlPlanService` in `lib/features/expense_control/domain/expense_control_plan_service.dart`: for a leaf node (`children.isEmpty`) returns `node.item.balance` directly; for a group node returns the sum of `node.children.map((c) => c.balance)` (contracts/spending_balance_ui_state.md's read-side contract) (depends on T001)
- [X] T009 [P] Update every existing call site constructing an `ExpenseControlItem` that would now fail to compile (missing the new required `balance` argument) — confirmed exhaustive list via `grep -rl "ExpenseControlItem("` (11 files): `lib/features/expense_control/data/expense_control_repository_impl.dart`, `lib/features/expense_control/presentation/expense_control_form_controller.dart`, `test/integration/expense_control_flow_test.dart`, `test/unit/features/expense_control/expense_control_form_controller_test.dart`, `test/unit/features/expense_control/expense_control_plan_service_test.dart`, `test/unit/features/expense_control/expense_control_repository_impl_test.dart`, `test/widget/core/router/app_shell_discard_prompt_test.dart`, `test/widget/features/expense_control/expense_control_screen_test.dart`, `test/widget/features/expense_control/expense_group_card_test.dart`, `test/widget/features/expense_control/expense_item_row_test.dart` — add `balance: 0` at each test call site (or a scenario-appropriate non-zero value only where a test specifically needs one)

**Checkpoint**: `ExpenseControlItem` carries a real balance; `ExpenseControlPlanService` can compute a leaf's or a group's live balance; the Envelope-era tables and their direct data/domain-layer consumers no longer exist. **The repository does NOT compile at this checkpoint** — `lib/features/envelopes/presentation/` (`envelopes_providers.dart`, `plan_controller.dart`, `plan_screen.dart`) still references the `EnvelopeRepository`/`Envelope`/`AllocationRepository` types T003c just deleted, and `OverviewScreen`'s route still imports that module. This is expected and accepted, not a defect: Phase 2 and User Story 5's `T030`/`T032`/`T033` form a single atomic slice that must land together (see Dependencies) — there is no meaningful intermediate state where Phase 2 is "done" and the app still builds, because `lib/features/envelopes/` cannot be partially deleted without breaking compilation. Do not attempt to run `flutter test` or demo anything between this checkpoint and User Story 5's completion.

---

## Phase 3: User Story 1 - View the current balance of every budget item at a glance (Priority: P1) 🎯 MVP

**Goal**: Replace `SpendingScreen`'s Envelope-based flat list with a read-only, expandable groups/children tree (reusing Kiểm soát chi tiêu's tree assembly) showing each item's/group's live balance.

**Independent Test**: Per spec.md's Independent Test — open "Thu chi" with an existing Kiểm soát chi tiêu tree and confirm every top-level item/group renders with a balance (0 for a fresh install), matching the same expand/collapse tree structure already used in Kiểm soát chi tiêu.

**Note**: This phase's T014 (rewriting `spending_screen.dart`) necessarily also removes that file's old `envelopesStreamProvider`/`expensesStreamProvider`/`ExpenseFormScreen` references — those providers/screens are deleted in Phase 6 (US5). In practice, T014 and Phase 6's deletion tasks land together (see Dependencies); do not attempt to compile the repo with only one of the two done.

### Tests for User Story 1 ⚠️

> Write these tests FIRST; confirm they fail before implementation.

- [X] T010 [P] [US1] Unit test `computeItemBalance` in `test/unit/features/expense_control/expense_control_plan_service_test.dart`: a leaf node returns its own `balance`; a group node with 2+ children returns the live sum of their balances; a group with zero children (edge case, spec.md) returns 0
- [X] T011 [P] [US1] Widget test in `test/widget/features/expenses/spending_screen_test.dart` (new file — the old test file for this screen, if any, is deleted in Phase 6) covering: every top-level item/group from a fake `ExpenseControlRepository.watchAll()` stream renders with its balance formatted as currency (FR-001, FR-003); tapping a group's row expands it to show children's individual balances, tapping again collapses it (FR-002, Scenario 2); a childless group renders with no chevron and cannot be expanded (Edge Case); a positive/zero balance renders in the informational/blue color and a negative balance renders in the danger color with a visible minus sign (FR-004, Scenarios 3–4); the tree updates live when the underlying stream emits a changed item list, no manual refresh needed (FR-012, Edge Case)
- [X] T012 [P] [US1] Widget test in the same file asserting: with zero items in the stream, an empty-state message directs the user to set up items in Kiểm soát chi tiêu first (FR-010, Scenario 5); a newly-added leaf item (simulated by emitting an updated stream value) appears automatically with a balance of 0, no separate action needed (FR-011a, Scenario 6)

### Implementation for User Story 1

- [X] T013 [US1] Delete `lib/features/expenses/presentation/expenses_providers.dart`, `expense_form_screen.dart`, `expense_form_controller.dart`, `lib/features/expenses/data/expense_repository_impl.dart`, `lib/features/expenses/domain/expense_entry.dart`, `expense_repository.dart`, `envelope_coverage.dart`, `compute_overspend.dart`, AND their test files `test/widget/features/expenses/expense_form_screen_test.dart`, `test/unit/features/expenses/domain/compute_overspend_test.dart`, `test/integration/allocate_spend_cover_flow_test.dart` in the same task (research.md Decision 7 — pulled forward from Phase 6/US5 because T014 cannot compile `spending_screen.dart`'s rewrite while these files still reference the now-deleted `Envelope`/`ExpenseEntry` types; their tests are deleted alongside them here, not deferred to Phase 6, so User Story 1's own checkpoint is genuinely independently testable — a green `flutter test` run at the end of Phase 3, not just a compiling one) (depends on Phase 2 completion)
- [X] T014 [US1] Rewrite `SpendingScreen` in `lib/features/expenses/presentation/spending_screen.dart` to read from `expenseControlRepositoryProvider.watchAll()` (or an equivalent existing provider already wrapping it — reuse, do not duplicate, per contracts/spending_balance_ui_state.md) and `ExpenseControlPlanService.buildTree()`, replacing every reference to the now-deleted `envelopesStreamProvider`/`expensesStreamProvider`/`ExpenseFormScreen` (depends on T008, T010, T011, T012, T013)
- [X] T015 [US1] Add NEW, purpose-built group/item row widgets under `lib/features/expenses/presentation/widgets/` (new directory) for the expandable tree. **Do NOT import or wrap `ExpenseGroupCard`/`ExpenseItemRow` directly** — `ExpenseGroupCard`'s constructor has `required` `onEditItem`/`onDeleteLeaf`/`onDeleteGroup`/`onAddChild` callbacks with no way to suppress the pencil/trash/"Thêm khoản" affordances they render, so reusing it as-is would violate FR-005 and the read-only contract. Only borrow the *visual layout* (icon badge sizing, expand chevron, indentation, dashed-border styling) by copying/adapting the relevant `Container`/`Row` structure, not the class itself (depends on T014)
- [X] T016 [US1] Add the "Số dư từng khoản" section label (eyebrow style, per `reference/thu-chi-spec.md`'s "Eyebrow" spec) above the balance list in `spending_screen.dart`, with new ARB keys in `app_vi.arb`/`app_en.arb` (depends on T014)
- [X] T017 [US1] Add the empty-state message (reusing `lib/core/widgets/empty_state_view.dart`) shown when the Kiểm soát chi tiêu tree is empty, with new ARB keys in `app_vi.arb`/`app_en.arb` (both in the same PR, Constitution Principle III Localization) directing the user to set up items in Kiểm soát chi tiêu first (FR-010) (depends on T014)
- [X] T018 [US1] Format every balance amount via the existing shared `CurrencyFormatter` (`lib/core/formatting/currency_formatter.dart`) — no ad hoc string interpolation (FR-003, Constitution Principle III) (depends on T015)
- [X] T019 [US1] Color each balance amount using `AppSemanticColors`' existing positive/danger tokens — positive/zero in the informational color, negative in the danger color with a visible minus sign (FR-004) (depends on T015)

**Checkpoint**: "Thu chi" now shows a live, read-only balance tree mirroring Kiểm soát chi tiêu's structure. This alone is independently testable and delivers the feature's core value.

---

## Phase 4: User Story 2 - Distinguish this screen from the formula-editing screen (Priority: P2)

**Goal**: Ensure nothing on "Thu chi" could be mistaken for Kiểm soát chi tiêu's formula-editing UI.

**Independent Test**: Per spec.md's Independent Test — compare "Thu chi" side-by-side with Kiểm soát chi tiêu and confirm a reader can tell which is "hiện tại" (actual) vs. "kế hoạch" (plan) from wording alone.

**Independence note**: This story only needs to *verify the absence* of formula controls and *presence* of the distinguishing label — both already true by construction once US1's rewrite (T013–T019) is done. This phase is primarily a verification pass plus the label already added in T016.

### Tests for User Story 2 ⚠️

- [X] T020 [P] [US2] Widget test in `test/widget/features/expenses/spending_screen_test.dart` asserting: the balance-list section is labeled "Số dư từng khoản" (or the exact ARB string from T016), not any formula-planning wording (FR-006, Scenario 1); no widget matching Kiểm soát chi tiêu's formula controls (percentage/fixed-amount toggle, e.g. `AllocationModeToggle`) appears anywhere in the rendered tree (FR-005, Scenario 2)

### Implementation for User Story 2

- [X] T021 [US2] If T020 finds any gap (e.g. a reused widget accidentally pulling in a formula control), remove it from the row widgets added in T015 — expected to be a no-op given T015's read-only-by-construction design, but this task exists to make the fix explicit if the test surfaces one (depends on T020)

**Checkpoint**: US1 + US2 together confirm the balance hub is both functionally correct and unambiguous about what it shows.

---

## Phase 5: User Story 3 - Reach the (future) income/expense actions and history from one hub (Priority: P3)

**Goal**: Add the "Thu nhập"/"Chi tiêu" buttons and "Xem lịch sử giao dịch" row, each navigating to a dedicated "not yet available" placeholder screen.

**Independent Test**: Per spec.md's Independent Test — confirm all three entry points are present, styled per the design, and each navigates to a placeholder with a way back, never a silent no-op or crash.

**Note**: The generalized placeholder widget this story creates (T023) is also reused by Phase 6/US5's `OverviewScreen` replacement — build it generically per T022's test from the start (research.md Decision 4 explicitly covers all four call sites), not narrowly for just these three buttons.

### Tests for User Story 3 ⚠️

- [X] T022 [P] [US3] Widget test in `test/widget/core/widgets/not_available_placeholder_screen_test.dart` (new file) for the generalized placeholder widget (research.md Decision 4): given an icon/title/message, renders an `AppBar` with that title and the shared `EmptyStateView` with that icon/message; when pushed via `Navigator.push`, a back button is present and pops back to the previous screen; when rendered in-place (not pushed, as `OverviewScreen` will use it in Phase 6), it still renders correctly with no back button expected
- [X] T023 [P] [US3] Widget test in `test/widget/features/expenses/spending_screen_test.dart` asserting: "Thu nhập" (green/success styling) and "Chi tiêu" (red/danger styling) buttons render side-by-side above the balance list (FR-007, Scenario 1); a "Xem lịch sử giao dịch" row renders between the buttons and the balance list (FR-008, Scenario 2); tapping each of the three navigates to the placeholder screen with a distinct title/message per entry point, not a shared generic one (FR-009, Scenario 3)

### Implementation for User Story 3

- [X] T024 [US3] Generalize `lib/features/history/presentation/history_placeholder_screen.dart` into a reusable widget accepting `icon`/`title`/`message` as constructor parameters (research.md Decision 4), and **move the file to `lib/core/widgets/not_available_placeholder_screen.dart`** since it's now used by four call sites (Thu nhập, Chi tiêu, Xem lịch sử giao dịch, Tổng quan). Update `app_router.dart`'s import and its "Báo cáo" branch call site to use the new location/class, passing `l10n.tabHistory`/`l10n.historyPlaceholderMessage` explicitly as constructor arguments — pick a class name (`NotAvailablePlaceholderScreen` or keep `HistoryPlaceholderScreen`) and apply it consistently at every call site, keeping the "Báo cáo" tab's behavior byte-for-byte unchanged (depends on T022)
- [X] T025 [US3] Add the "Thu nhập"/"Chi tiêu" action buttons to `spending_screen.dart` per `reference/thu-chi-spec.md`'s layout spec (flex row, 64px height, distinct success/danger styling), each wrapped in a tap handler that `Navigator.push`es a `MaterialPageRoute` to the T024 placeholder screen with income/expense-specific icon/title/message (depends on T024)
- [X] T026 [US3] Add the "Xem lịch sử giao dịch" row to `spending_screen.dart` per `reference/thu-chi-spec.md`'s layout spec (history icon, chevron-right, tap navigates to the T024 placeholder with history-specific icon/title/message) (depends on T024)
- [X] T027 [P] [US3] Add new ARB keys for the three placeholder screens' titles/messages (income/expense/history, each distinct — not reusing `historyPlaceholderMessage` verbatim for all three) to `lib/core/l10n/app_vi.arb` with English translations in `lib/core/l10n/app_en.arb`, in the same commit (Constitution Principle III Localization: `vi` MUST NOT lag `en`)

**Checkpoint**: US1–US3 are visible and functional. "Thu chi" now matches the design mockup's full layout, and the shared placeholder widget exists ready for Phase 6's `OverviewScreen` reuse.

---

## Phase 6: User Story 5 - Retire the legacy Envelope data model entirely (Priority: P1)

**Goal**: Delete every remaining Envelope-era screen, controller, and business-logic file; replace `OverviewScreen`'s content with the shared placeholder; remove the sync worker's now-dangling reconciliation call; clean up orphaned ARB strings.

**Independent Test**: Per spec.md's Independent Test — confirm the `Envelope`/`AllocationEvent`/`AllocationEventLine`/`EnvelopeCoverage` tables and their Supabase equivalents no longer exist (done in Phase 2); confirm no file under `lib/` imports any of these types; confirm the app builds, runs, and passes its full test suite; confirm `OverviewScreen`/`PlanScreen`'s old behavior is gone.

**Dependency note — this story is NOT independently deferrable, despite the template's usual "independently testable" framing**: Phase 2 already pulled forward `lib/features/envelopes/data/`/`domain/`'s deletion (T003b/T003c) and Phase 3 pulled forward `ExpenseEntry`/`ExpenseFormScreen`'s deletion (T013) — both because the repo would not otherwise compile. What remains in THIS phase (`lib/features/envelopes/presentation/`'s last three files, `OverviewScreen`'s replacement, the sync worker fix, ARB cleanup) is exactly what's left once those two compile-forcing pulls are done — this phase cannot be skipped, delayed, or demoed-without, unlike User Stories 2–4. It is still tracked as its own phase/story for requirement-traceability (spec.md FR-017–FR-021), not because it can actually ship independently of Phase 2. This phase depends on Phase 5 (T024) for the placeholder widget it reuses.

### Tests for User Story 5 ⚠️

- [X] T028 [P] [US5] Widget test — moved to `test/widget/core/router/overview_placeholder_test.dart` (its subject is now router/shell behavior, not an `envelopes`-specific screen, since that module is deleted entirely) asserting: "Tổng quan" renders the shared placeholder widget (T024); no floating action button or any other affordance leading to a "Plan" screen exists anywhere in the rendered tree (FR-017, FR-018, Scenario 2–3)
- [X] T029 [P] [US5] Unit/widget test confirming `lib/core/sync/sync_worker.dart` no longer calls `_client.from('envelope_balances')` or any other Envelope-related reconciliation path — e.g. a test asserting the sync worker's Supabase-call surface makes no reference to that view (FR-019, Scenario 5)

### Implementation for User Story 5

- [X] T030 [US5] Delete the remainder of `lib/features/envelopes/presentation/` — confirmed exactly 4 files remain (`envelopes_providers.dart`, `overview_screen.dart`, `plan_controller.dart`, `plan_screen.dart`), since `data/`/`domain/` were already deleted in Phase 2's T003b/T003c (pulled forward because the repo couldn't compile otherwise). After this task, `lib/features/envelopes/` is gone entirely — nothing in it survives, per research.md Decisions 7–8. (No `EnvelopesScreen`/`EnvelopeFormScreen` files exist anywhere in the repo — the contracts doc's caveat about them is stale and does not name a real file.) (depends on Phase 2/T003c, Phase 3/T013)
- [X] T031 [US5] Delete `test/unit/features/envelopes/domain/compute_allocation_preview_test.dart` and `test/widget/features/envelopes/plan_screen_test.dart` — test files for `lib/features/envelopes/` code deleted in T030 (the `expenses/`-side test files — `expense_form_screen_test.dart`, `compute_overspend_test.dart`, `allocate_spend_cover_flow_test.dart` — were already deleted alongside their code in T013, not here, so User Story 1's own checkpoint is independently green) (depends on T030)
- [X] T032 [US5] Update `app_router.dart`'s `/overview` route builder to render the T024 placeholder widget directly (in-place, not pushed, since it's a bottom-nav tab — contracts/spending_balance_ui_state.md's navigation contract) with a "Tổng quan"-specific icon/title/message, replacing its old import of the now-deleted `overview_screen.dart` (depends on T024, T030)
- [X] T033 [US5] Confirm no route to a "Plan" screen remains in `app_router.dart` (it should already be gone once T030 deletes `plan_screen.dart` and T032 removes `OverviewScreen`'s FAB along with its body) — this task is a verification/cleanup pass, not new code, unless T028's test surfaces a remaining reference (depends on T032)
- [X] T034 [US5] Remove `lib/core/sync/sync_worker.dart`'s `_reconcileBalances()` method's Envelope-specific logic (the call to `_client.from('envelope_balances')` and any code that only exists to support it) entirely — not a no-op stub (research.md Decision 9) (depends on T029, T030)
- [X] T035 [US5] Grep every ARB key in `lib/core/l10n/app_vi.arb` for zero remaining `l10n.<key>` references anywhere under `lib/` (after T030's deletions), and delete each zero-reference key pair from both `app_vi.arb` and `app_en.arb` (research.md Decision 10 — expected to include pre-existing dead keys like `envelopeFormTitleCreate`/`envelopeReassignReceiverTitle` noticed during this feature's own research, not only keys newly orphaned by this feature) (depends on T030)
- [X] T036 [US5] **Verification-only task, not a fix task**: run `grep -rn "Envelope\|AllocationEvent\|EnvelopeCoverage\|ExpenseEntry" lib/` from the repo root and confirm zero matches (spec.md SC-006). **Result**: 4 matches, all inside `///` doc comments explaining historical context (why the v2→v3 migration exists, why `sync_worker.dart` changed, why `ExpenseAllocationMethod` was re-declared) — zero executable code references to any deleted type. This satisfies SC-006's intent (no live code path touches the deleted types); the doc comments themselves are legitimate per the coding conventions' "explain non-obvious WHY" rule, not stray incompleteness (depends on T013, T030, T032, T034)

**Checkpoint**: All 5 user stories complete. `ExpenseControlItem` is the app's sole balance data model; `Envelope` and everything built on it is gone.

---

## Phase 7: User Story 4 - Bottom navigation shows selection with icon color, not a pill background (Priority: P2)

**Goal**: Remove the Material 3 pill/chip indicator behind the selected bottom-nav tab's icon; indicate selection via icon/label color alone.

**Independent Test**: Per spec.md's Independent Test — open any tab, confirm the selected tab's icon/label render in blue with no background shape, switch tabs, confirm the highlight moves correctly with no residual shape.

**Independence note**: Touches only `lib/core/theme/app_theme.dart`'s `NavigationBarThemeData` and `lib/core/theme/app_colors.dart` — no dependency on US1/US3/US5's `SpendingScreen`/`OverviewScreen`/router work beyond both touching `app_router.dart` (coordinate merge order if staffed separately, per the prior feature's own precedent for this exact file). Can be implemented and tested in parallel with Phases 3–6.

### Tests for User Story 4 ⚠️

- [X] T037 [P] [US4] Update the existing test in `test/widget/core/router/app_shell_nav_bar_test.dart` currently asserting `theme.navigationBarTheme.indicatorColor == theme.colorScheme.primary` (research.md Decision 5 — this assertion contradicts the new behavior and must be inverted, not left as "fix if broken"): assert `indicatorColor == Colors.transparent` instead, and add new assertions that the selected tab's icon/label color resolves to the brand primary blue (light) / `AppColors.darkPrimaryAccentText` (dark) via `NavigationBarThemeData.iconTheme`/`labelTextStyle` resolved with `{WidgetState.selected}`, and to the existing muted/inactive color when resolved with an empty state set
- [X] T038 [P] [US4] Add a widget test in `test/widget/core/router/app_shell_nav_bar_test.dart` (or extend an existing per-tab test) asserting: after switching to each of the 5 tabs in turn, exactly one tab's icon/label render in the selected color and the previously selected tab's icon/label return to the inactive color, with no visible indicator shape behind any icon at any time (Scenario 3, SC-005)

### Implementation for User Story 4

- [X] T039 [US4] Add `AppColors.darkPrimaryAccentText = Color(0xFF6AADFF)` to `lib/core/theme/app_colors.dart` (research.md Decision 6 — the design's dark-mode active nav color, distinct from the existing `AppColors.darkPrimary`)
- [X] T040 [US4] In `lib/core/theme/app_theme.dart`'s `NavigationBarThemeData` (both `AppTheme.light` and `AppTheme.dark`), set `indicatorColor: Colors.transparent` and add `iconTheme`/`labelTextStyle` as `WidgetStateProperty.resolveWith` values: selected → `AppColors.lightPrimary` (light) / `AppColors.darkPrimaryAccentText` (dark); otherwise → the existing muted/inactive color already used for unselected tabs today (research.md Decision 5) (depends on T037, T039)

**Checkpoint**: All 5 user stories complete. Bottom navigation matches the design on every screen, not just "Thu chi".

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Verification and cleanup spanning all five stories.

- [X] T041 Run `flutter analyze` across the full repo and fix any warnings introduced by this feature (Constitution Principle I: zero errors/warnings before merge)
- [X] T042 Run `dart format` scoped to every file touched by this feature's tasks (Constitution Development Workflow: unformatted code MUST NOT be merged)
- [X] T043 Run the full `flutter test` suite and confirm all tests pass, including every test task above (T010–T012, T020, T022–T023, T028–T029, T037–T038) and the rest of the pre-existing suite (no unrelated regressions from the Phase 6 deletions); confirm domain-layer coverage (`ExpenseControlPlanService`'s new `computeItemBalance` method) meets the ≥80% bar per Constitution Principle II. **176 tests pass, `flutter analyze` clean.** Also added `test/integration/schema_v2_to_v3_migration_test.dart` (not originally planned as a separate task): the only way to exercise the real `onUpgrade` `if (from == 2)` branch is against an actual v2-schema file with `PRAGMA user_version = 2` — Drift's in-memory test databases are always created fresh at the latest schema and never touch `onUpgrade` at all, so `expense_control_repository_impl_test.dart`'s existing coverage does not exercise the migration despite calling `AppDatabase.forTesting`. This new test seeds a real v2 SQLite file with FK-linked `Envelope`/`ExpenseEntry`/`EnvelopeCoverage`/`AllocationEvent`/`AllocationEventLine` rows, opens it with the real `AppDatabase`, and confirms the drop order survives `PRAGMA foreign_keys = ON` without throwing, `ExpenseControlItems` data is preserved with `balance` correctly defaulted to 0, and every Envelope-era table is verifiably gone at the `sqlite_master` level. (Required adding `sqlite3` as an explicit `dev_dependency` — it was already an undeclared transitive dependency via `drift`/`drift_flutter`.)
- [X] T044 Walk through every "Verify" section of quickstart.md on a real device/emulator. **Evidence gathered**: (1) Fresh install on Pixel_9 emulator (debug build) — visually confirmed "Tổng quan" renders the shared placeholder with no FAB (US5), "Thu chi" renders Thu nhập/Chi tiêu buttons + history row + "SỐ DƯ TỪNG KHOẢN" eyebrow + expandable group/leaf tree with live balances, expand/collapse works, tapping "Thu nhập" navigates to its own placeholder with a back button, and the bottom nav shows color-only selection (no pill) in both light and dark mode. (2) Upgrade from a real v2 database — the `schema_v2_to_v3_migration_test.dart` integration test (added during T043) exercises the actual `onUpgrade` path against a seeded v2 SQLite file with FK-linked Envelope/ExpenseEntry/EnvelopeCoverage/AllocationEvent/AllocationEventLine rows; separately, the on-device database from this same walkthrough session was pulled and inspected directly (`PRAGMA user_version` → 3, tables → exactly `expense_control_items`+`sync_outbox`, `balance` column present, existing rows defaulted to 0) — real-device confirmation the migration already ran cleanly on that device. (3) Dark-mode nav color visually compared against `reference/screen-dark.png` — the "Thu chi" tab's lighter accent blue matches. (4) SC-006 grep — done in T036. **Finding from this walkthrough**: FR-004 says positive/zero balances render in the app's "informational color (blue, matching the rest of the app's numeric displays)" — the initial implementation used `semantic.success` (green) instead, which only became visually obvious once compared against `reference/screen-dark.png` (widget tests only checked text content, not color, until this was caught). Fixed `BalanceAmountText` to use `theme.colorScheme.primary` for positive/zero and `theme.colorScheme.error` for negative, and strengthened the FR-004 widget test to assert `Text.style.color` directly so a regression back to green would now fail the suite. Full re-verification after the fix was visual-only for one screenshot pass plus the widget test; a second full device re-walkthrough was judged unnecessary given the trivial, well-isolated nature of the fix.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: None — empty, skip directly to Phase 2.
- **Foundational (Phase 2)**: No dependencies beyond existing code. Now includes `lib/features/envelopes/data/`'s and `domain/`'s deletion (T003b/T003c, pulled forward from User Story 5 — the repo does not compile between T003 and T003c being done). BLOCKS User Stories 1, 2, 3, and 5. Does NOT block User Story 4 (see its Independence note). **The repo does not compile again until User Story 5 also lands** (see Phase 2's checkpoint) — Phase 2 → US1 → US3/T024 → US5 is a single non-stoppable unit (Implementation Strategy).
- **User Story 1 (Phase 3)**: Depends on Phase 2. Pulls forward the deletion of `ExpenseEntry`/`ExpenseFormScreen`/`expenses_providers.dart` (T013) from User Story 5, since `spending_screen.dart`'s rewrite cannot compile otherwise. Blocks User Story 2 and User Story 3 (both add to the same screen T014 creates).
- **User Story 2 (Phase 4)**: Depends on User Story 1.
- **User Story 3 (Phase 5)**: Depends on User Story 1 (adds to the same screen). Does not depend on User Story 2. Its T024 specifically (the generalized placeholder widget, not the rest of US3's buttons) is a dependency of User Story 5's T030/T032 — T024 must land before US5 can complete, even though T022/T023/T025–T027 (the rest of US3) can wait until after US5.
- **User Story 5 (Phase 6)**: Depends on Phase 2 (T003/T003b/T003c already done), Phase 3/T013 (`ExpenseEntry`/`ExpenseFormScreen` already deleted), and Phase 5/T024 only (the placeholder widget it reuses for `OverviewScreen` — not the rest of Phase 5). What remains at this phase is deleting the last three files of `lib/features/envelopes/presentation/`, the `OverviewScreen`/`app_router.dart` update, the sync-worker fix, and ARB cleanup. **This story is not independently deferrable** (see its own Dependency note) — it must complete before the repo compiles again after Phase 2.
- **User Story 4 (Phase 7)**: Depends only on existing code (`app_theme.dart`, `app_colors.dart`). Can run in parallel with Phases 3–6 from the start, though it shares `app_router.dart` with Phase 6's work (coordinate merge order, no logical dependency).
- **Polish (Phase 8)**: Depends on all desired user stories being complete.

### Parallel Opportunities

- T003, T006, T009 [P] — different files/concerns from the rest of Phase 2's sequential DB-schema chain (T001→T002→T004→T005; T007/T008 depend on T001/T002 but not on each other's completion order strictly). T003b/T003c are NOT parallel with each other (T003c depends on T003b) but the pair can proceed alongside T006/T009 once T003 itself is done.
- T010, T011, T012 [P] — different test concerns; T011/T012 share a file but are conceptually independent, can be drafted in parallel then merged.
- T022, T023 [P] — different files (new placeholder-widget test vs. `spending_screen_test.dart` additions).
- T027 [P] — independent ARB file edit, no code dependency on T025–T026's exact implementation shape.
- T028, T029 [P] — different files/concerns (`OverviewScreen` test vs. sync-worker test).
- **User Story 4 (Phase 7) can run largely in parallel with User Stories 1–3, 5 (Phases 3–6)** once Phase 2 is done — it touches `app_theme.dart`/`app_colors.dart`, disjoint from the balance-hub/Envelope-retirement work, though it shares `app_router.dart` with Phase 6 (coordinate merge order).
- T037, T038 [P] — same file but independent assertions, low conflict risk if merged carefully.

---

## Parallel Example: After Phase 2 Completes

```bash
# Two tracks — Track A is one uninterrupted sequence (Phase 2 + US1 + US3/T024 + US5
# do not compile as separable checkpoints, see Implementation Strategy); Track B is
# the one genuinely independent story:

Track A (non-stoppable until US5 lands):
  T010/T011/T012 → T013 → T014 → T015 → T016/T017/T018/T019          (US1)
  then T022 → T024 (placeholder widget test+impl only —
       T023/T025/T026/T027 can wait)                                  (US3, partial)
  then T028/T029 → T030 → T031 → T032 → T033 → T034 → T035 → T036    (US5)
  --- app compiles and tests pass again here ---
  then T023 → T025/T026/T027                                          (US3, remainder)
  then T020 → T021                                                   (US2)

Track B (visual polish, independent of Track A):
  T037/T038 → T039 → T040                                            (US4)
```

---

## Implementation Strategy

### MVP First — Phase 2 + US1 + US3/T024 + US5 form one atomic, non-stoppable unit

**This feature cannot be usefully stopped after Phase 2 or after User Story 1 alone** — the repo does not compile in between (see Phase 2's checkpoint). The true minimum unit that leaves the repo in a working, testable state is: Phase 2 (T001–T009) → User Story 1 (T010–T019) → User Story 3's T024 only (the placeholder widget, not its buttons) → User Story 5 (T028–T036). Only at that point does `flutter test`/`flutter analyze` pass again.

1. Complete Phase 2 (widen `ExpenseControlItem`, combined balance+drop migration, delete `envelopes/data|domain/`, `computeItemBalance`).
2. Complete Phase 3/User Story 1 (delete `ExpenseEntry`/`ExpenseFormScreen`, rewrite `SpendingScreen`).
3. Complete just T024 from Phase 5/User Story 3 (the generalized placeholder widget — needed by US5's `OverviewScreen` replacement; the rest of US3 — the actual buttons/row on `SpendingScreen` — can wait).
4. Complete Phase 6/User Story 5 (delete the rest of `lib/features/envelopes/`, replace `OverviewScreen`, fix the sync worker, clean up ARB strings).
5. **STOP and VALIDATE**: this is the first point since Phase 2 began where `flutter analyze`/`flutter test` can actually pass. Run quickstart.md's first and fifth Verify sections.

### Incremental Delivery

1. Foundational (Phase 2) → User Story 1 → User Story 3's T024 only → User Story 5 → first validate/demo point (per above — this whole chain is one delivery unit, not four separable ones).
2. Add the rest of User Story 3 (T022, T023, T025–T027 — the actual buttons/row) → validate → demo.
3. Add User Story 2 (distinguish from formula screen — largely a verification pass) → validate.
4. Add User Story 4 (bottom nav icon-color fix) at any point in parallel with 1–3, or last — it's the only genuinely independent story in this feature.

### Parallel Team Strategy

1. One person/track completes Phase 2 → US1 → US3/T024-only → US5 as one uninterrupted sequence (per the MVP unit above) — this cannot be split across people without one blocking on another's compile-breaking changes.
2. Once that sequence lands: add the rest of US3 and US2 (both quick, sequential, low-risk).
3. A second, independent track does US4 in parallel with the ENTIRE first track's run, coordinating merge order on `app_router.dart` with whoever lands US5's T032/T033.

---

## Notes

- [P] tasks = different files (or, within T011/T012, T037/T038, different concerns in the same file, noted explicitly above), no blocking dependency on an incomplete task.
- research.md Decision 5's identified existing-test inversion is T037 specifically — do not treat it as "fix if broken," it is scoped implementation-adjacent work (the assertion is now factually wrong about the new design, not merely stale).
- T024 (generalizing `HistoryPlaceholderScreen`) is the one task where two reasonable implementation shapes exist (keep the class name vs. rename it) — pick whichever keeps `app_router.dart`'s existing "Báo cáo" tab behavior unchanged, verified by that tab's own existing tests still passing.
- User Story 1's T013 and User Story 5's T030/T031 are the two places this feature deletes code — T013 is pulled forward out of its "natural" US5 home because US1 cannot compile without it; this split is intentional, not an error, and is called out explicitly in both phases' descriptions above.
- Commit after each task or logical group, per this project's established practice (see prior features' tasks.md files for the in-place-annotation convention used to record verification evidence during implementation).
