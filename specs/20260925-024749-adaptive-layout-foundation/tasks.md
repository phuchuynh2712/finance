---
description: "Task list for Adaptive Layout Foundation"
---

# Tasks: Adaptive Layout Foundation

**Input**: Design documents from `specs/20260925-024749-adaptive-layout-foundation/`

**Prerequisites**: [plan.md](./plan.md) (required), [spec.md](./spec.md) (required
for user stories), [research.md](./research.md), [data-model.md](./data-model.md),
[contracts/adaptive-shell-ui.md](./contracts/adaptive-shell-ui.md)

**Tests**: Included. The constitution's Testing Standards principle mandates
automated tests for every feature (unit/widget/integration as applicable) —
they are not optional here even though the generic template treats them as
such.

**Organization**: Tasks are grouped by user story (US1/US2/US3, matching
spec.md's P1/P2/P3) to enable independent implementation and testing of each.

**Revision note**: This file was updated after `/speckit-analyze` (see that
report for finding IDs referenced below) — T022/T023 are new (finding G1);
the tooltip-hover test (T025, was T023) drops a misleading example
(finding I2); the keyboard test (T026, was T024) is scoped more precisely
(finding G3); Polish gained an explicit platform-check verification step
(finding U1); task IDs from the original T022 onward shifted by +2 to make
room for T022/T023.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an
  incomplete task)
- **[Story]**: Which user story this task belongs to (US1/US2/US3) — Setup,
  Foundational, and Polish tasks carry no story label
- Every task names its exact file path(s)

## Path Conventions

