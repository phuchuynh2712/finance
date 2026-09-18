---

description: "Task list template for feature implementation"
---

# Tasks: Expense Control

**Input**: Design documents from `/specs/20260904-144604-expense-control/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md (all present)

**Tests**: Included — the project constitution (Principle II, Testing Standards) mandates automated tests shipped with every feature (unit ≥80% domain coverage, widget tests for reusable UI, integration tests for critical flows); this is not optional for this repository.

**Organization**: Tasks are grouped by user story (spec.md: US1–US4) to enable independent implementation and testing of each story.

**Revision history**:
- Rev 2 (2026-09-04): incorporated `/speckit-analyze` findings I1/C1/G1/C2/U1/U2 (old `/envelopes` tab, currency formatter, "Lưu công thức" flow, accessibility, FR-006 test, nesting-cap test).
- Rev 3 (2026-09-04): incorporated a second `/speckit-analyze` pass's findings — this revision's task IDs from T026 onward are renumbered again (no task had been started, so this remains a clean renumbering):
  - **G1** (new): US2 and US3 had no ARB-authoring task at all (only US1/US4 did) despite both introducing new user-facing strings — added T026 and T033.
  - **C1** (new): the old `/envelopes` cleanup task didn't delete `envelope_form_controller.dart` (becomes dead code) or `test/widget/features/envelopes/envelopes_screen_test.dart` (references the deleted `EnvelopesScreen` class — a compile break, not just dead code) — extended T049 (was T047).
  - **I1** (new): the "Parallel Team Strategy" note claimed US4 only touches routing independently of US1–US3, but the Rev 2 "Lưu công thức" discard-trigger task also touches `app_router.dart`'s `_AppShell` — corrected below.
  - **U1** (new): clarified the mechanism by which `ExpenseItemRow` behaves differently in the create-dialog vs. the live list (T041, was T039).
- Implementation complete (2026-09-04): all 56 tasks done. Two things surfaced during implementation that the plan didn't anticipate, both resolved:
  - A real correctness bug (not in any task's original scope): the pending-formula-edit overlay meant `ExpenseItemRow`'s `TextEditingController` never resynced after a discard (switching tabs away and back left the field showing the discarded typed value instead of reverting). Fixed by threading a `hasPendingEdit` flag down to `_FormulaField` and resyncing in `didUpdateWidget` exactly on the pending→committed/discarded transition; covered by a new `test/widget/features/expense_control/expense_item_row_test.dart`.
  - Live device testing (Android emulator) caught a real horizontal-overflow layout bug in the inline formula row (`SegmentedButton` + value `TextField` side by side didn't fit on-device, even though it fit in the mockup's 390px reference width) — none of the widget tests caught it because their default 800×600 test surface happened not to trigger it. Fixed by stacking the value field above the mode toggle (`Column` instead of `Row`) in `expense_item_row.dart`; this is exactly the kind of gap `/verify`-style live testing exists to catch that a static review or unit/widget test suite alone would miss.
  - `test/unit/core/l10n_expense_control_en_test.dart` was added beyond the original task list to verify the English ARB strings actually resolve (T052) — the app itself has no runtime locale switcher to test through (a pre-existing, feature-independent gap), so this exercises `AppLocalizations` directly instead.
  - **A real functional bug found via live user review, not any test**: the "Thêm khoản trong [Tên nhóm]" button — the *only* way to add a child and turn a leaf into a group — was only ever rendered when the item was **already** a group (`isGroup && _expanded`). A plain leaf had no such affordance, so a leaf could never gain its first child through the UI at all (FR-002 was unreachable). Fixed in `expense_group_card.dart` by also rendering the button for the leaf branch. Covered by a new test in `expense_group_card_test.dart`.
  - **A spec correction, also from live user review**: the 2026-09-04 Clarification on the group sub-label ("renders empty/absent") was wrong. Added a 2026-09-05 Clarification + **FR-024**: a group's sub-label shows the live sum of its children's formulas (reusing the same `computeTotals` the plan-wide summary uses, just scoped to `node.children`), never blank. Implemented in `expense_control_screen.dart` (computes `groupSubtotal` per node) and `expense_group_card.dart` (renders it under the group name); `data-model.md` updated to document it as a derived, never-persisted value.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an incomplete task in this list)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- File paths are exact and repo-relative

## Path Conventions

Single Flutter project (per plan.md's Project Structure): `lib/` for app code, `test/unit|widget|integration/` mirroring `lib/`, `supabase/migrations/` for the sync-target schema.

---

## Phase 1: Setup

**Purpose**: Establish the new feature modules' directory skeleton so subsequent tasks have a place to land.

- [x] T001 Create directory skeleton: `lib/features/expense_control/domain/`, `lib/features/expense_control/data/`, `lib/features/expense_control/presentation/widgets/`, `lib/features/history/presentation/`, and their test mirrors `test/unit/features/expense_control/`, `test/widget/features/expense_control/`, `test/widget/core/router/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Local DB schema, sync target, domain contracts, DI wiring, and the navigable screen shell that every user story builds on.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T002 [P] Create Drift table `ExpenseControlItems` and local `enum ExpenseAllocationMethod { percentage, fixed }` (feature-local — do NOT import `envelopes_table.dart`'s enum, per research.md §5b) in `lib/core/database/tables/expense_control_items_table.dart`, per data-model.md's field table (id, userId, parentId nullable self-ref, name, iconKey, description nullable, sortOrder, allocationMethod nullable, allocationValue nullable, createdAt/updatedAt/deletedAt), with a `TableIndex` on `userId` mirroring `envelopes_user_id_idx`
- [x] T003 Register `ExpenseControlItems` in `lib/core/database/app_database.dart`'s `@DriftDatabase(tables: [...])`, bump `schemaVersion` from 1 to 2, and add an `onUpgrade` step to the existing `MigrationStrategy` (which currently only has `beforeOpen`) that runs when `from == 1`: soft-delete every existing `Envelopes` row (`deletedAt = DateTime.now()` where `deletedAt IS NULL`) per research.md §3 (depends on T002)
- [x] T004 [P] Create Supabase migration `supabase/migrations/<timestamp>_expense_control_items.sql` applying `contracts/schema.sql` verbatim (table, `user_id`/`parent_id` indexes, RLS enabled, owner-only policy)
- [x] T005 [P] Create domain entity `ExpenseControlItem` in `lib/features/expense_control/domain/expense_control_item.dart` (id, userId, parentId, name, iconKey, description, sortOrder, allocationMethod, allocationValue — mirrors `lib/features/envelopes/domain/envelope.dart`'s style)
- [x] T006 Create domain repository interface in `lib/features/expense_control/domain/expense_control_repository.dart` exactly per `contracts/expense_control_repository.md`: `watchAll`, `getAll`, `create`, `update`, `delete`, `reorderTopLevel`, and `saveFormulas(Map<String, ExpenseFormulaEdit> changes)` plus the `ExpenseFormulaEdit` type (the batch-commit half of the "Lưu công thức" flow, research.md §9 — real implementation lands in US3/T039, this task only declares the contract) (depends on T005)
- [x] T007 Create domain service `lib/features/expense_control/domain/expense_control_plan_service.dart`: build `ExpenseControlNode` trees (top-level items + direct children) from a flat `List<ExpenseControlItem>`; compute `ExpenseControlTotals` (percentAllocated, fixedItemCount, percentFree) across all leaves per data-model.md; validate a candidate save against FR-007 (sum ≤ 100%) and FR-008 (strictly < 100% when any fixed item exists) for FR-012's block-before-persist requirement; enforce the one-level nesting cap (FR-002 — reject/guard against a row whose `parentId` refers to another child row, not just a top-level item); every tree/totals/validation function accepts an optional `Map<String, ExpenseFormulaEdit>` overlay so US3's inline editing can compute against pending, not-yet-persisted state (research.md §9) — pure Dart, no Flutter/Drift imports (depends on T005)
- [x] T008 Unit tests for the plan service in `test/unit/features/expense_control/expense_control_plan_service_test.dart`: percentage-sum block at >100%, strict-<100% block when a fixed item exists and sum would hit exactly 100%, valid-save totals output (spec.md US1 Acceptance Scenarios 2–4); one-level nesting cap rejects assigning a `parentId` that itself already has a `parentId` (FR-002); totals/validation computed correctly when a pending-edit overlay is supplied (depends on T007)
- [x] T009 Create `ExpenseControlRepositoryImpl` in `lib/features/expense_control/data/expense_control_repository_impl.dart`: Drift-backed `watchAll`/`getAll`/`create`/`update`/`delete` with `sync_outbox` writes (`entityTable: 'expense_control_items'`), soft-delete tombstones — mirror `lib/features/envelopes/data/envelope_repository_impl.dart`'s transaction/outbox pattern; `delete()` cascades to direct children in the same transaction when the target has any (FR-016); implement `reorderTopLevel` and `saveFormulas` as `throw UnimplementedError()` stubs for now — the real implementations are T037 (US3, reorder) and T039 (US3, saveFormulas), needed here only so the class compiles against the T006 interface (depends on T003, T006)
- [x] T010 Create Riverpod providers in `lib/features/expense_control/presentation/expense_control_providers.dart`: `expenseControlRepositoryProvider`, a `watchAll()`-backed `StreamProvider<List<ExpenseControlItem>>`, and derived providers exposing the plan service's tree (`ExpenseControlNode`s) and totals (`ExpenseControlTotals`) — mirror `envelopes_providers.dart`'s style (depends on T007, T009)
- [x] T011 [P] Create reusable `EmptyStateView` widget in `lib/core/widgets/empty_state_view.dart`: icon + message + optional CTA button, theme-driven (no hardcoded colors), with a `Semantics` label on the CTA button (Constitution Principle III screen-reader requirement — research.md §11), per research.md §6
- [x] T012 [P] Add ARB keys `tabExpenseControl` and `expenseControlScreenTitle` (vi: "Kiểm soát" / "Kiểm soát chi tiêu") with English translations in `lib/core/l10n/app_vi.arb` and `lib/core/l10n/app_en.arb`
- [x] T013 Create the screen shell in `lib/features/expense_control/presentation/expense_control_screen.dart`: fixed header (icon badge + `expenseControlScreenTitle`), `Scaffold` wired to the providers from T010; body content (list/banner/empty-state) is intentionally left for US1 (depends on T010, T012)
- [x] T014 Insert a new `StatefulShellBranch` for `/expense-control` as the 2nd branch (right after `/overview`, before `/spending`) in `lib/core/router/app_router.dart`, pointing to `ExpenseControlScreen`, with a `NavigationDestination` using `l10n.tabExpenseControl` and an appropriate `lucide_icons` icon (e.g. `LucideIcons.slidersHorizontal`, matching the mockup's header icon) (depends on T013)

**Checkpoint**: Foundation ready — the Kiểm soát tab is reachable and shows an (empty) screen shell; user story implementation can now begin.

---

## Phase 3: User Story 1 - Define an Expense Item's Formula (Priority: P1) 🎯 MVP

**Goal**: Users can create a top-level leaf expense item with a name, icon, and percentage-or-fixed formula; the running allocation summary updates live; invalid saves (over-budget, zero/blank value) are blocked before persisting; an empty state greets a first-time user.

**Independent Test**: On the Expense Control tab, tap "Thêm khoản mới", enter a name and icon, choose percentage or fixed mode, enter a value, and save. Reopen the app and confirm the item and its formula persisted (spec.md US1 Independent Test).

### Implementation for User Story 1

- [x] T015 [P] [US1] Create the icon picker in `lib/features/expense_control/presentation/widgets/icon_picker.dart`: a curated `const Map<String, IconData>` of `lucide_icons` entries (icon key → `IconData`) and a picker widget that returns the selected key; each icon option carries a `Semantics` label (icon name) so the picker is screen-reader navigable (research.md §2, §11)
- [x] T016 [US1] Widget test for the icon picker in `test/widget/features/expense_control/icon_picker_test.dart`: selecting an icon returns its key, initial selection renders correctly (depends on T015)
- [x] T017 [P] [US1] Create `AllocationSummaryBanner` widget in `lib/features/expense_control/presentation/widgets/allocation_summary_banner.dart`: renders "Đã phân bổ {X}% + {N} khoản cố định" / "Còn {Y}% tự do" from `ExpenseControlTotals` (FR-011), using `AppSemanticColors.warning`/`warningSoft` tokens (no hardcoded colors); percentage values go through one centralized formatting helper (research.md §10) — no ad hoc string interpolation
- [x] T018 [US1] Create `ExpenseItemRow` widget (leaf) in `lib/features/expense_control/presentation/widgets/expense_item_row.dart`: name + icon (via T015's icon map), value input, percentage/fixed segmented toggle, and an informational note (not a blocking error) that insufficient real income may affect fixed-amount funding later (FR-010); fixed-amount values are formatted via `lib/core/formatting/currency_formatter.dart` (Constitution Principle III — research.md §10), never ad hoc string interpolation; the %/₫ toggle chips and any icon-only affordance carry `Semantics` labels (research.md §11); accept an `onValueChanged(String itemId, ExpenseFormulaEdit edit)`-style callback parameter so the same widget can be wired to different destinations by its caller (immediate form state in the create dialog vs. the pending-edits provider in the live list — see T041) rather than calling any persistence layer itself (depends on T015)
- [x] T019 [P] [US1] Create `ExpenseControlFormController` in `lib/features/expense_control/presentation/expense_control_form_controller.dart`: create/edit form state; validates name non-blank and value non-zero/non-negative/non-blank (FR-017) and delegates the percentage-budget check to `ExpenseControlPlanService` (FR-007/FR-008) before allowing save (FR-012)
- [x] T020 [US1] Unit tests for the form controller in `test/unit/features/expense_control/expense_control_form_controller_test.dart`: blank name rejected, zero/blank value rejected, valid leaf item accepted, over-budget candidate rejected via the plan service, switching formula mode (percentage ⇄ fixed) on an existing item replaces — does not convert or retain — the previously stored value (FR-006) (depends on T019)
- [x] T021 [US1] Wire the "Thêm khoản mới" button and a create-item form (name, icon picker, optional description, formula mode + value) in `expense_control_screen.dart`, calling `ExpenseControlRepositoryImpl.create` through the form controller on save — this creation flow persists immediately, including the item's initial formula (FR-017 requires a value up front); it is intentionally NOT part of the deferred "Lưu công thức" batch flow introduced in US3/research.md §9, which only covers *editing* an already-existing item's formula; wires T018's `onValueChanged` callback to the form controller's field, not to any repository call (depends on T015, T018, T019)
- [x] T022 [P] [US1] Add ARB keys (vi + en) for all US1-introduced strings: "Thêm khoản mới" button, empty-state message, fixed-amount informational note, over-budget validation message, blank-name/zero-value validation message, banner text templates, Semantics labels introduced by T015/T017/T018
- [x] T023 [US1] Render the top-level leaf item list plus the FR-023 empty state (`EmptyStateView` + prominent "Thêm khoản mới" CTA, banner hidden) in `expense_control_screen.dart`, using the ARB keys from T022; show `AllocationSummaryBanner` only when at least one item exists (depends on T011, T013, T017, T018, T022)
- [x] T024 [US1] Widget tests in `test/widget/features/expense_control/expense_control_screen_test.dart`: empty state renders with CTA and no banner (spec.md US1 Acceptance Scenario 1); create-and-list happy path; save blocked at 105% total with the offending total flagged; save blocked at exactly 100% when a fixed item exists; save blocked on zero/blank value (depends on T021, T023)

**Checkpoint**: User Story 1 is fully functional and independently testable — leaf items can be created, validated, listed, and persisted.

---

## Phase 4: User Story 2 - Group Items Into Categories (Priority: P2)

**Goal**: Users can turn a leaf item into a group by adding a child, see the group's own formula replaced by its children's, expand/collapse each group independently, and have a group revert to a leaf when its last child is removed.

**Independent Test**: Create a group, add two child items to it with their own formulas, collapse and re-expand the group, and confirm both children and their formulas persist and remain associated with that group (spec.md US2 Independent Test).

### Implementation for User Story 2

- [x] T025 [P] [US2] Create `ExpenseGroupCard` widget in `lib/features/expense_control/presentation/widgets/expense_group_card.dart`: header row (grip-vertical handle placeholder, icon badge, name, edit/delete buttons, chevron shown only when children exist), local expand/collapse state, children list (reusing `ExpenseItemRow` from T018), "Thêm khoản trong [Tên nhóm]" button, and — when childless — its own leaf formula row; the drag handle, pencil, trash, and chevron icons each carry a `Semantics` label (research.md §11), e.g. "Sắp xếp nhóm", "Sửa {name}", "Xoá {name}" (depends on T018)
- [x] T026 [P] [US2] Add ARB keys (vi + en) for all US2-introduced strings: "Thêm khoản trong [Tên nhóm]" button template, and the group-card Semantics label text values introduced by T025 ("Sắp xếp nhóm", "Sửa {name}", "Xoá {name}", chevron expand/collapse labels) — resolves analyze finding G1 (US2 previously had no ARB-authoring task)
- [x] T027 [US2] Extend `ExpenseControlRepositoryImpl.create()` in `expense_control_repository_impl.dart`: when the new item's `parentId` is set and the parent currently has zero children, clear the parent's `allocationMethod`/`allocationValue` in the same transaction as the child insert (FR-004) (depends on T009)
- [x] T028 [US2] Replace US1's flat leaf-only rendering in `expense_control_screen.dart` with tree rendering (`ExpenseGroupCard` for every top-level item, leaf or group) sourced from the `ExpenseControlNode` provider (T010/T007), using the ARB keys from T026 (depends on T025, T026, T023)
- [x] T029 [US2] Wire the "Thêm khoản trong [Tên nhóm]" flow (reuses the create form from T021 with `parentId` pre-set); new child appears at the end of the group's children with no formula set yet (FR-004 Acceptance Scenario 4) (depends on T019, T027)
- [x] T030 [US2] Wire last-child deletion so the parent reverts to leaf state and regains an editable (empty) formula row in the UI (FR-005) (depends on T007, T028)
- [x] T031 [P] [US2] Extend `expense_control_plan_service_test.dart` with leaf→group (formula cleared on first child) and group→leaf (formula slot re-eligible, not auto-restored) transition tests, plus a totals test confirming a group's own value never counts, only its children's (depends on T007)
- [x] T032 [US2] Widget tests in `test/widget/features/expense_control/expense_group_card_test.dart`: expand/collapse toggles independently of other groups; adding a child converts a leaf to a group; deleting the last child reverts a group to a leaf (depends on T025, T028, T030)

**Checkpoint**: User Stories 1 AND 2 both work independently — grouping, nesting-cap-of-one, and group totals are correct.

---

## Phase 5: User Story 3 - Edit, Reorder, and Delete Items and Groups (Priority: P2)

**Goal**: Users can edit any item/group's name/icon/description, adjust an existing item's formula inline and commit it via "Lưu công thức", drag-reorder top-level groups (persisted), and delete leaf items immediately or groups with a cascading-delete warning.

**Independent Test**: Edit an existing item's name and formula value, drag-reorder two top-level groups, then delete one item and confirm the remaining state (order, names, formulas) is correct and persists after an app restart (spec.md US3 Independent Test).

### Implementation for User Story 3

- [x] T033 [P] [US3] Add ARB keys (vi + en) for all US3-introduced strings: edit-dialog title/field labels/save-button text, the group-delete cascading-removal confirmation dialog text (title, warning, confirm/cancel buttons — FR-016; leaf deletion has no confirmation dialog, per spec.md US3 Acceptance Scenario 4's "removed immediately," so no ARB entry is needed for that path), the "Lưu công thức" button label + its Semantics label, and the FR-012 blocked/flagged validation message shown when the button is disabled — resolves analyze finding G1 (US3 previously had no ARB-authoring task)
- [x] T034 [US3] Wire the edit (pencil) flow on both group and item rows, pre-filling `ExpenseControlFormController` with the existing item's name/icon/description, calling `ExpenseControlRepositoryImpl.update` on save, using the ARB keys from T033 — this dialog covers name/icon/description only; formula editing is handled inline per T040–T042 (research.md §9), not through this dialog (FR-013) (depends on T019, T025, T018, T033)
- [x] T035 [US3] Wire the delete (trash) flow on leaf item rows: immediate removal via `ExpenseControlRepositoryImpl.delete`, summary updates to reflect the removal (FR-016, spec.md US3 Acceptance Scenario 4) (depends on T009)
- [x] T036 [US3] Wire the delete flow on group rows: confirmation dialog warning that child items will also be removed before the cascading deletion proceeds, using the ARB keys from T033 (FR-016, spec.md US3 Acceptance Scenario 3) (depends on T009, T033)
- [x] T037 [P] [US3] Implement `reorderTopLevel(List<String> orderedIds)` in `expense_control_repository_impl.dart`: persists new `sortOrder` values for the given top-level ids in one transaction, with outbox writes per changed row (FR-014) (depends on T009)
- [x] T038 [US3] Wire drag-and-drop reorder for top-level items/groups only (no child reordering, per research.md §4) in `expense_control_screen.dart`, calling `reorderTopLevel` on drop (depends on T037, T028)
- [x] T039 [US3] Implement `saveFormulas(Map<String, ExpenseFormulaEdit> changes)` in `expense_control_repository_impl.dart`, replacing the T009 stub: writes all changed items' `allocationMethod`/`allocationValue` in one Drift transaction with one `sync_outbox` row per changed item (research.md §9, contracts/expense_control_repository.md) (same file as T037 — not parallelizable with it; depends on T009)
- [x] T040 [US3] Create an `autoDispose` Riverpod provider in `expense_control_providers.dart` holding pending formula edits (`Map<String, ExpenseFormulaEdit>`); since `app_router.dart`'s `StatefulShellRoute.indexedStack` keeps the screen mounted across tab switches (`autoDispose` alone would NOT fire on tab-away — research.md §9), also add an explicit discard trigger in `_AppShell` (`app_router.dart`): watch `navigationShell.currentIndex` and `ref.invalidate()` the pending-edits provider whenever it changes away from the Kiểm soát branch's index, satisfying the Edge Case ("navigates away without tapping 'Lưu công thức' → unsaved changes discarded"). **Coordination note**: this modifies the same `_AppShell`/`app_router.dart` that T048/T049 (US4) also modify — if staffing US3 and US4 in parallel, coordinate on this file rather than treating them as fully independent (analyze finding I1) (depends on T010, T039, T014)
- [x] T041 [US3] Rewire `ExpenseItemRow`'s value input and %/₫ toggle (T018, via its `onValueChanged` callback) for already-persisted items so edits write to the T040 pending-edits provider instead of calling the repository directly; the tree/totals providers (T010) overlay pending edits via `ExpenseControlPlanService`'s optional overlay param (T007) so the summary banner reflects them live (FR-011) (depends on T018, T040, T007)
- [x] T042 [US3] Create and wire a "Lưu công thức" primary button (bottom of `expense_control_screen.dart`, per the mockup's page-level placement), using the ARB keys from T033, that validates the merged (persisted + pending) plan via `ExpenseControlPlanService` (FR-007/FR-008); if invalid, stays disabled/shows which total is violated (FR-012); if valid, calls `saveFormulas` (T039) and clears the pending-edits provider (T040) (depends on T039, T040, T041, T033)
- [x] T043 [US3] Unit tests in `test/unit/features/expense_control/expense_control_repository_impl_test.dart` (or extend an existing repo test file): `saveFormulas` persists all changed items in one transaction with correct outbox rows; `reorderTopLevel` persists new sort order (depends on T037, T039)
- [x] T044 [US3] Widget tests in `test/widget/features/expense_control/expense_control_screen_test.dart` (extends T024): inline-editing a formula updates the summary banner live before saving (FR-011); tapping "Lưu công thức" while over budget stays blocked and flags the total (FR-012); tapping it while valid persists and clears pending state; switching to another bottom-nav tab and back discards the pending edit without persisting it (Edge Case — drives an actual `navigationShell.currentIndex` change, not just a widget dispose, since `IndexedStack` keeps the screen mounted); editing name/icon/description via the pencil dialog persists immediately; deleting a leaf removes it immediately; deleting a group shows the confirmation dialog and cascades on confirm; reordering two top-level groups persists across a simulated provider/repository re-read (depends on T034, T035, T036, T038, T042)

**Checkpoint**: All of US1–US3 are independently functional — full CRUD, formula editing via "Lưu công thức", and reorder are in place.

---

## Phase 6: User Story 4 - Reach Expense Control via Updated Navigation (Priority: P3)

**Goal**: The bottom navigation shows exactly 5 tabs in order — Tổng quan, Kiểm soát, Thu chi, Lịch sử/Báo cáo, Hồ sơ — with "Thu chi"/"Hồ sơ" as renames of the old "Chi tiêu"/"Cá nhân" tabs, "Lịch sử/Báo cáo" as a new placeholder, and the old "Khoản" tab fully retired.

**Independent Test**: From any tab, confirm the bottom navigation shows exactly 5 tabs in order and that tapping "Kiểm soát" opens the Expense Control screen (spec.md US4 Independent Test — already satisfied by Foundational T014; this phase completes the remaining tabs and retires the old one).

### Implementation for User Story 4

- [x] T045 [P] [US4] Update ARB values (not keys) in `app_vi.arb`/`app_en.arb`: `tabSpending` vi "Chi tiêu" → "Thu chi"; `tabAccount` vi "Cá nhân" → "Hồ sơ"; review/update the `en` values to match (research.md §7)
- [x] T046 [US4] Add ARB key `tabHistory` (vi: "Lịch sử/Báo cáo", plus English) and a placeholder-screen message key in the same `app_vi.arb`/`app_en.arb` files (same files as T045 — not parallelizable with it; run after T045)
- [x] T047 [P] [US4] Create `HistoryPlaceholderScreen` in `lib/features/history/presentation/history_placeholder_screen.dart` using `EmptyStateView` (T011) with a "coming soon"-style message, no data layer (research.md §8) (depends on T011)
- [x] T048 [US4] Insert a new `StatefulShellBranch` for `/history` as the 4th branch (between `/spending` and `/account`) in `app_router.dart`, pointing to `HistoryPlaceholderScreen`, with a `NavigationDestination` using `l10n.tabHistory`; update the `/spending` and `/account` destinations' labels to use the renamed `tabSpending`/`tabAccount` values (already updated in T045) (depends on T014, T047)
- [x] T049 [US4] Remove the old `/envelopes` `StatefulShellBranch` and its `NavigationDestination` (`l10n.tabEnvelopes`) from `app_router.dart`; delete the now-unreferenced `tabEnvelopes` ARB key from `app_vi.arb`/`app_en.arb`; delete `lib/features/envelopes/presentation/envelopes_screen.dart`, `envelope_form_screen.dart`, and `envelope_form_controller.dart` (the latter is imported only by `envelope_form_screen.dart` — verified — so it becomes dead code the moment that screen is deleted); delete `test/widget/features/envelopes/envelopes_screen_test.dart` (tests the deleted `EnvelopesScreen` class directly — leaving it in place breaks compilation, not just dead code); remove `envelopes_providers.dart`'s `envelopeRepositoryProvider`/`envelopesStreamProvider` only if nothing else references them (verified: `spending_screen.dart` and `overview_screen.dart` DO still reference envelope-adjacent providers — do not remove providers those screens depend on) — resolves analyze findings I1 and C1 (FR-020 requires *exactly* 5 tabs and states Kiểm soát replaces the old Khoản tab; Constitution Principle I forbids merging dead/unrouted code and requires `flutter analyze`/tests to pass with zero errors) (research.md §12) (depends on T048)
- [x] T050 [US4] Widget test in `test/widget/core/router/app_shell_test.dart`: bottom nav shows exactly 5 destinations (not 6 — explicitly assert `/envelopes` is gone) in order Tổng quan/Kiểm soát/Thu chi/Lịch sử/Báo cáo/Hồ sơ with the correct (possibly renamed) labels; tapping each navigates to its screen; tapping "Lịch sử/Báo cáo" opens the placeholder (spec.md US4 Acceptance Scenarios 1–4) (depends on T049, T045, T046)

**Checkpoint**: All user stories independently functional; the full 5-tab navigation (FR-020) is complete and the old Khoản tab is retired.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Verification that spans all user stories.

- [x] T051 [P] Integration test in `test/integration/expense_control_flow_test.dart`: create → group (add child) → inline-edit formula → "Lưu công thức" → reorder top-level → delete, end-to-end against the real Drift DB (in-memory), per quickstart.md's manual checklist items 1, 4, 7, 8 (depends on all of Phase 3–5)
- [x] T052 [P] Locale-switch verification: with the app language set to English, confirm every string introduced by this feature (screen title, banners, buttons, validation/confirmation messages, Semantics labels, the two new/renamed tab labels) is translated and not falling back to Vietnamese or a raw ARB key (quickstart.md item 10)
- [x] T053 Run `flutter analyze` across all new/modified files and fix any errors or warnings (Constitution Principle I)
- [x] T054 Verify unit-test line coverage for `expense_control_plan_service.dart`, `expense_control_form_controller.dart`, and `expense_control_repository_impl.dart` is ≥80% (Constitution Principle II); add missing cases if short
- [x] T055 [P] Accessibility pass: verify every icon-only custom widget introduced by this feature (icon picker entries, group-card drag handle/pencil/trash/chevron, %/₫ toggle chips, empty-state CTA) exposes a `Semantics` label reachable by a screen reader, and that touch targets meet ≥48×48dp (Constitution Principle III — resolves analyze finding C2, research.md §11)
- [x] T056 Run the full quickstart.md manual verification checklist in both light and dark theme

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately.
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories (DB table, repository contract incl. `saveFormulas`, domain service, screen shell, and the Kiểm soát tab itself all live here).
- **User Stories (Phase 3–6)**: All depend on Foundational completion.
  - US1 (P1) has no dependency on US2/US3/US4 — it is the MVP.
  - US2 (P2) depends on US1's `ExpenseItemRow` (T018) and screen wiring (T023) being in place, since it extends leaf rendering into tree rendering.
  - US3 (P2) depends on US1's form controller (T019) and US2's tree rendering (T028) — edit/delete/reorder/formula-save act on the tree US2 introduced.
  - US4 (P3) depends only on Foundational (T014 already makes Kiểm soát reachable); it completes the remaining tabs and retires the old one. It is *mostly* independent of US1–US3's screen content, but shares one file (`app_router.dart`'s `_AppShell`) with US3's T040 — see the coordination note on T040.
- **Polish (Phase 7)**: Depends on US1–US3 (integration test) and all string-introducing phases (locale check).

### Within Each User Story

- Widgets/entities before the controllers/services that consume them.
- ARB-authoring tasks before the wiring tasks that render their strings.
- Repository/data-layer changes before the screen wiring that calls them.
- Implementation before its corresponding test task.
- Story checkpoint reached before starting the next-priority story (if working sequentially).

### Parallel Opportunities

- Foundational: T002, T004, T005, T011, T012 can run in parallel (independent files).
- US1: T015, T017, T019, T022 can run in parallel.
- US2: T025, T026, T031 can run in parallel.
- US3: T033 can run in parallel with T037 (independent files); T037 can run in parallel with the T034–T036 wiring tasks (different file); T039 shares a file with T037 (run after it, not parallel).
- US4: T045 and T047 can run in parallel (T046 shares T045's ARB files — run after T045).
- Polish: T051, T052, T055 can run in parallel.

---

## Parallel Example: Foundational Phase

```bash
# Launch independent Foundational tasks together:
Task: "Create ExpenseControlItems Drift table + ExpenseAllocationMethod enum in lib/core/database/tables/expense_control_items_table.dart"
Task: "Create Supabase migration supabase/migrations/<timestamp>_expense_control_items.sql"
Task: "Create ExpenseControlItem entity in lib/features/expense_control/domain/expense_control_item.dart"
Task: "Create EmptyStateView widget in lib/core/widgets/empty_state_view.dart"
Task: "Add tabExpenseControl/expenseControlScreenTitle ARB keys in app_vi.arb/app_en.arb"
```

## Parallel Example: User Story 1

```bash
Task: "Create icon picker in lib/features/expense_control/presentation/widgets/icon_picker.dart"
Task: "Create AllocationSummaryBanner in lib/features/expense_control/presentation/widgets/allocation_summary_banner.dart"
Task: "Create ExpenseControlFormController in lib/features/expense_control/presentation/expense_control_form_controller.dart"
Task: "Add US1 ARB keys in app_vi.arb/app_en.arb"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — includes the DB table, repository, domain service, and the Kiểm soát tab itself)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Run quickstart.md items 1–3 and the T024 widget tests independently
5. Demo: users can define and persist leaf expense items with live validation

### Incremental Delivery

1. Setup + Foundational → Kiểm soát tab reachable, empty screen
2. + US1 → leaf items create/list/validate (MVP)
3. + US2 → grouping, expand/collapse
4. + US3 → edit name/icon/description, inline formula editing + "Lưu công thức", reorder, delete
5. + US4 → full 5-tab navigation (renames + placeholder tab), old Khoản tab retired
6. + Polish → integration test, locale verification, coverage check, accessibility pass

### Parallel Team Strategy

Once Foundational is done, US4 can be *mostly* staffed independently of US1–US3 (it only otherwise touches routing/l10n, not the expense-control screen internals) — a second contributor can work through most of Phase 6 while a first works through Phases 3–5 in order (US2/US3 depend on each other's screen-rendering work, so they are best kept sequential for one contributor). **Exception**: US3's T040 and US4's T048/T049 all modify `app_router.dart`'s `_AppShell` — coordinate on that one file (e.g. the US4 contributor lands their router changes first, or the two changes are merged by hand) rather than assuming full independence.

---

## Notes

- [P] tasks = different files, no dependency on an incomplete task in this list.
- [Story] label maps task to its user story (US1–US4) for traceability.
- Tests are included per the project constitution (Testing Standards is a MUST, not optional for this repo) — written alongside/after their implementation task, not strictly TDD-first (not requested).
- Every user story that introduces new user-facing strings (US1, US2, US3, US4) has its own ARB-authoring task (T022, T026, T033, T045/T046 respectively) — per Constitution Principle III, hardcoded strings are prohibited and every new string needs both `vi`/`en` translations in the same PR.
- Commit after each task or logical group, per repository convention.
- Stop at any checkpoint to validate a story independently before continuing.
- `features/envelopes/`'s domain/data layers (`Envelope`, `EnvelopeRepository`, the `envelopes`/`envelope_coverages` Drift tables) are intentionally untouched — `Spending`("Thu chi")/`Overview` still depend on them (research.md §12). Only the dedicated envelopes CRUD *screen*, its form controller, its now-orphaned providers, and its now-stale test are removed, in T049.
