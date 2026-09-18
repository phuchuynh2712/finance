---

description: "Task list template for feature implementation"
---

# Tasks: Align Expense Control Screen with Design (Formula Editing, Group Summary, Bottom Nav)

**Input**: Design documents from `/specs/20260918-100444-lock-formula-dialog-edit/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md (all present)

**Tests**: Included — the project constitution (Principle II, Testing Standards) mandates automated tests shipped with every feature and, per Principle I/Development Workflow, that behavior changes ship tests in the same PR, not as a follow-up. research.md Decision 6 additionally identifies two *existing* tests whose assertions contradict this feature's new behavior — updating them is scoped work here, not incidental breakage to fix opportunistically.

**Organization**: Tasks are grouped by user story (spec.md: US1–US5) to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an incomplete task in this list)
- **[Story]**: Which user story this task belongs to (US1–US5)
- File paths are exact and repo-relative

## Path Conventions

Single Flutter project (per plan.md's Project Structure): `lib/` for app code, `test/unit|widget/` mirroring `lib/`. No new directories — every task lands inside the existing `lib/features/expense_control/` or the shared `lib/core/router/`, `lib/core/l10n/`.

---

## Phase 1: Setup

**Purpose**: None needed — this feature adds no new modules, packages, or directory skeleton; every touched file already exists.

*(No tasks — proceed directly to Phase 2.)*

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Widen the pending-edit concept from formula-only to whole-item (research.md Decisions 1–2), which every user story either writes to, reads from, or gates on.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T001 Replace `ExpenseFormulaEdit` with `PendingItemEdit` in `lib/features/expense_control/domain/expense_control_item.dart` per data-model.md: nullable `name`, `iconKey`, `description`, `method` (`ExpenseAllocationMethod?`), `value` (`double?`) — all optional, meaning "unchanged from the committed item" when null; keep the class doc comment pointing at data-model.md instead of research.md §9 (this feature's own research.md, not the prior feature's). **Done**: resolved as plain `String?` for `description` (T028), not a tri-state wrapper — documented in the class doc comment.
- [X] T002 Rename `pendingFormulaEditsProvider` → `pendingItemEditsProvider` in `lib/features/expense_control/presentation/expense_control_providers.dart`, updating its type from `StateProvider<Map<String, ExpenseFormulaEdit>>` to `StateProvider<Map<String, PendingItemEdit>>` (depends on T001)
- [X] T003 Widen the tree-assembly overlay in `lib/features/expense_control/presentation/expense_control_providers.dart` (or wherever `ExpenseControlPlanService`'s tree-building is invoked with a pending overlay) so a `PendingItemEdit`'s `name`/`iconKey`/`description` — not only `method`/`value` — are applied on top of the matching committed `ExpenseControlItem` before the tree reaches presentation (FR-005), per research.md Decision 2 and contracts/expense_control_ui_state.md's read-side contract (depends on T002). **Done**: found the actual overlay logic lives in `ExpenseControlPlanService._applyOverlay` (`expense_control_plan_service.dart`), not `expense_control_providers.dart` — widened there; also renamed that file's `Map<String, ExpenseFormulaEdit>` params to `PendingItemEdit` throughout (buildTree/computeTotals/validateBudget).
- [X] T004 Update all call sites of the renamed provider/type across `lib/features/expense_control/presentation/expense_control_screen.dart` and `lib/features/expense_control/presentation/widgets/expense_group_card.dart` (parameter/variable names `pendingEditIds`, `onValueChanged` callback signature, etc.) to compile against `pendingItemEditsProvider`/`PendingItemEdit` (depends on T002, T003). **Done, with a deviation**: a third call site outside this task's named files was found later (during T006/T007/T008 cleanup) still compiling against the old name — `lib/core/router/app_router.dart:187`'s tab-switch discard (`ref.invalidate(pendingFormulaEditsProvider)`), which broke `app_router_test.dart`/`app_shell_test.dart`'s compilation. Fixed as a plain rename to `pendingItemEditsProvider`, preserving today's silent-discard behavior exactly — NOT the T018-T021 confirmation-prompt replacement, which is separate, larger, not-yet-done US3 work.

**Checkpoint**: The pending-edit map and its overlay now cover a whole item, not just its formula. Nothing user-visible has changed yet — user story implementation can now begin.

---

## Phase 3: User Story 1 - Edit a formula through the dialog instead of inline (Priority: P1) 🎯 MVP (part 1 of 2)

**Goal**: Lock the inline value/mode display to a non-interactive static label; make the existing item-edit dialog able to edit and stage a leaf's formula alongside its name/icon/description.

**Independent Test**: Per spec.md's Independent Test — tap the inline value label (nothing happens), then use the pencil icon to open the dialog and confirm it now contains editable formula fields alongside name/icon/description, staging on "Lưu" without touching the database (verifiable via widget test assertions on `pendingItemEditsProvider`'s state, without needing US2's commit path).

### Tests for User Story 1 ⚠️

> Write these tests FIRST; confirm the ones that assert *new* behavior fail before implementation, and update the ones asserting *old* behavior (research.md Decision 6) as part of this same phase.

- [X] T005 [P] [US1] Update `test/widget/features/expense_control/expense_item_row_test.dart`: replace every `find.byType(TextField)`/`enterText` assertion on the inline value field with an assertion that it renders as a non-interactive `Text` (or equivalent static label widget) showing the current/staged value, and that tapping it does not open a keyboard or focus any field (FR-001, SC-001, spec.md US1 Acceptance Scenario 1). **Done**: 3 tests, all passing — static-label rendering, tap-produces-no-reaction, fixed-amount formatting.
- [X] T006 [P] [US1] Add a new test in `test/widget/features/expense_control/expense_control_screen_test.dart` (or a new dialog-focused test file alongside it) covering: opening a leaf's edit dialog shows its mode/value pre-filled as editable fields (FR-003 leaf branch); opening a group's edit dialog still shows only name/icon/description (FR-003 group branch, spec.md US1 Scenario 6); tapping "Lưu" for a leaf with a valid change stages a `PendingItemEdit` and closes the dialog without calling `repository.update()` (FR-004); reopening that leaf's dialog before committing shows the staged value (FR-008, Scenario 4); an over-budget value blocks "Lưu" with an inline error and stages nothing (FR-006, Scenario 5). **Done**: added a `group('T006: ...')` block with 4 tests covering exactly these 4 scenarios (staging itself is covered by T007's rewritten test, so not duplicated here). Added `_harnessWithContainer`/`_containerFor` helpers (`UncontrolledProviderScope` + a held `ProviderContainer`) so tests can seed/assert `pendingItemEditsProvider` directly. All pass.
- [X] T007 [US1] Rewrite the now-contradicted test in `test/widget/features/expense_control/expense_control_screen_test.dart` currently named `"editing name/icon/description via the pencil dialog persists immediately (US3 Scenario 1)"` (research.md Decision 6) to assert the new leaf behavior — the edit stages via `pendingItemEditsProvider` and is only persisted after a subsequent "Lưu công thức" — while leaving the equivalent group-dialog case (if covered elsewhere in the same file) asserting immediate persistence, unchanged (depends on T006). **Done**: renamed to reflect the new behavior; asserts nothing is written to the repo and `savedFormulaBatches` is empty right after the dialog's "Lưu", then commits via "Lưu công thức" and asserts persistence. No separate group-dialog persistence test existed in this file to preserve (the file's other pencil-dialog coverage is this same leaf case).
- [X] T008 [P] [US1] Update `test/unit/features/expense_control/expense_control_form_controller_test.dart`: invert any assertion that `save()` calls `repository.update()` synchronously for an existing **leaf** item to instead assert it writes into `pendingItemEditsProvider` and does NOT call `repository.update()`; leave the existing-**group** and create-dialog assertions unchanged (research.md Decision 6, Decision 3). **Done**: fixed `_FakeExpenseControlRepository.saveFormulas`'s type (`PendingItemEdit`), added an `onStageEdit` capture map wired into `buildController`, inverted the FR-006 test to assert `repository.updated` is empty and `staged['1']` holds the new method/value. Group-case test unchanged (still asserts immediate `repository.update()`). All 6 tests pass.

### Implementation for User Story 1

- [X] T009 [US1] Extract `_CompactModeToggle` out of `lib/features/expense_control/presentation/widgets/expense_item_row.dart` into a shared, reusable widget (e.g. `lib/features/expense_control/presentation/widgets/allocation_mode_toggle.dart`) with its existing interactive pill behavior and 32px-tall styling intact, updating `expense_item_row.dart`'s current usage to import it from its new location — this must land *before* T010 removes the toggle's inline usage entirely, since T010 has nothing left to reuse from if this file's copy is deleted first (depends on T004). **Done, with a deviation**: T010's chosen mode-conveyance approach (a `%`/`₫` suffix baked into the static label's own text, not a separate widget) means the list side no longer needs *any* mode-toggle widget, extracted or otherwise. Extracted it anyway into `allocation_mode_toggle.dart` (renamed public `AllocationModeToggle`) purely for T012 (dialog) to reuse per FR-013 — it is not imported back into `expense_item_row.dart`.
- [X] T010 [US1] In `lib/features/expense_control/presentation/widgets/expense_item_row.dart`, replace `_FormulaField`'s `TextField` + (now-extracted-per-T009) mode-toggle `Row` with a non-interactive presentation: a `Text` showing the formatted value (reusing `formatPercent`/the fixed-amount formatter per the value's `method`) sized to its content (no fixed `width: 96`, per FR-001's mockup-matching requirement), plus the mode conveyed visually but non-interactively (FR-002 — exact treatment left to implementation judgment per Clarifications) — delete `_FormulaFieldState`'s `TextEditingController`/`_emit`/`onChanged` wiring entirely, since there is no more inline input to emit from (depends on T009). **Done**: chose a `%`/`₫` suffix on the label's own text ("24%", "4.000.000 ₫" — `CurrencyFormatter` already appends `₫`) to satisfy FR-002's "mode conveyed visually," rather than keeping a separate pill widget next to the label — simpler and still legible at a glance. This also meant removing `onValueChanged`/`hasPendingEdit` from `ExpenseItemRow`'s and `ExpenseGroupCard`'s public API entirely (no inline input left to have a callback for) — a slightly wider blast radius than either task's own wording anticipated, but required for the widget tree to compile once the field stopped being interactive.
- [X] T011 [US1] Update `ExpenseControlFormController` in `lib/features/expense_control/presentation/expense_control_form_controller.dart`: for an existing **leaf** item (`existingItem != null && isFormulaEditable == true`), change `save()` to run the existing budget-validation check (FR-006) and, on success, write a `PendingItemEdit` capturing every changed field into `pendingItemEditsProvider` instead of calling `repository.update()`; on validation failure, leave `state` such that the dialog stays open with the existing over-budget error surfaced (reuse `budgetValidation`'s existing display path) and stage nothing; leave the create-dialog and existing-group branches calling `repository.create()`/`repository.update()` exactly as today (research.md Decision 3) (depends on T009, T010). **Done**: `canSave` (which already includes `budgetValidation?.isValid`) still gates `save()` overall — an over-budget attempt was already a no-op before this change and still is, so FR-006's "dialog stays open with error, nothing staged" falls out of existing gating rather than needing new branching. Added a new `onStageEdit` callback (null-safe, defaults to no-op in tests that don't need it) wired in the provider factory to `pendingItemEditsProvider`.
- [X] T012 [US1] In `lib/features/expense_control/presentation/expense_control_screen.dart`'s `_ItemFormDialog`, add the mode selector (the T009 shared widget) and value field to the dialog's content when `params.isFormulaEditable` is true, laid out per FR-013 (value field `Expanded`, mode toggle beside it with only a small fixed gap, no dropdown) — replace the existing `DropdownButton<ExpenseAllocationMethod>` entirely; target SC-004 (a 9-digit value like `999999999` must stay fully visible while typing, not clipped) — verified on-device in T032 rather than by widget test, per this project's own prior-feature finding that layout overflow doesn't always reproduce at widget tests' default test-surface size (depends on T009). **Done**: the dialog already had a value field (`Expanded`) + mode selector in this exact layout shape from the prior feature — only the mode selector itself needed swapping (`DropdownButton` → `AllocationModeToggle`), layout/gap unchanged.
- [X] T013 [US1] Wire `_openEditDialog` in `lib/features/expense_control/presentation/expense_control_screen.dart` to pass `isFormulaEditable: item.allocationMethod != null` — `ExpenseControlItem` has no `isGroup` getter itself (only `ExpenseControlNode` does, via `children.isNotEmpty`); per the class's own doc comment a leaf carries a non-null `allocationMethod`/`allocationValue` while a group's are both null, so this is the correct leaf-vs-group test from an `ExpenseControlItem` alone — replacing today's hardcoded `isFormulaEditable: false` for all edits (FR-003) (depends on T012)

**Checkpoint**: A leaf's formula can now only be changed via the dialog, staged in-memory; the inline display is a static label. Not yet committable to the database (that's US2) — `flutter test` for this phase's scope should pass with US2's commit-path tests still pending/skipped.

---

## Phase 4: User Story 2 - Commit staged formula changes explicitly (Priority: P1) 🎯 MVP (part 2 of 2)

**Goal**: Make "Lưu công thức" (and, later, US3's tab-switch prompt) the sole path that writes `pendingItemEditsProvider`'s staged edits — including staged metadata, not formula-only — to the database.

**Independent Test**: Per spec.md's Independent Test — seed `pendingItemEditsProvider` with staged edits for two items (bypassing the dialog UI, directly via the provider, to test this story in isolation from US1's UI), confirm nothing is in the database yet, press "Lưu công thức", confirm both are persisted and the map is cleared.

### Tests for User Story 2 ⚠️

- [X] T014 [P] [US2] Update `test/widget/features/expense_control/expense_control_screen_test.dart`'s existing "Lưu công thức" coverage (the tests referencing `research.md §9` batch-commit behavior) to seed `pendingItemEditsProvider` with a `PendingItemEdit` that includes a staged `name` change (not only `method`/`value`) and confirm pressing "Lưu công thức" persists the name change too (FR-004's "together as a single pending edit", SC-002, research.md Decision 4). **Done**: replaced the old inline-typing "research.md §9" test (which typed into a now-nonexistent `TextField`) with a container-seeded equivalent for the value-only case, plus a new test seeding `PendingItemEdit(name: 'Renamed', value: 50)` and asserting both fields land after "Lưu công thức". Also caught and fixed a real bug while writing these: the fake repository's `saveFormulas` was silently dropping `name`/`iconKey`/`description` (only wrote `method`/`value`), which would have made this test fail against the fake, not the implementation — fixed to mirror the real repo's all-5-fields write.
- [X] T015 [P] [US2] Confirm (add if missing) a widget test asserting that with zero staged edits, "Lưu công thức" is not shown/is disabled (FR-007, spec.md US2 Scenario 3 — likely already covered by the prior feature's tests; verify it still passes unchanged). **Done**: no such test existed in this file (only inline-typing tests, now removed) — added one asserting `find.text('Lưu công thức')` is absent with an empty pending map.

### Implementation for User Story 2

- [X] T016 [US2] Update `ExpenseControlRepository.saveFormulas` in `lib/features/expense_control/domain/expense_control_repository.dart` and its Drift-backed implementation in `lib/features/expense_control/data/expense_control_repository_impl.dart` to accept `Map<String, PendingItemEdit>` instead of `Map<String, ExpenseFormulaEdit>`, and to write every non-null field of each `PendingItemEdit` (name/iconKey/description via the same update path as `update()`, method/value as today) in one transaction per item — signature/behavior otherwise unchanged (research.md Decision 1's "no shape change to the repository's own contract" refers to the *interface method count*, not this one parameter's type) (depends on T001). **Done — pulled forward ahead of T006/T007**: discovered mid-US1 that `ExpenseFormulaEdit` still being the repository's parameter type was a compile-blocking dependency for every test file touching `saveFormulas`/`_FakeExpenseControlRepository`, not just US2's own scope — did this task out of its nominal order to unblock the rest. Each field uses `Value.absent()` when unset (leaves that column untouched) vs. `Value(...)` when the edit specifies it.
- [X] T017 [US2] Update the "Lưu công thức" button's `onPressed` handler in `lib/features/expense_control/presentation/expense_control_screen.dart` to call the T016 signature and clear `pendingItemEditsProvider` to `{}` on success, unchanged in every other respect (validation-before-write, error display, enabled/disabled gating) from today's behavior (FR-007) (depends on T016). **Done**: already implemented (as a byproduct of the T012/T013 screen edits) — `onPressed` calls `repository.saveFormulas(pendingEdits)` then `ref.read(pendingItemEditsProvider.notifier).state = {}`; validation/error-display/gating untouched. Confirmed correct and end-to-end tested by T014's new tests (value-only and value+name cases both persist and clear the map).

**Checkpoint**: User Stories 1 and 2 together form the MVP — a leaf's formula (and any accompanying name/icon/description change) can be edited via the dialog, staged, and explicitly committed. Independently testable and demoable now, per quickstart.md's first two Verify sections.

---

## Phase 5: User Story 3 - Warn before losing unsaved staged edits by switching tabs (Priority: P2)

**Goal**: Intercept bottom-navigation tab switches while `pendingItemEditsProvider` is non-empty, offering "Lưu" / "Không lưu" / "Hủy" instead of today's silent `ref.invalidate(pendingFormulaEditsProvider)` discard.

**Independent Test**: Per spec.md's Independent Test — stage an edit (via US1/US2's now-working flow), tap a different bottom-nav tab, confirm the three-button prompt appears and each choice behaves as specified before navigation proceeds (or doesn't).

### Tests for User Story 3 ⚠️

- [ ] T018 [P] [US3] Add ARB keys for the three prompt button labels ("Lưu", "Không lưu", "Hủy") and the prompt's title/message text to `lib/core/l10n/app_vi.arb` with English translations in `lib/core/l10n/app_en.arb`, in the same commit (Constitution Principle III Localization: `vi` MUST NOT lag `en`) — write this as a test-adjacent task since T019 depends on the generated `AppLocalizations` getters existing
- [ ] T019 [US3] Add a widget test in `test/widget/core/router/app_shell_test.dart` (extending its existing pending-edit-discard coverage) covering: with staged edits present, tapping a different bottom-nav tab shows the three-button prompt and does not navigate immediately (FR-009, SC-003, Scenario 1); tapping "Lưu" persists staged edits then navigates (FR-010, Scenario 2); tapping "Không lưu" clears the map without persisting then navigates immediately (FR-011, Scenario 3); tapping "Hủy" navigates nowhere and leaves the map intact (Scenario 4 in Edge Cases); an over-budget staged combination blocked via the prompt's "Lưu" keeps the prompt open with an error and does not navigate (Edge Cases §3); with zero staged edits, tapping another tab navigates immediately with no prompt (FR-012, Scenario 4) — SC-003 specifically requires this prompt fires for all four other destinations, not just one, so parametrize or repeat this assertion across Tổng quan/Thu chi/Lịch sử/Hồ sơ, not a single tab (depends on T018)

### Implementation for User Story 3

- [ ] T020 [US3] Create the three-button confirmation dialog (e.g. as a private widget or a `showDialog`-returning function within `app_router.dart`, or its own file under `lib/core/router/` if it grows beyond a few lines) using the T018 ARB strings for "Lưu"/"Không lưu"/"Hủy", surfacing the same over-budget error styling as "Lưu công thức" when its "Lưu" choice's validation fails — this must land *before* T021 wires it in, since T021 has nothing to call otherwise (same before-its-user ordering pattern as T009/T010) (depends on T018)
- [ ] T021 [US3] In `lib/core/router/app_router.dart`'s `_AppShell` (or wherever the router currently does `if (mounted) ref.invalidate(pendingFormulaEditsProvider)` on tab-index change), replace the silent invalidate with: check `pendingItemEditsProvider` non-empty → if so, `await showDialog` the T020 confirmation widget and branch on its result (save-then-navigate via the same commit path as T017, discard-then-navigate by clearing the map, or don't navigate) before calling `goBranch`; if empty, navigate immediately as today (FR-009–FR-012) (depends on T017, T020)

**Checkpoint**: Staged edits can no longer be lost by switching tabs. All P1+P2 user stories (US1–US3) are complete and independently verified.

---

## Phase 6: User Story 4 - Show the group allocation summary only when it's the only overview available (Priority: P3)

**Goal**: A group header's allocation-summary line is visible only while collapsed, never truncated while shown.

**Independent Test**: Per spec.md's Independent Test — collapse a group whose summary previously truncated, confirm it now shows in full across multiple lines; expand it, confirm the summary disappears entirely.

**Independence note**: Touches only `expense_group_card.dart`'s rendering of `groupSubtotal` — no dependency on the pending-edit widening (Phase 2) or US1–US3's dialog/staging changes; can be implemented and tested in parallel with Phases 3–5 by a different contributor once Phase 2 is merged (it shares the file with US1's T004 update, so sequence after T004 specifically, not after all of US1–US3).

### Tests for User Story 4 ⚠️

- [ ] T022 [P] [US4] Add a widget test in `test/widget/features/expense_control/expense_group_card_test.dart` covering: a collapsed group with a summary long enough to have previously truncated now renders it in full, wrapped across multiple lines, no ellipsis (FR-015, SC-005, Scenario 1); expanding that same group hides the summary line entirely, leaving only the header row (FR-014, Scenario 2); toggling collapsed⇄expanded updates the summary's visibility immediately each time (Scenario 3)

### Implementation for User Story 4

- [ ] T023 [US4] In `lib/features/expense_control/presentation/widgets/expense_group_card.dart`, wrap the `groupSubtotal` `Text` widget in a condition on `_expanded == false` (hide it entirely when `true`) and remove its `overflow: TextOverflow.ellipsis` (let it wrap naturally instead, per FR-014/FR-015) (depends on T004)

**Checkpoint**: Group summaries no longer duplicate information or truncate. Independently shippable regardless of US1–US3/US5's state.

---

## Phase 7: User Story 5 - Correct the bottom navigation bar's visual details to match the design (Priority: P3)

**Goal**: Fix the shared bottom `NavigationBar`'s indicator color, one label's line-wrapping, and its missing top border — app-wide, not scoped to Expense Control.

**Independent Test**: Per spec.md's Independent Test — open any screen, confirm the selected tab's indicator is the brand primary color, confirm all five labels render on one line each, confirm a thin top border separates the bar from content above.

**Independence note**: Touches only `app_router.dart`'s `NavigationBar` construction (styling, not the tab-switch logic US3 also adds to the same file) — no *logical* dependency on any other phase; can be done in parallel with Phases 3–6 by a different contributor at any point after this file exists (i.e. immediately). Caveat: US3 (T020/T021) edits the same file for unrelated reasons — no logical conflict, but two contributors literally editing `app_router.dart` at the same time risks a git-merge collision even though neither depends on the other's changes; coordinate merge order or work sequentially on this one file if staffed separately.

### Tests for User Story 5 ⚠️

- [ ] T024 [P] [US5] Add widget-test coverage in `test/widget/core/router/app_shell_test.dart` (or a new `NavigationBar`-focused test file) asserting: the selected destination's indicator color equals `Theme.of(context).colorScheme.primary` (not the default `NavigationBarThemeData`/`colorScheme.secondary` teal) (FR-016); every one of the five destination labels ("Tổng quan", "Kiểm soát", "Thu chi", "Lịch sử/Báo cáo", "Hồ sơ") measures as a single line at the default text scale — e.g. via `tester.getSize` on each label's rendered `Text` staying within one line-height, or by asserting the widget tree contains no forced line break for "Lịch sử/Báo cáo" specifically (FR-017); the bar's container has a top border matching `AppSemanticColors.border1`/the app's standard border token (FR-018); repeat the indicator-color and single-line-label assertions after selecting each of the other four tabs, not only the first, since SC-006 requires this to hold on every tab (FR-016–FR-018, SC-006)

### Implementation for User Story 5

- [ ] T025 [US5] In `lib/core/router/app_router.dart`, set the `NavigationBar`'s `indicatorColor` explicitly to `Theme.of(context).colorScheme.primary` (or add `indicatorColor` to a `NavigationBarThemeData` in `AppTheme.light`/`.dark` in `lib/core/theme/app_theme.dart` if a theme-level fix is preferred over a per-instance override — pick whichever keeps the app's "single centralized design system" principle intact, i.e. the theme-level fix, so any future second `NavigationBar` instance doesn't need to repeat the override) (FR-016)
- [ ] T026 [US5] In `lib/core/router/app_router.dart`, shorten or restyle the "Lịch sử/Báo cáo" `NavigationDestination`'s label so it fits on one line at the default text scale alongside the other four (e.g. reduce label font size slightly for all five destinations if that's what it takes to fit the longest one, or shorten this label's text — confirm with the user which approach before assuming a copy change, since the spec left the exact wording unspecified) (FR-017)
- [ ] T027 [US5] Wrap the `NavigationBar` in `lib/core/router/app_router.dart`'s `Scaffold.bottomNavigationBar` with a `Container`/`DecoratedBox` adding a top border (`Border(top: BorderSide(color: semantic.border1))`, matching the app's other fixed headers' existing border styling, e.g. `expense_control_screen.dart`'s header `Container`) (FR-018)

**Checkpoint**: All 5 user stories complete. The bottom navigation bar matches the design on every screen, not just Expense Control.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Verification and cleanup spanning all five stories.

- [X] T028 Resolve data-model.md's open question about `PendingItemEdit.description`'s unchanged-vs-cleared ambiguity: either confirm plain `String?` is sufficient (staged-clearing a description is not reachable through the current dialog UI, or an empty string is an acceptable stand-in for "cleared") and document that decision, or implement the tri-state wrapper data-model.md describes — resolve before or during T001, not after, since it affects `PendingItemEdit`'s shape. **Done**: resolved during T001 — plain `String?`, no tri-state wrapper; rationale documented in `PendingItemEdit`'s doc comment.
- [ ] T029 Run `flutter analyze` across the full repo and fix any warnings introduced by this feature (Constitution Principle I: zero errors/warnings before merge)
- [ ] T030 Run `dart format` scoped to every file touched by this feature's tasks (Constitution Development Workflow: unformatted code MUST NOT be merged)
- [ ] T031 Run the full `flutter test` suite and confirm all tests pass, including every test task above (T005–T008, T014–T015, T019, T022, T024) and the rest of the pre-existing suite (no unrelated regressions); per Constitution Principle II's ≥80% domain-layer coverage bar, confirm `ExpenseControlFormController`'s validation logic (extended, not replaced, by this feature per plan.md's Constitution Check) has not dropped below that threshold — this feature adds no new domain-layer class needing its own fresh coverage measurement, only extends an already-covered one
- [ ] T032 Walk through every "Verify" section of quickstart.md on a real device/emulator (not just widget tests — research.md's own prior-feature history in this same directory tree notes layout bugs on-device that widget tests' default test-surface size missed), recording evidence of each step per this project's established practice of annotating tasks.md in place with verification notes — explicitly confirm all 6 success criteria (SC-001 through SC-006) hold on-device, with SC-004 (9-digit value fully visible in the dialog) getting particular attention since it's the one SC this feature has no automated widget-test coverage for

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: None — empty, skip directly to Phase 2.
- **Foundational (Phase 2)**: No dependencies beyond existing code — BLOCKS User Stories 1, 2, and 3 (all read/write the widened pending-edit concept). Does NOT block User Stories 4 or 5 (see their Independence notes), though T004 (which touches files US4/US5 also touch) should land first to avoid merge conflicts.
- **User Story 1 (Phase 3)**: Depends on Phase 2. Blocks User Story 2 (nothing to commit without something staged) and User Story 3 (nothing to guard against losing without staging existing).
- **User Story 2 (Phase 4)**: Depends on User Story 1 (needs `PendingItemEdit` entries to exist to commit) — together they form the MVP.
- **User Story 3 (Phase 5)**: Depends on User Story 2 (its "Lưu" choice reuses the exact commit path T017 builds).
- **User Story 4 (Phase 6)**: Depends only on T004 (file-conflict avoidance), not on US1–US3's behavior. Can run in parallel with Phases 3–5.
- **User Story 5 (Phase 7)**: Depends on nothing but existing code. Can run in parallel with Phases 3–6 from the start.
- **Polish (Phase 8)**: Depends on all desired user stories being complete; T028 should actually resolve early (see its own note) rather than literally last.

### Parallel Opportunities

- T005, T006 (different test concerns, same file — sequence within the file, but conceptually independent) can be drafted in parallel by different people then merged.
- T014, T015 [P] — different assertions, low conflict risk.
- **US4 (Phase 6) and US5 (Phase 7) can run entirely in parallel with US1–US3 (Phases 3–5)** once Phase 2 is done — they touch disjoint files (`expense_group_card.dart` vs. `app_router.dart`) from the dialog/staging work.
- T024's test and T018's ARB additions [P] — independent files.

---

## Parallel Example: After Phase 2 Completes

```bash
# Two independent tracks can start simultaneously:
Track A (MVP): T005 → T006 → T007/T008 → T009 → T010 → T011 → T012 → T013  (User Story 1)
               then T014/T015 → T016 → T017                                 (User Story 2)
               then T018/T019 → T020/T021                                   (User Story 3)