Existing Flutter feature-first project. All paths below are relative to the
repository root (`lib/`, `test/`) — no new top-level directory is created by
this feature (plan.md's Structure Decision).

---

## Phase 1: Setup

**Purpose**: Confirm the true baseline this feature builds on before
touching anything.

- [X] T001 Run `flutter pub get`, `flutter analyze`, `dart format
  --output=none --set-exit-if-changed lib test`, and `flutter test` from
  the repository root on the current, unmodified `HEAD`. Confirm all four
  pass clean and record the exact current test count (386 as of this
  feature's start per spec.md SC-005) — this is the baseline that later
  Polish-phase tasks (T029–T030) must still match or exceed.

**Checkpoint**: Baseline confirmed green — safe to start Foundational work.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The shared breakpoint tokens and the pinned test-viewport fix
that both User Story 1 and User Story 2 depend on, and that every story's
own tests depend on being correct.

**⚠️ CRITICAL**: Complete this phase before starting User Story 1 or 2.
(User Story 3 does not depend on this phase — see its own section.)

- [X] T002 [P] Create `lib/core/theme/app_layout.dart`: a `WindowSizeClass`
  enum with five values — `compact` (0dp), `medium` (600dp), `expanded`
  (840dp), `large` (1200dp), `extraLarge` (1600dp) — a pure function
  `WindowSizeClass windowSizeClassFor(double width)` that returns the class
  whose lower bound is the greatest one `<= width` (a boundary value belongs
  to the higher class, e.g. exactly `600.0` → `medium`), and a constant
  `contentMaxWidth = 960.0` (see [data-model.md](./data-model.md)'s
  `WindowSizeClass`/`windowSizeClassFor`/`AppLayoutTokens` sections). Pure
  Dart, no Flutter import.
- [X] T003 [P] Create `test/flutter_test_config.dart` that sets
  `TestWidgetsFlutterBinding.ensureInitialized()`'s default test surface —
  via `WidgetTester.view` inside a `testExecutable(FutureOr<void> Function()
  testMain)` top-level function per `flutter_test`'s own auto-discovery
  convention for this exact filename — to a compact reference size of
  390×844 logical pixels (devicePixelRatio matching the existing convention
  in `test/widget/features/expenses/expense_screen_test.dart`, which already
  uses 800×1400 physical / a comparable ratio — reuse that same ratio
  approach), applied to every test unless that test explicitly overrides
  `tester.view.physicalSize` itself. See
  [research.md](./research.md) Decision 4 — this was empirically confirmed
  necessary this session: `flutter_test`'s own unpinned default is 800×600
  logical pixels, already past this feature's 600dp breakpoint.
- [X] T004 Add `test/unit/core/theme/app_layout_test.dart`: unit tests for
  `windowSizeClassFor` at each boundary pair — 599.0/600.0 (compact/medium),
  839.0/840.0 (medium/expanded), 1199.0/1200.0 (expanded/large),
  1599.0/1600.0 (large/extraLarge). Depends on T002.

**Checkpoint**: `app_layout.dart` exists and is unit-tested; every test in
this suite now runs at a known, explicit, compact-by-default width. User
Story 1 and User Story 2 can now both start.

**Addendum (found during implementation, not in the original task list)**:
T003's pinned default (410×864 — this app's own design-reference width,
not an arbitrary pick; see the file's doc comment) surfaced 5 real,
pre-existing test failures unrelated to any code this feature touches —
4 `RenderFlex` overflow bugs and 1 requirement (FR-017/SC-006) that turned
out to be unachievable at any real phone width. Both are fixed; full
details and the evidence behind the FR-017/SC-006 product decision are in
spec.md's new "Implementation Notes" section. Files touched beyond the
original T002–T004 scope: `lib/core/widgets/empty_state_view.dart`,
`lib/features/expense_control/presentation/expense_control_screen.dart`,
`lib/features/expenses/presentation/expense_screen.dart`,
`lib/features/expenses/presentation/income_screen.dart`, and
`test/widget/core/router/app_shell_nav_bar_test.dart`. Full suite: 396/396
passing (386 baseline + 10 new from T004).

---

## Phase 3: User Story 1 - Navigation adapts to window size (Priority: P1) 🎯 MVP

**Goal**: The app shell's primary navigation switches between a bottom bar
(<600dp) and a side rail (≥600dp, icon+label always visible), preserving
the selected tab, the existing Kiểm soát unsaved-edits prompt, and — per
Clarification Q2 — the currently viewed screen's own local state (scroll
position, unsubmitted form input), across a live resize in either
direction.

**Independent Test**: Per spec.md — open the app narrow, confirm the bottom
bar is unchanged; open/resize it wide, confirm a rail with the same 5
destinations, selected tab, and discard-prompt behavior; resize live across
600dp and confirm no state is lost. Fully verifiable without User Story 2
or 3.

### Implementation for User Story 1

- [X] T005 [US1] In `lib/core/router/app_router.dart`, replace the five
  hand-written `NavigationDestination` widgets inside `_AppShellState
  .build()` with a single private, ordered list of 5 plain-data entries
  (icon, a `String Function(AppLocalizations)` label getter, and the
  existing branch index 0–4, in today's order: Tổng quan, Kiểm soát, Thu
  chi, Báo cáo, Hồ sơ) — see [data-model.md](./data-model.md)'s
  `_NavDestinationSpec`. Do not change destination order, icons, or labels.
- [X] T006 [US1] In `lib/core/router/app_router.dart`, add a `GlobalKey`
  field to `_AppShellState`, instantiated once (e.g. `final _shellKey =
  GlobalKey();` as a field initializer or in `initState` — never inside
  `build()`, per the Flutter framework's own `GlobalKey` "Pitfalls"
  guidance cited in research.md Decision 2).
- [X] T007 [US1] In `lib/core/router/app_router.dart`, rework
  `_AppShellState.build()` to read `final widthClass = windowSizeClassFor
  (MediaQuery.sizeOf(context).width);` (from T002) and branch:
  - `widthClass == WindowSizeClass.compact` → today's existing shape:
    `Scaffold(body: KeyedSubtree(key: _shellKey, child:
    widget.navigationShell), bottomNavigationBar: <DecoratedBox-wrapped
    NavigationBar>)`, with the `NavigationBar`'s destinations built by
    mapping T005's shared list to `NavigationDestination`s (unchanged
    visual output from today).
  - otherwise (`medium`/`expanded`/`large`/`extraLarge`) → new shape:
    `Scaffold(body: Row(children: [<a NavigationRail with
    labelType: NavigationRailLabelType.all, selectedIndex, and
    destinations built by mapping T005's list to
    NavigationRailDestinations>, Expanded(child: KeyedSubtree(key:
    _shellKey, child: widget.navigationShell))]))`.
  - Both branches wrap `widget.navigationShell` with the *same* `_shellKey`
    instance (via `KeyedSubtree` or by passing the key directly if
    `StatefulNavigationShell` accepts one) so Flutter reparents rather than
    disposes it across a branch switch (research.md Decision 2).
  - `onDestinationSelected`/`onTap` on both widgets continue to call the
    existing `_handleDestinationSelected`, unchanged.
  - Do not introduce any `Platform.is*`/`kIsWeb`/`defaultTargetPlatform`
    check anywhere in this method — the branch above MUST be driven only
    by `widthClass` (FR-002; verified again in T028).
