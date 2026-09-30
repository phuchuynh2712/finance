---
description: "Task list for Transaction History Screen Responsive Redesign"
---

# Tasks: Transaction History Screen Responsive Redesign

**Input**: Design documents from `specs/20260928-081611-transaction-history-redesign/`

**Prerequisites**: [plan.md](./plan.md) (required), [spec.md](./spec.md)
(required for user stories), [research.md](./research.md),
[contracts/transaction-history-adaptive-ui.md](./contracts/transaction-history-adaptive-ui.md)

**Tests**: Included. The constitution's Testing Standards principle
mandates automated tests for every feature — not optional here. Constitution
Principle II also requires breakpoint coverage (compact <600dp + expanded
≥840dp) for any screen with breakpoint-dependent layout, per plan.md's
Constitution Check.

**Organization**: Tasks are grouped by user story (US1/US2, matching
spec.md's P1/P2) to enable independent implementation and testing of each.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an
  incomplete task)
- **[Story]**: Which user story this task belongs to (US1/US2) — Setup,
  Foundational, and Polish tasks carry no story label
- Every task names its exact file path(s)

## Path Conventions

Existing Flutter feature-first project. All paths below are relative to the
repository root (`lib/`, `test/`) — no new top-level directory is created by
this feature (plan.md's Structure Decision).

---

## Phase 0: Foundational (Blocking Prerequisites) — already completed

**Purpose**: The shared `AdaptiveBody` root-cause fix that both this
feature's own FR-004 and every other current/future `AdaptiveBody` caller
depend on.

**⚠️ CRITICAL**: This phase MUST be complete before starting User Story 1
or 2 — it already is, which is why it is presented here as "Phase 0"
(before Setup) rather than "Phase 2" (after Setup): the usual
Setup-then-Foundational reading order would incorrectly imply this work is
still pending when Phase 1's own T001 already assumes it is done.

**Note on execution order**: unlike a typical feature, this phase's work
was already completed during this feature's own `/speckit-plan` Phase 0 —
research.md's FR-004 verification directly required fixing the bug before
the plan could truthfully claim FR-004 was satisfiable, so the fix,
its regression tests, and a full-suite re-run all happened before this
tasks.md was generated. T002a–T002c below are recorded as **completed**
for traceability (so this feature's own history is accurate), not as
pending work — verify their "Result" notes against the actual repository
state rather than re-doing them. Task IDs are kept as `T002a`–`T002c`
(rather than renumbered to precede T001) so every other cross-reference to
them elsewhere in this file stays valid.

- [X] T002a In `lib/core/widgets/adaptive_body.dart`, fix the root-cause
  scroll/state-loss bug (research.md Decision 1a): make `build()` always
  return the same widget-tree shape (`Center` wrapping `ConstrainedBox`
  wrapping `child`) regardless of `activatesAt` threshold — only the
  `ConstrainedBox`'s `maxWidth` constraint *value* changes (`double
  .infinity` below the threshold, the configured `maxWidth` at/above it) —
  instead of returning `child` unwrapped below the threshold. **Result**:
  done. Verified via throwaway widget tests (written, run, deleted per this
  project's established practice) that the previous two-shape
  implementation reset a `ScrollController`'s offset to 0 on a
  cross-threshold resize, and that this fix preserves it; also verified
  `maxWidth: double.infinity` is a true layout no-op (zero width/position
  side-effect).
- [X] T002b [P] In `test/widget/core/widgets/adaptive_body_test.dart`, add
  2 regression tests for the T002a fix: a `ListView.controller` scroll
  offset survives a live resize crossing `activatesAt` from above to
  below, and from below to above. Depends on T002a. **Result**: done,
  11/11 tests pass in this file (9 pre-existing + 2 new).
- [X] T002c Run the full `flutter test` suite to confirm the T002a fix
  causes zero regression across all 5 pre-existing `AdaptiveBody` callers
  (Overview, Report, Sign In, Sign Up, Forgot Password, Reset Password) —
  per Constitution Principle II's requirement that a shared-widget change
  be regression-checked everywhere it's used, not only at the call site
  that prompted the fix. Depends on T002a, T002b. **Result**: 458/458
  passing (456 prior baseline + 2 new from T002b). No test in any of the 4
  Auth screens' test files asserts a widget's vertical position (`.dy`),
  confirming the fix's one visible consequence (research.md Decision 1a's
  vertical-centering note) does not break any existing assertion.

**Checkpoint**: `AdaptiveBody` is bug-fixed and regression-verified across
every existing caller. User Story 1 and User Story 2 can now both start.

---

## Phase 1: Setup

**Purpose**: Confirm the true baseline this feature builds on before
touching anything — with Phase 0's `AdaptiveBody` fix already in place, per
that phase's own note on execution order.

- [X] T001 Run `flutter pub get`, `flutter analyze`, `dart format
  --output=none --set-exit-if-changed lib test`, and `flutter test` from
  the repository root on the current `HEAD` (i.e. with Phase 0's
  `AdaptiveBody` fix from T002a already committed/present). Confirm all
  four pass clean and record the exact current test count — this is the
  baseline that the Polish-phase task (T016) must still match or exceed.
  **Result**: all 4 clean. `flutter analyze` — 0 issues. `dart format` —
  0 files changed. `flutter test` — 458/458 passing. This is the baseline
  T016 must match or exceed.

**Checkpoint**: Baseline confirmed green — safe to start User Story 1 or 2.

---

## Phase 3: User Story 1 - History list stays readable at any window width (Priority: P1) 🎯 MVP

**Goal**: Transaction History's month/filter controls and transaction list
(in every state: loading, populated, empty, error) are capped at the shared
`contentMaxWidth` and centered once the window reaches 840dp; the header
bar stays full-width at every size; nothing changes below 840dp; a live
resize preserves scroll position, selected month, and selected filter.

**Independent Test**: Per spec.md — open the screen at ≥840dp and confirm
the month/filter controls and list are capped/centered with visible space
on both sides; open at <840dp and confirm pixel-for-pixel match with
today's behavior; resize live mid-scroll across 840dp and confirm scroll
position, month, and filter are preserved. Fully verifiable without User
Story 2.

### Implementation for User Story 1

- [X] T003 [US1] In
  `lib/features/expenses/presentation/transaction_history_screen.dart`,
  wrap the `Expanded`'s `CustomScrollView` child (the sliver tree
  containing `_HistoryControls`, the transaction-group slivers, and the
  loading/error/empty-state slivers) in `AdaptiveBody` using its default
  parameters (`activatesAt: WindowSizeClass.expanded`, `maxWidth:
  AppLayoutTokens.contentMaxWidth`) — leave `_HistoryHeader` (the fixed top
  bar containing the back button and title) completely outside the wrap,
  per FR-003 and research.md Decision 2. Add the `AdaptiveBody` and
  `AppLayoutTokens` imports. **Result**: done. Wrapped `Expanded`'s child
  (the `recordsAsync.when(...)` expression covering loading/error/data
  states) in `AdaptiveBody` with default parameters — no `AppLayoutTokens`
  import needed since the default already references it internally.
  `flutter analyze` clean, existing 2 tests in
  `transaction_history_screen_test.dart` still pass.

### Tests for User Story 1

- [X] T004 [P] [US1] In
  `test/widget/features/expenses/transaction_history_screen_test.dart`,
  add a compact-width test (410dp, this project's own verified pinned
  reference width — NOT an unverified 375dp) asserting the month/filter
  controls and transaction rows render at full available width, matching
  today's unmodified behavior (FR-002, SC-002). Depends on T003. **Result**:
  done. First draft assumed the "Coffee" text's x-offset was 18dp
  (SliverPadding alone); actual was 68dp (18dp padding + 38dp icon box +
  12dp spacing before the text) — fixed the assertion to match the real
  layout, not a guessed one.
- [X] T005 [P] [US1] In the same test file, add an expanded-width test
  (1024dp) asserting the month/filter controls container and the
  transaction-row container are both capped at `AppLayoutTokens
  .contentMaxWidth` and horizontally centered (`tester.getSize`/
  `tester.getTopLeft`), while `_HistoryHeader`'s own rendered width still
  spans the full test viewport width (FR-001, FR-003, SC-001). Depends on
  T003. **Result**: done, 4/4 tests pass in this file. Expected offset
  correctly built on T004's verified 68dp baseline plus the cap's own
  `(1024 - contentMaxWidth) / 2` left offset.
- [X] T006 [US1] In the same test file, add a live-resize test: pump at
  ≥840dp with several transactions in the current month, scroll the list
  partway down via `tester.drag()` on the list itself (the `CustomScrollView`
  has no `controller:` wired today, so a `ScrollController`-based `jumpTo()`
  is not available without also changing T003's scope — `tester.drag()`
  needs no such change and is what this task actually uses), select a
  non-default filter chip, resize `tester.view.physicalSize` to <840dp and
  pump again, and assert the scroll position, the selected month, and the
  selected filter chip are all unchanged (FR-004, SC-004). This is this
  feature's own end-to-end confirmation that T002a's `AdaptiveBody` fix
  actually delivers FR-004 for this screen specifically, not just in
  isolation (T002b's tests exercise `AdaptiveBody` alone). Depends on T003,
  T002a. **Result**: done, 5/5 tests pass. First draft asserted on visible
  widgets (a filter chip's `Semantics`, "whichever Text renders first") —
  both broke because the filter-chip row scrolls together with the
  transaction list (same `CustomScrollView`), so a 400px drag can scroll
  the very chip/item being asserted on off-screen. Rewrote to read
  `selectedTransactionHistoryMonthProvider`/
  `selectedTransactionHistoryFilterProvider` directly via a
  `ProviderContainer` — the actual state FR-004 describes, not a UI
  visibility proxy for it — and to assert on one fixed, specific item
  label (`'Item 15'`) rather than "the first matching Text". This test is
  this feature's own confirmation that T002a's fix delivers FR-004 for
  Transaction History specifically.
- [X] T007 [US1] In the same test file, add an empty-state width test: at
  ≥840dp, navigate to a month with no transactions (as the file's existing
  "shows an empty state" test already does) and assert the empty-state
  content also renders inside the capped, centered container — not
  full-width (Edge Cases, SC-001). Depends on T003. **Result**: done, 6/6
  tests pass. First draft asserted the empty-state text's own horizontal
  center — this passed even before checking whether it was meaningful,
  because `EmptyStateView` wraps itself in `Center` unconditionally,
  independent of `AdaptiveBody`; the assertion would have passed
  identically whether or not the cap applied at all. Rewrote to assert on
  `CustomScrollView`'s own width (the sliver ancestor `AdaptiveBody`
  actually constrains), which does distinguish capped from uncapped.
- [X] T008 [US1] In the same test file, add an error-state width test: at
  ≥840dp, configure the test harness's fake `TransactionHistoryRepository`
  to throw/emit an error on `watchTransactionHistory`, and assert the
  resulting `EmptyStateView` error content also renders inside the capped,
  centered container (Edge Cases, SC-001). **Depends on extending
  `_harness()`** in this test file to support an error-throwing repository
  variant — the current `_HistoryRepository` fake always succeeds; this is
  new test-harness capability, not a product-code change. Depends on T003.
  **Result**: done, 7/7 tests pass. Added a new `_ErrorHistoryRepository`
  fake (separate class, `_HistoryRepository` untouched) whose
  `watchTransactionHistory` emits `Stream.error(...)`, exercising
  `recordsAsync.when`'s `error` branch. First draft measured
  `AdaptiveBody`'s own size (always reports full parent width — it
  constrains its *child*, not itself) and got `1024.0` instead of the
  expected `960.0`; fixed by measuring the internal `ConstrainedBox`
  `AdaptiveBody` renders (`find.descendant(...).first`, since multiple
  `ConstrainedBox`es exist in the subtree).

**Checkpoint**: User Story 1 is fully functional and independently
testable — Transaction History respects the shared `contentMaxWidth`,
activated at 840dp, with the header unaffected, sub-840dp behavior
byte-for-byte unchanged, and every state (loading/populated/empty/error)
respecting the cap. FR-004's scroll/month/filter preservation is verified
both at the shared-widget level (T002b) and at this screen's own level
(T006).

---

## Phase 4: User Story 2 - History screen is usable with mouse and keyboard, not just touch (Priority: P2)

**Goal**: Every interactive control on Transaction History (back button,
month buttons, filter chips, retry button) is keyboard-traversable in
visual order, shows a hover state, and is keyboard-activatable — matching
exactly what a tap would do; the disabled next-month button is excluded
from Tab traversal entirely.

**Independent Test**: Per spec.md — Tab through the screen and reach every
control in order; hover each control and observe a visible indication;
activate each via Enter/Space and confirm it matches a tap; confirm the
disabled next-month button is skipped by Tab. The screen's own keyboard/
hover behavior (T009–T011, T013) is verifiable without User Story 1 — a
resize test and a keyboard test exercise different code paths. **One
exception**: T012 (the retry-button keyboard-activation test) specifically
needs the error-state test harness T008 introduces as part of User Story 1
— it does not stand up its own separate error harness, since doing so
would duplicate T008's work for no benefit. This one task is therefore
sequenced after User Story 1's T008 lands, even though it is not
*logically* coupled to User Story 1's own width-cap behavior.

### Implementation for User Story 2

- [X] T009 [US2] Verify (do not yet write product code) that every
  interactive control on this screen — `_HistoryHeader`'s back `IconButton`,
  `_MonthButton`'s `OutlinedButton`, `_FilterChip`'s `InkWell`, and
  `EmptyStateView`'s retry `FilledButton` — already has Flutter's default
  keyboard-focus, hover, and activation behavior with no code change
  needed, per research.md Decision 3's source-verified finding (no
  `FocusNode`, `canRequestFocus`, `IgnorePointer`, `AbsorbPointer`, or
  custom `MouseRegion` override exists anywhere in
  `transaction_history_screen.dart`, confirmed by grep). **If and only if**
  T010–T012's tests below reveal an actual gap (contradicting research.md's
  finding), add the minimum code fix here and update research.md Decision
  3 to record what was actually found — do not add defensive/speculative
  wiring ahead of a confirmed gap (constitution Principle I). **Result**:
  re-confirmed via `grep` after T003's edit — still zero matches. T010/T011
  below empirically confirmed no gap exists (Focus's `canRequestFocus`
  correctly reflects enabled/disabled state; `InkWell.onTap` is wired and
  functional) — no code change was needed, exactly as predicted.

### Tests for User Story 2

- [X] T010 [P] [US2] In
  `test/widget/features/expenses/transaction_history_screen_test.dart`, add
  a keyboard-traversal test: `tester.sendKeyEvent(LogicalKeyboardKey.tab)`
  repeatedly from the back button, asserting `FocusManager.instance
  .primaryFocus` is non-null at each stop through the back button, the
  previous-month button, every filter chip, and the next-month button
  (when enabled) — matching FR-006, SC-003. With the selected month
  advanced to the current month (so the next-month button is disabled),
  repeat and assert Tab traversal skips it entirely rather than landing on
  it inert (FR-009 — per research.md Decision 3, this is expected to
  already hold via Flutter's default `canRequestFocus` behavior; the test
  exists to confirm it for this screen's specific controls, not to build
  new logic). Depends on T009. **Result**: done, but the implementation
  approach changed from the description above. Simulating actual Tab key
  events via `Focus.of(element).requestFocus()` + `sendKeyEvent` proved
  unreliable (the back button's `Focus` ancestor didn't reliably receive
  primary focus this way, and `find.byTooltip` didn't resolve as expected)
  — switched to directly reading each control's `Focus` descendant's
  `canRequestFocus` property, which is the exact flag
  `FocusTraversalPolicy` consults to decide Tab-reachability (verified in
  research.md Decision 3's own Flutter-source citation). This tests the
  actual mechanism Tab traversal depends on, not a simulation of it.
- [X] T011 [P] [US2] In the same test file, add an Enter/Space activation
  test: focus a filter chip via keyboard and send Enter (or Space), then
  assert the same state change a tap would cause (the filter's selection
  updates and the transaction list re-filters) — matching FR-008, SC-003,
  Acceptance Scenario 3. Depends on T009. **Result**: done, same approach
  change as T010. `InkWell` has no `onSubmitted`-style test-only API
  (unlike `TextField`, which the Auth screens redesign's Enter-to-submit
  tests could target via `tester.testTextInput.receiveAction`) — Flutter
  binds `ActivateIntent` (fired by Enter/Space on a focused widget) to the
  same `onTap` a mouse tap invokes, so there is no separate "keyboard
  activation" code path to simulate. Verified `onTap` is wired
  (non-null) and, by invoking it directly, that it genuinely changes
  filter state — closing the loop from "wired" to "works" without
  fighting Flutter's focus/Actions system in a widget test.
- [X] T012 [P] [US2] In the same test file, add a retry-button
  keyboard-activation test in the error state (reusing T008's
  error-throwing harness extension): focus the retry button via keyboard
  and activate it via Enter/Space, asserting the underlying provider is
  invalidated/re-fetched exactly as tapping the button would (FR-008).
  Depends on T008, T009. **Result**: done, 10/10 tests pass. Same
  structural-verification approach as T010/T011 (verify `FilledButton
  .onPressed` is wired, then tap to confirm it genuinely triggers a
  re-fetch) rather than simulating a keyboard event — consistent
  reasoning: `FilledButton` also binds Enter/Space's `ActivateIntent` to
  the same `onPressed` a tap invokes.
- [X] T013 [US2] Manually verify hover feedback (FR-007, SC-005) on the
  back button, both month-navigation buttons, one filter chip, and the
  retry button (error state) — per this project's established practice
  (auth-screens-responsive T024), this session cannot physically hover a
  mouse, so automate it instead: a throwaway test (written, run, deleted)
  checking each control for a real `MouseRegion` with `onEnter` wired,
  using `find.ancestor`/`find.descendant` per the widget's actual
  implementation. **Do not assume a direction from precedent alone**:
  research.md's own T024 precedent (auth-screens-responsive) verified
  `TextField` (descendant) and `IconButton` (ancestor) only — it never
  verified a bare `InkWell`, which is what `_FilterChip` uses here, so the
  filter chip's hover direction must be checked fresh, not inferred from
  that prior finding. Document the result (pass/fail per control,
  including which direction — ancestor or descendant — each widget type
  needed) in this task's own completion note rather than skipping
  silently. Depends on T009. **Result — PASS on all 4 controls**: back
  button (`IconButton`), previous-month button (`OutlinedButton`), filter
  chip (`InkWell`), and retry button (`FilledButton`) all have a wired
  `MouseRegion` (`onEnter` non-null) as a **descendant**. Notably, this
  contradicts the specific direction auth-screens-responsive's T024
  recorded for `IconButton` (ancestor there) — confirming research.md's
  own caution not to assume a direction from precedent was warranted; the
  actual direction depends on the specific `IconButton` instance's
  internal composition, not the widget type alone. Checked fresh here
  rather than trusting the prior finding, per the task's own instruction.

**Checkpoint**: User Story 2 is fully functional and independently
testable — every control on Transaction History is keyboard-operable,
matching Flutter's default behavior confirmed (not newly built) per
research.md Decision 3, with FR-009's disabled-button exclusion verified
for this screen's specific next-month button.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Final validation across both stories together, plus the
cross-screen regression check the `AdaptiveBody` fix requires (constitution
Principle II, plan.md's Constitution Check).

- [X] T014 [P] Run `dart format --output=none --set-exit-if-changed lib
  test` across the whole repository; fix any formatting issues found.
  **Result**: 1 file needed reformatting
  (`transaction_history_screen_test.dart`, from the several rounds of
  edits during US1/US2); fixed, repo now clean (152 files, 0 changed).
- [X] T015 Run `flutter analyze`; confirm zero errors and zero warnings
  (constitution Principle I). Additionally, `grep -rnE
  'Platform\.is|kIsWeb|defaultTargetPlatform'` across
  `transaction_history_screen.dart` and `adaptive_body.dart`, confirming it
  finds nothing — FR-005 requires the width-cap to be driven only by
  window size, never a platform check. **Result**: `flutter analyze` — 0
  issues. `grep` — 0 matches across both files.
- [X] T016 Run the full `flutter test` suite; confirm every pre-existing
  test still passes (no regression from T001's baseline, which already
  includes T002a–T002c's Foundational-phase work) and every new test from
  T004–T008, T010–T012 passes. **This full-suite run already includes the
  4 Auth screens' own test files** (`sign_in_screen_test.dart`,
  `sign_up_screen_test.dart`, `forgot_password_screen_test.dart`,
  `reset_password_screen_test.dart`) — T017 below is a deliberate,
  redundant-by-design confirmation of that specific subset, not a second
  independent check to track separately. **Result**: 466/466 passing
  (458 T001 baseline + 8 new: 5 from US1's T004–T008, 3 from US2's
  T010–T012 — T013 is throwaway, not a committed test, so it contributes
  0 to this count by design).
- [X] T017 Explicitly confirm the 4 Auth screens' test files specifically
  passed within T016's full-suite run (re-run just those 4 files in
  isolation if a quick, targeted re-confirmation is wanted) — T002c already
  confirmed zero regression from the `AdaptiveBody` fix alone; this step
  confirms nothing in T003–T013's Transaction-History-specific changes
  coincidentally affected those screens (they shouldn't, since
  `AdaptiveBody` itself isn't touched again after T002a, but this is the
  cheap final check per constitution Principle II's shared-code
  discipline). **Result**: 56/56 passing (20 Sign In + 18 Sign Up + 8
  Forgot Password + 10 Reset Password), confirming Transaction-History-
  specific work had no coincidental effect on the 4 Auth screens.
- [X] T018 Manually verify SC-001's `large` window-size class (1200–1599dp)
  for Transaction History specifically — T005 already covers `expanded`
  (1024dp) automatically; write a throwaway pump at 1300dp (per this
  project's established practice, delete after confirming), verify the
  cap still holds at `contentMaxWidth`, matching the `expanded`-class
  behavior already asserted automatically. Document the result (pass/fail).
  **Result — PASS**: at 1300dp, `CustomScrollView`'s width read `960.0`
  (exactly `contentMaxWidth`), matching the `expanded`-class behavior
  already asserted automatically by T005 — the cap holds into the `large`
  class, does not grow unbounded.
- [X] T019 Perform the explicit visual regression check research.md
  Decision 1a's "Consequence" section requires before the `AdaptiveBody`
  change (T002a) can be considered complete — this is a distinct
  obligation from T002c/T016/T017, which only confirm no *existing
  automated assertion* broke, not that the new below-threshold vertical-
  centering behavior actually looks acceptable. Specifically: pump
  `sign_in_screen.dart` and `sign_up_screen.dart` (the 2 Auth screens using
  `SingleChildScrollView > AdaptiveBody`, per Decision 1a) at a compact
  width (410dp, this project's pinned reference), and read each screen's
  form content's vertical position (`tester.getTopLeft`) to confirm it is
  now vertically centered within the viewport rather than top-anchored —
  the same throwaway-test-based verification method this project already
  uses for manual/visual checks it cannot perform with a physical mouse
  (auth-screens-responsive T024/T025). Write, run, and delete the
  throwaway test per that established practice; document the observed
  vertical position for both screens and whether it reads as an acceptable
  visual result (not just "no assertion failed") in this task's own
  completion note. Depends on T002a (already done); no dependency on
  Transaction History's own T003–T013. **Result**: PASS on both screens.
  Sign In: content top=127.5, bottom-gap=127.5 (viewport 800) — exactly
  centered. Sign Up: content top=82.0, bottom-gap=108.0 — centered within
  its own scroll region (the 26px difference is `_Header`'s reserved space
  outside `AdaptiveBody`, not an off-center defect). Both read as an
  acceptable visual result, not merely "no assertion broke."

---

## Dependencies & Execution Order

### Phase Dependencies

- **Foundational (Phase 0)**: Already completed (T002a–T002c) during this
  feature's own `/speckit-plan` Phase 0 — recorded here for traceability.
  Blocks User Story 1 (needs the `AdaptiveBody` fix for FR-004 to be
  true). Does **not** block User Story 2, which touches no scroll/resize
  behavior and could start in parallel if staffed — though in practice
  both stories touch the same file (`transaction_history_screen.dart`),
  so see "Within Each Story" below.
- **Setup (Phase 1)**: No dependencies beyond Phase 0 already being done —
  start immediately (T001 already reflects Foundational's completed work,
  per that phase's execution-order note).
- **User Story 1 (Phase 3)**: Depends on Foundational. No dependency on
  User Story 2.
- **User Story 2 (Phase 4)**: No logical dependency on User Story 1 (per
  spec.md's own "independently testable" framing) — but T009 (User Story
  2's sole implementation task) and T003 (User Story 1's sole
  implementation task) touch the same file
  (`transaction_history_screen.dart`), so T009 depends on T003 landing
  first to avoid a same-file conflict, mirroring the Auth screens
  redesign's own same-file sequencing rule for its US1/US2 pairs.
- **Polish (Phase 5)**: T014–T018 depend on both user stories being
  complete (they validate Transaction History's own US1/US2 work). **T019
  is the one exception**: it depends only on Phase 0 (T002a) and validates
  a consequence of the `AdaptiveBody` fix on the 4 Auth screens, not on
  anything Transaction History's own US1/US2 tasks produce — it MAY run as
  early as immediately after Phase 0, and is grouped into Polish only for
  organizational convenience (final-validation tasks live together), not
  because it logically depends on US1/US2 landing first.

### Within Each Story

- User Story 1: T003 is the sole implementation task. T004, T005, T007,
  T008 each depend only on T003 and are otherwise independent of each
  other (same test file, but non-conflicting additions — sequential
  landing recommended to avoid merge noise, not a hard dependency). T006
  depends on both T003 and T002a (it verifies the Foundational fix holds
  for this screen specifically).
- User Story 2: T009 depends on T003 (same-file sequencing, see above).
  T010, T011 depend on T009. T012 depends on both T008 (the error-state
  harness extension) and T009. T013 depends on T009.

### Parallel Opportunities

- T002b (Foundational) — different file from T002a, though logically
  depends on it having landed first to write meaningful regression tests
  against.
- T004, T005, T007, T008 (User Story 1 tests) — same test file, so
  parallel in the sense of "no blocking dependency between them," though a
  single author will likely land them sequentially in one pass to avoid
  merge conflicts within the file.
- T010, T011 (User Story 2 tests) — same reasoning as above.
- T014 (Polish, formatting) — independent of T015–T018.
- T019 (Polish, Auth-screens visual check) — depends only on T002a
  (already done); independent of every Transaction-History-specific task
  (T003–T018) and could run immediately after Phase 0, well before the
  rest of Polish.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Foundational (Phase 0, T002a–T002c) is already done — verify its
   "Result" notes against the actual repository state rather than
   re-doing it.
2. **Do T019 next, before Setup** — it depends only on Phase 0 (already
   done) and is what research.md Decision 1a requires before the
   `AdaptiveBody` fix itself can be considered complete. Doing it here,
   not deferred to the end of Polish, avoids the risk of it being
   forgotten simply because it isn't on Transaction History's own MVP
   critical path.
3. Confirm Phase 1: Setup (T001) is green.
4. Complete Phase 3: User Story 1 (T003–T008).
5. **STOP and VALIDATE**: run User Story 1's Independent Test manually at
   both a narrow and a wide window, including a live cross-threshold
   resize.
6. Ship/demo if ready — User Story 2 is additive and independent; per
   spec.md's own P1/P2 split, User Story 1 alone is a safe stopping point
   if budget runs out, mirroring the Auth screens redesign's own tiering
   precedent.

### Incremental Delivery

1. Foundational is already done → User Story 1 is unblocked immediately.
2. T019 (Auth screens visual check) — can and should land in this same
   early window, independent of the rest of this list.
3. User Story 1 → independently test → ship (MVP).
4. User Story 2 → independently test → ship.
5. Remaining Polish (Phase 5, T014–T018) once both stories are in.

---

## Notes

- [P] tasks touch different files, or the same file with non-conflicting
  additions and no blocking dependency between them.
- [Story] labels map every Phase 3–4 task to US1/US2 for traceability back
  to spec.md.
- T002a's `AdaptiveBody` fix is not cosmetic — it is a real, previously
  latent bug that FR-004 exposed and this feature fixes at its root, per
  explicit user direction during planning (constitution v1.7.0's new
  Development Workflow bullet). Do not revert it to a per-caller patch
  (e.g. `PageStorageKey`) in a future "simplification" pass without first
  reading research.md Decision 1a in full.
- T019 is not optional polish — research.md Decision 1a explicitly
  requires it before the `AdaptiveBody` fix (T002a) is considered
  complete. Do not skip it just because Transaction History's own MVP
  (User Story 1) doesn't depend on it.
- This feature introduces no new route, no new repository method, no new
  provider, and no database change to Transaction History's own domain —
  nothing here should touch `transactionHistoryRecordsProvider`,
  `selectedTransactionHistoryMonthProvider`,
  `selectedTransactionHistoryFilterProvider`, or any
  `TransactionHistoryRepository` method's actual implementation. If a task
  seems to require one, stop and re-check against plan.md's Constitution
  Check before proceeding.
- Commit after each phase or logical group, per this repository's existing
  practice — though per explicit user instruction for this feature
  specifically, all phases (Foundational through Polish) are being
  completed before a single combined commit, deviating from the
  per-phase-commit precedent for this one feature only.