Track B (visual polish, independent of Track A):
  T022 → T023                                                               (User Story 4)
  T024 → T025 → T026 → T027                                                 (User Story 5)
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2 Only)

1. Complete Phase 2: Foundational (widen the pending-edit concept).
2. Complete Phase 3: User Story 1 (dialog gains formula fields, inline display locked).
3. Complete Phase 4: User Story 2 ("Lưu công thức" commits staged edits, including staged metadata).
4. **STOP and VALIDATE**: run quickstart.md's first two Verify sections. This alone delivers the feature's core value (no more accidental inline edits, no more truncated long values) even before US3's safety net exists.

### Incremental Delivery

1. Foundational → MVP (US1 + US2) → validate/demo.
2. Add User Story 3 (tab-switch data-loss guard) → validate → demo.
3. Add User Stories 4 and 5 (independent visual-polish fixes) in either order, or in parallel — neither depends on the other or on US1–US3.

### Parallel Team Strategy

1. One or two people complete Phase 2 together (small, must land first for US1–US3).
2. Then: one track does US1 → US2 → US3 sequentially (each depends on the last); a second, independent track does US4 and US5 in parallel with the first track's entire run.

---

## Notes

- [P] tasks = different files (or, within T005/T006, different concerns in the same file, noted explicitly above), no blocking dependency on an incomplete task.
- research.md Decision 6's two identified test updates are T007 and T008 specifically — do not treat them as "fix if broken," they are scoped implementation tasks.
- T026 (shortening/restyling the "Lịch sử/Báo cáo" label) is the one task in this list where the spec deliberately left the exact approach open — confirm the specific wording/sizing choice before implementing, since it's the one place a wrong guess would be user-visible copy, not just internal structure.
- Commit after each task or logical group, per this project's established practice (see the prior `expense-control` feature's tasks.md for the in-place-annotation convention this project uses to record verification evidence).