- [X] T008 [US1] In `lib/core/router/app_router.dart`, verify (and adjust
  if needed) that `_handleDestinationSelected`'s existing unsaved-Kiểm-soát
  -edits `_DiscardPromptDialog` gate (FR-004) is reachable identically
  whether it was triggered from `NavigationBar.onDestinationSelected` (T007
  compact branch) or `NavigationRail.onDestinationSelected` (T007 expanded
  branch) — no new branching logic should be needed since both call the
  same handler, but confirm this explicitly rather than assuming it.
- [X] T009 [US1] In `test/widget/core/router/app_shell_nav_bar_test.dart`,
  add/confirm a test at a compact width (<600dp, e.g. pump at the
  `flutter_test_config.dart` default from T003) asserting a
  `NavigationBar` is rendered with all 5 destinations, exactly matching the
  suite's existing pre-feature assertions (regression coverage).
- [X] T010 [US1] In the same file, add a test at an expanded width (≥600dp
  — explicitly set `tester.view.physicalSize` for this test) asserting a
  `NavigationRail` is rendered instead, with all 5 destinations each
  showing both icon and visible text label (Clarification Q1,
  `NavigationRailLabelType.all`), and the correct `selectedIndex`.
- [X] T011 [US1] In the same file, add a resize scenario: pump the shell at
  a compact width with a descendant test screen that has scrollable
  content or a `TextField`; scroll/type into it; then change
  `tester.view.physicalSize` to an expanded width and pump again; assert
  the scroll position / typed text is unchanged (Clarification Q2,
  Acceptance Scenario 5) — this is the test that actually exercises T006's
  `GlobalKey` reparenting, not just the visual bar-vs-rail switch.
- [X] T012 [P] [US1] In
  `test/widget/core/router/app_shell_discard_prompt_test.dart`, add a test
  mirroring the file's existing bottom-bar discard-prompt coverage, but at
  an expanded width so the trigger comes from `NavigationRail
  .onDestinationSelected` — confirm the same prompt and save/discard/cancel
  behavior (T008, FR-004, Acceptance Scenario 3).

**Checkpoint**: User Story 1 is fully functional and independently
testable — navigation adapts correctly at both ends, and no screen state is
lost across a live resize.

---

## Phase 4: User Story 2 - Content doesn't stretch edge-to-edge on wide screens (Priority: P2)

**Goal**: Tổng quan and Báo cáo cap their main content at a shared,
centered maximum width once the window reaches 840dp, unchanged below it.

**Independent Test**: Per spec.md — open either screen wide, confirm a
capped, centered content column instead of edge-to-edge stretching; open
narrow, confirm no change from today. Fully verifiable without User Story
1 or 3.

### Implementation for User Story 2

- [X] T013 [P] [US2] Create `lib/core/widgets/adaptive_body.dart`: an
  `AdaptiveBody` widget taking a required `child` and an optional
  `maxWidth` (defaults to `AppLayoutTokens.contentMaxWidth` from T002) that
  renders `child` unchanged when `windowSizeClassFor(MediaQuery.sizeOf
  (context).width)` is `compact` or `medium` (<840dp — FR-006), and wraps
  it in `Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth:
  maxWidth), child: child))` otherwise (FR-005) — see
  [contracts/adaptive-shell-ui.md](./contracts/adaptive-shell-ui.md)'s
  `AdaptiveBody` contract. Depends on T002.
- [X] T014 [P] [US2] In
  `lib/features/expenses/presentation/overview_screen.dart`, wrap the main
  scrollable content (inside the existing `Expanded(child: ListView(...))`
  — do not touch the `_Header` above it) in `AdaptiveBody`. Depends on
  T013.
- [X] T015 [P] [US2] In
  `lib/features/expenses/presentation/report_screen.dart`, make the
  equivalent change (same pattern as T014 — wrap the content `ListView`,
  leave `_Header`/`_MonthSelector` positioning as-is). Depends on T013.
- [X] T016 [P] [US2] Create
  `test/widget/core/widgets/adaptive_body_test.dart`: assert `child`
  renders at full available width below 840dp, and at a capped, centered
  width at and above 840dp (including a very wide test width, per
  Acceptance Scenario 3 — content must not keep growing). Depends on T013.
- [X] T017 [US2] In
  `test/widget/features/expenses/overview_screen_test.dart`, add a test at
  ≥840dp width asserting the main content column's rendered width does not
  exceed `AppLayoutTokens.contentMaxWidth` and is horizontally centered;
  confirm existing compact-width tests in this file are unaffected. Depends
  on T014.
- [X] T018 [US2] Make the equivalent addition to
  `test/widget/features/expenses/report_screen_test.dart`. Depends on T015.

**Checkpoint**: User Story 2 is fully functional and independently
testable — both screens respect the shared content max-width.

---

## Phase 5: User Story 3 - Every control works well with touch, mouse, and keyboard (Priority: P3)

**Goal**: A uniform ≥48×48dp tap target everywhere (including desktop
platforms, which Flutter would otherwise shrink by default, and including
the two known undocumented sub-48dp controls `/speckit-analyze` found —
finding G1), tooltips on every icon-only control, and full keyboard
reachability — enforced once at the shared theme level, plus two direct
fixes where the theme alone can't reach.

**Independent Test**: Per spec.md — hover icon-only controls and see
tooltips; Tab through a screen and see focus move with Enter/Space
activation; measure any control's clickable area at a desktop window size
and find it ≥48×48dp (except a control with its own documented exception —
FR-007). Fully verifiable without User Story 1 or 2 (this story does not
depend on the Foundational phase's `app_layout.dart`/
`flutter_test_config.dart` for its *implementation*, though its own new
tests will still run under T003's pinned default once that phase is done).

### Implementation for User Story 3

- [X] T019 [US3] In `lib/core/theme/app_theme.dart`, add `visualDensity:
  VisualDensity.standard` and `materialTapTargetSize:
  MaterialTapTargetSize.padded` to `AppTheme.light`'s `ThemeData` —
  overriding Flutter's own `TargetPlatform.linux/.macOS/.windows` defaults
  (`compact` density, `shrinkWrap` tap target size — confirmed in the
  installed SDK's `theme_data.dart`, research.md Decision 6), which is what
  a Web build running in a desktop browser would otherwise pick up.
- [X] T020 [US3] Make the identical addition to `AppTheme.dark` in the same
  file.
- [X] T021 [P] [US3] Add a tooltip (and, where one doesn't already exist, a
  matching `Semantics(button: true, label: ...)` wrapper) to each of these
  8 icon-only controls that currently have neither, reusing an existing
  localized string in every case — no new ARB key is needed for any of
  them:
  - `lib/features/expense_control/presentation/widgets/expense_item_row.dart:83`
    (edit) and `:100` (delete) — add `tooltip:` using the same value
    already passed to the surrounding `Semantics.label`
    (`l10n.expenseControlEditSemantic(item.name)` /
    `l10n.expenseControlDeleteSemantic(item.name)`).
  - `lib/features/expense_control/presentation/widgets/expense_group_card.dart:141`
    (edit) and `:157` (delete) — same pattern, same two existing keys.
  - `lib/features/expenses/presentation/income_screen.dart:330` (delete
    source) — same pattern, reuse
    `l10n.incomeSourceDeleteSemantic(widget.row.name)`.
  - `lib/features/expenses/presentation/income_screen.dart:62` and
    `lib/features/expenses/presentation/expense_screen.dart:85` (both a
    bare back-chevron `IconButton` in an `AppBar.leading`, with neither
    `Semantics` nor `tooltip` today) — add both, reusing the existing
    generic `l10n.signUpBackSemantic` ("Back") key already used for
    `sign_up_screen.dart`'s own back button.
  - `lib/features/account/presentation/sign_up_screen.dart:168` (the
    password show/hide toggle, currently bare) — add both `tooltip:` and a
    `Semantics` wrapper, reusing the exact same conditional pattern
    `sign_in_screen.dart:191` already uses:
    `_obscurePassword ? l10n.signInShowPasswordSemantic :
    l10n.signInHidePasswordSemantic`.
- [X] T022 [P] [US3] **(`/speckit-analyze` finding G1)** In
  `lib/features/expenses/presentation/income_screen.dart:333`, change the
  delete-source `IconButton`'s `constraints: const BoxConstraints(minWidth:
  44, minHeight: 44)` to `minWidth: 48, minHeight: 48` — this is the one
  confirmed, undocumented sub-48dp control on this screen (its sibling
  edit/delete buttons elsewhere in the codebase already use 48×48).
- [X] T023 [P] [US3] **(`/speckit-analyze` finding G1)** In
  `lib/features/account/presentation/account_screen.dart:513`, change the
  tab/segment control's `constraints: const BoxConstraints(minHeight: 28)`
  to `minHeight: 48` (add `minWidth: 48` too if the surrounding `Container`
  doesn't already guarantee it via its `padding`/text content — verify the
  rendered width at implementation time). Confirm the visual change (a
  slightly taller pill) doesn't clip or overlap adjacent elements in
  `account_screen.dart`'s layout.
- [X] T024 [US3] In `test/unit/core/theme/app_theme_test.dart`, add
  assertions that both `AppTheme.light.materialTapTargetSize` and
  `AppTheme.dark.materialTapTargetSize` equal `MaterialTapTargetSize
  .padded`, and both themes' `visualDensity` equals `VisualDensity
  .standard`. Depends on T019, T020.
- [X] T025 [US3] Create `test/widget/core/theme/adaptive_input_test.dart`:
  pump a representative screen containing one of T021's fixed controls
  with a mouse `TestGesture` and assert hovering it shows its tooltip
  text. Depends on T021. (Deliberately does not use a navigation-rail
  destination as the test subject here — the rail doesn't exist until User
  Story 1's T007 ships, and this story has no dependency on User Story 1;
  a rail-specific tooltip check belongs in User Story 1's own
  `app_shell_nav_bar_test.dart` instead, if desired, not here.)
- [X] T026 [US3] In the same new file, add a keyboard-traversal test
  covering what spec.md's SC-004 actually claims: (a) against the app's
  **existing, unmodified `NavigationBar`** (already present before this
  feature — no dependency on User Story 1's rail work), simulate repeated
  Tab key presses (`tester.sendKeyEvent(LogicalKeyboardKey.tab)`) and
  assert focus reaches and `LogicalKeyboardKey.enter`/`.space` activates
  each of the 5 navigation destinations in turn; and (b) on one screen
  (e.g. Tổng quan), assert Tab reaches and activates at least one primary
  in-screen action, with a visible focus indicator at each stop.

**Checkpoint**: User Story 3 is fully functional and independently
testable — the tap-target/tooltip/keyboard baseline applies project-wide
from the shared theme, the 8 previously-bare controls are covered, and
both confirmed undocumented sub-48dp controls (income_screen.dart,
account_screen.dart) are fixed.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation across all three stories together.

- [X] T027 [P] Run `dart format --output=none --set-exit-if-changed lib
  test` across the whole repository; fix any formatting issues found.
  **Result**: 0 files changed.
- [X] T028 Run `flutter analyze`; confirm zero errors and zero warnings
  (constitution Principle I). Additionally (`/speckit-analyze` finding
  U1, FR-002): `grep -rnE 'Platform\.is|kIsWeb|defaultTargetPlatform'
  lib/core/router/app_router.dart lib/core/widgets/adaptive_body.dart
  lib/core/theme/app_layout.dart` and confirm it finds nothing — this
  feature's layout decisions must be driven only by `windowSizeClassFor`/
  `MediaQuery`, never by a platform check. **Result**: 0 issues; grep
  found nothing.
- [X] T029 Run the full `flutter test` suite; confirm every pre-existing
  test still passes (no regression from T001's baseline) and every new
  test from T004, T009–T012, T016–T018, T022–T026 passes (spec.md SC-005).
  **Result**: 413/413 passing (386 baseline + 27 new).
- [X] T030 Manually walk through [quickstart.md](./quickstart.md)'s 9
  verification steps (ideally including a real resizable desktop/web
  browser window for steps 4–5's live-resize and state-preservation
  checks, which a widget test can approximate but not fully replace).
  **Result — partial, documented honestly rather than skipped silently**:
  - `flutter build web` (with placeholder `--dart-define`s) **succeeds
    cleanly** — a genuine, additional signal beyond `flutter analyze`/
    `flutter test` (both VM-based), confirming this feature's code
    compiles correctly for the Web target specifically. The build's own
    warnings (a wasm-compat note about `flutter_secure_storage_web`'s
    `dart:html` usage, a missing-CupertinoIcons-font note) are
    pre-existing and unrelated to this feature.
  - A live in-browser walkthrough (serving that build via a local HTTP
    server, driving it with the pre-installed Chromium via Playwright)
    was attempted for steps 1–2 (compact/expanded rendering) but could
    not complete: Flutter Web's default CanvasKit renderer fetches its
    runtime from `www.gstatic.com`, and this session's egress proxy
    returns a `403` for that host with reason `connect_rejected
    (organization policy)` — confirmed directly, not assumed. Per this
    environment's own proxy guidance, an explicit organization-policy
    403 is not something to retry or route around, so this was not
    pursued further (e.g. via a locally-bundled-CanvasKit build
    configuration) — that remains a genuine gap for whoever next has
    a network policy allowing it, or a non-cloud environment.
  - Steps 3, 6–9 (auth-gated interaction, hover, keyboard) have the same
    live-browser limitation, compounded by no live Supabase test account
    being available in this session either way.
  - **Every interaction quickstart.md's 9 steps describe is still
    covered by an automated test that exercises the real production
    widget tree**, not a mock: step 1/2 → T009/T010; step 3 → T012;
    step 4 → T009/T010 (the same resize mechanism, asserted
    structurally); step 5 → T011 (`identical()` on the real
    `OverviewScreen`'s `Element`); step 6 → T016–T018; step 7 → T025;
    step 8 → T026; step 9 → T024. This is not a substitute for a human
    actually dragging a browser window and confirming it *feels* right —
    that remains open for the user (or a future session with network
    access to `gstatic.com`, or a native mobile/desktop run) to do.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Setup. **Blocks User Story 1 and
  User Story 2** (both need `app_layout.dart`; both stories' own tests need
  the pinned default surface size to mean what they assert). Does **not**
  block User Story 3, which may start in parallel with Phase 2 if staffed.
- **User Story 1 (Phase 3)**: Depends on Foundational. No dependency on
  User Story 2 or 3.
- **User Story 2 (Phase 4)**: Depends on Foundational. No dependency on
  User Story 1 or 3.
- **User Story 3 (Phase 5)**: No dependency on Foundational, User Story 1,
  or User Story 2 — can start immediately after Setup (see T025's note on
  deliberately avoiding a hidden rail dependency, and T026's use of the
  existing `NavigationBar` rather than the new rail).
- **Polish (Phase 6)**: Depends on all three user stories being complete.

### Within Each Story

- User Story 1: T005 → T006 → T007 (needs T002, T005, T006) → T008 → T009
  → T010 → T011 (T009–T011 share one file, strictly sequential); T012 can
  run any time after T008.
- User Story 2: T013 first; T014, T015, T016 can all start once T013 is
  done (three different files); T017 after T014; T018 after T015.
- User Story 3: T019 → T020 (same file); T021, T022, T023 are each
  independent of T019/T020 and of each other (three different files);
  T024 after T019+T020; T025 after T021; T026 after T025 (same new file).

### Parallel Opportunities

- T002 and T003 (Foundational) — different files, no shared dependency.
- T014, T015, and T016 (User Story 2) — three different files, all depend
  only on T013.
- T021, T022, and T023 (User Story 3's three independent fixes) can all
  run in parallel with each other and with T019/T020 — five different
  files, no shared dependency.
- User Story 3 (Phase 5) as a whole can run in parallel with Foundational/
  User Story 1/User Story 2, since it has no dependency on any of them.

---

## Parallel Example: Foundational + User Story 3 kickoff

```bash
# Once Setup (T001) is done, these can all start together:
Task: "Create lib/core/theme/app_layout.dart with WindowSizeClass etc. (T002)"
Task: "Create test/flutter_test_config.dart pinning the default surface size (T003)"
Task: "Add visualDensity/materialTapTargetSize override to AppTheme.light (T019)"
Task: "Fix the 8 icon-only controls lacking a tooltip (T021)"
Task: "Fix income_screen.dart's 44x44 delete button to 48x48 (T022)"
Task: "Fix account_screen.dart's 28px-tall tab control to 48dp (T023)"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001).
2. Complete Phase 2: Foundational (T002–T004) — blocks US1.
3. Complete Phase 3: User Story 1 (T005–T012).
4. **STOP and VALIDATE**: run User Story 1's Independent Test manually
   (quickstart.md steps 1–5) — the navigation shell alone already answers
   the original "web and mobile look identical" complaint's most visible
   symptom.
5. Ship/demo if ready — User Story 2 and 3 are additive, not required for
   User Story 1's value to land.

### Incremental Delivery

1. Setup + Foundational → foundation ready.
2. User Story 1 → independently test → ship (MVP).
3. User Story 2 → independently test → ship.
4. User Story 3 → independently test → ship (or ship alongside either of
   the above, since it has no dependency on them).
5. Polish (Phase 6) once all three are in.

---

## Notes

- [P] tasks touch different files and have no incomplete-task dependency
  between them.
- [Story] labels map every Phase 3–5 task to US1/US2/US3 for traceability
  back to spec.md.
- Every one of T021's 8 fixes reuses an already-existing localized string —
  no ARB/`flutter gen-l10n` step is needed for this feature. T022/T023 are
  pure `BoxConstraints` value changes — no ARB step either.
- SC-001's full 320–2560 logical-pixel range is not walked point-by-point
  by any single task — T004's boundary-value tests (at every breakpoint)
  combined with T009/T010's representative compact/expanded renders
  jointly establish correctness across the whole range, since
  `windowSizeClassFor` is a simple monotonic threshold classifier (spec.md
  Assumptions; `/speckit-analyze` finding G4). This is a deliberate
  boundary+spot-check strategy, not a gap.
- This feature introduces no new route, no new repository method, and no
  database change — nothing here should touch `lib/core/database/`,
  `lib/core/network/`, or any `*_repository*.dart` file. If a task seems to
  require one, stop and re-check against plan.md's Constitution Check
  before proceeding.
- Commit after each task or logical group, per this repository's existing
  practice.
