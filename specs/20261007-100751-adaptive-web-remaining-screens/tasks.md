# Tasks: Adaptive Web Layout for the Remaining Screens

**Input**: Design documents from `specs/20261007-100751-adaptive-web-remaining-screens/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Included. Constitution Principle II requires tests in the same pull request as the behavior, and every screen with a breakpoint-dependent layout needs widget coverage at a compact (<600dp) and an expanded (≥840dp) width. Pure logic tests (gutter, entry layout, key mapping) are written first and must be seen failing before the code that satisfies them.

**Organization**: One phase per user story, in the clarified delivery order: US1 (P1, MVP, Chi tiêu) → US2 (Thu nhập) → US3 (Thu chi) → US4 (Kế hoạch + pop-ups) → US5 (Hồ sơ) → US6 (placeholders) → US7 (final sweep). Each story is its own pull request (plan.md "Delivery slices"); a story's tasks never depend on a later story's tasks. Phase 2 (shared primitives) ships inside the US1 pull request.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: US1–US7 (Setup, Foundational and Polish phases carry no story label)
- File paths are exact, per plan.md's Project Structure

## Path Conventions

Single Flutter project (existing structure). Commands run from the repository root `/Users/phuchuynh/finance`.

**Format rule**: run `dart format <file>` on every file you create or edit, so `dart format --output=none --set-exit-if-changed lib test` stays at exit 0.

**New-text rule**: this feature adds exactly one user-visible string, the delete key's tooltip and label (T016, FR-014 and constitution Principle III). Every other label reuses an existing string (for example the Kế hoạch reorder handle reuses `expenseControlReorderSemantic`). Any further string that turns out to be unavoidable goes into `lib/core/l10n/app_vi.arb` (primary) and `app_en.arb` together with an `@key` description, then `flutter gen-l10n`, keeping the regenerated `lib/core/l10n/app_localizations*.dart` (tracked).

**Widget-test rule**: the default view is pinned to 410×864 by `test/flutter_test_config.dart`. Every adaptive test sets its own size with `tester.view.physicalSize = const Size(w, h)`, `tester.view.devicePixelRatio = 1.0` and `addTearDown(tester.view.reset)`, and runs the layout assertions in light **and** dark (`AppTheme.light` / `AppTheme.dark`). New adaptive tests use the shared fixtures of T008 (`test/support/expense_control_fixtures.dart`) instead of copying a private fake; existing test files are left as they are. In the real shell the navigation rail (83 dp) takes width from the screen while `MediaQuery` still reports the window width, so any test at a window ≥ 600 dp that checks centering, widths or the 640 dp budget wraps the screen with `withRail` (T008) in addition to any no-rail case.

**Compact-unchanged rule** (FR-002, SC-005): the existing tests of every changed screen must pass with no edit. There are exactly two permitted exceptions. The first (US1): `test/widget/features/expenses/expense_screen_test.dart` pins an 800×1400 surface purely to get height (`_useTallSurface`, line ~113), and 800 dp is now "wide"; if (and only if) a test there fails because of the wide layout, change that helper's size to `Size(410, 1400)`, touch nothing else, and record the change in `verification/README.md`. The second (US7, T080–T082): four existing assertions encode the old `AdaptiveBody`-around-the-list structure of finished screens (`overview_screen_test.dart` and `report_screen_test.dart` measure `find.byType(ListView)` as 960 wide at x = 120; `transaction_history_screen_test.dart` measures the scroll view's width in the empty state and finds a `ConstrainedBox` under `AdaptiveBody` in the error state) and cannot hold once the scroll view spans the viewport; each is re-pointed to the equivalent content measurement with the same intent (content ≤ 960 and centered) in the same pull request, and the change is listed in the pull request description. Everything else in those files stays untouched. A third exception was added at the owner's request after the device review: the headers of Thu chi and of the placeholders now use the shared `PageTitle` (icon chip, left-aligned), so their compact look changes on purpose, and `not_available_placeholder_screen_test.dart` was given the app theme and a two-part icon assertion; the bottom bar's labels are drawn at no more than 110 % text scale (`app_router.dart`). Separately, FR-002's "behaves exactly as today" has one intentional, invisible exception at every width: the delete key `⌫` gains a screen-reader label and a hover/long-press tooltip (T016, T019); no sizes, positions or taps change.

**Pull-request description rule** (constitution Development Workflow): every pull request that touches `core/` (tokens, widgets, theme, router) or a finished screen says so explicitly in its description; the gate task of each such story (T028, T057, T088) repeats this.

**Browser-verification rule**: throwaway Playwright scripts live in the session scratchpad (never committed); the QA account is read from `.env.test-credentials` inside the script and is never printed; nothing here changes a password; `.env`'s database/service keys are never read. Results go into `specs/20261007-100751-adaptive-web-remaining-screens/verification/README.md` as text tables. **No screenshots are committed**: view them, then delete the PNGs before committing.

**Android/iOS tool-churn note**: building for iOS or Android can modify tracked platform files; restore with `git checkout -- ios android` before committing anything unrelated.

---

## Phase 1: Setup

**Purpose**: Confirm the starting point and record the "before" evidence.

- [X] T001 Confirm the starting state: `git branch --show-current` prints `20261007-100751-adaptive-web-remaining-screens`; `flutter --version` reports Flutter 3.47.x; `git status --short` shows only Spec Kit files (`.specify/feature.json`, `CLAUDE.md`, `specs/20261007-100751-adaptive-web-remaining-screens/`); `flutter analyze` shows only the 2 existing `onReorder` infos; `flutter test` is green. Record the test count in the verification README header (create `specs/20261007-100751-adaptive-web-remaining-screens/verification/README.md` with a title and a "Baseline" line).
- [X] T002 Confirm the local-only inputs exist (never committed): `tool/env.json` (public Supabase values) and `.env.test-credentials` (QA account keys `TEST_ACCOUNT_EMAIL`, `TEST_ACCOUNT_PASSWORD`); confirm a Playwright environment works (the session scratchpad has `venv/` with `playwright` and `lib_app.py` helpers `open_app`, `login`, `tap`, `tap_xy`; if missing, create a venv and `pip install playwright`, using `channel="chrome"`). Confirm `flutter build web --dart-define-from-file=tool/env.json` succeeds and `build/web` can be served on a free port.
- [X] T003 Capture the "before" evidence from the unchanged tree (scratchpad only): with a throwaway script, record as text, for Chi tiêu, Thu nhập, Thu chi, Kế hoạch, Hồ sơ and Thông báo, the `flt-semantics` boxes (role, label, x, y, width, height) at 412×915 (the compact baseline for SC-005) and at 1440×900 (the wide "before"). Save as JSON in the scratchpad (`baseline_412.json`, `baseline_1440.json`); summarize the six wide measurements (for example Chi tiêu keys 435×198 px) in `verification/README.md` under "Before".

**Checkpoint**: Clean, known starting point with measured baselines.

---

## Phase 2: Foundational (shared layout primitives)

**Purpose**: The bounding primitive every story uses (research Decision 1, `contracts/adaptive-layout-primitives.md`). Delivered in the US1 pull request; no story can start before it.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T004 [P] Write the failing unit test `test/unit/core/theme/adaptive_gutter_test.dart` for `adaptiveGutterFor`: every row of the behavior table in `contracts/adaptive-layout-primitives.md` (412/412 → 18; 839.9/757 → 18; 840/757 → 18; 1440/1357 → 198.5; 2560/2477 → 758.5; 600/517 with `maxWidth: 520, activatesAt: medium` → 18; 1000/917 with the same → 198.5; 599.9/599.9 with the same → 18), plus properties: the result is never below `minGutter`, equals `minGutter` below the activation class, and is non-decreasing in `viewportWidth`. Run it and confirm it fails (the function does not exist yet).
- [X] T005 [P] Write the failing widget test `test/widget/core/widgets/adaptive_gutters_test.dart`: (a) at 412 the builder receives 18; (b) at 1440 (no rail in this case) it receives 240 for the default 960 width; (b2) with the shell's rail simulated inline as `Row[SizedBox(width: 83), Expanded(AdaptiveGutters(…))]` (`MediaQuery` still reports the 1440 window) it receives 198.5, and with `maxWidth: 520, activatesAt: WindowSizeClass.medium` in a 600 window with the rail (517 dp viewport) it receives 18; (c) with `maxWidth: 520, activatesAt: WindowSizeClass.medium` and no rail it receives 18 at 599 and 140 at 800; (d) resizing 1440 → 412 → 1440 keeps a `StatefulWidget` child's counter (same-shape proof: no remount); (e) the widget adds no `Center` or `ConstrainedBox` of its own (`find.descendant(of: find.byType(AdaptiveGutters), matching: …)` finds none when the builder returns a plain `SizedBox`). Run it and confirm it fails.
- [X] T006 Add to `lib/core/theme/app_layout.dart`: `AppLayoutTokens.entryContentMaxWidth = 520` and `AppLayoutTokens.screenGutter = 18` (with doc comments citing research Decision 2), and the pure function `adaptiveGutterFor({required double windowWidth, required double viewportWidth, double maxWidth = AppLayoutTokens.contentMaxWidth, WindowSizeClass activatesAt = WindowSizeClass.expanded, double minGutter = AppLayoutTokens.screenGutter})` per `data-model.md` §1.2. Make T004 pass.
- [X] T007 Create `lib/core/widgets/adaptive_gutters.dart`: `AdaptiveGutters` per `contracts/adaptive-layout-primitives.md` (`LayoutBuilder` + `MediaQuery.sizeOf(context).width`, calls `adaptiveGutterFor`, passes the number to `builder`, adds no layout widget). Doc comment: why it exists next to `AdaptiveBody` (the wheel dead zone, research Decision 1). Make T005 pass.
- [X] T008 [P] Create shared test fixtures `test/support/expense_control_fixtures.dart`: a public `FakeExpenseControlRepository` (the same behavior as the private fakes in `test/widget/features/expenses/expense_screen_test.dart` and `income_screen_test.dart`: `watchAll`, `getAll`, no-op writes, `recordExpense` recording `recordExpenseCallCount`/`lastItemId`/`lastAmount` with an optional gate, `applyIncomeAllocation` recording deltas), helpers `leafItem(id, {name, balance, parentId})` and `groupWithChildren(...)`, `accounts(int count, {int nameLength = 7})` (short names such as `Khoản 1` under a short group name such as `Nhóm`, both ≤ 9 characters by default so the spec's "two rows hold at least eight accounts" holds; `nameLength: 14` builds the long-name case), `withRail(Widget child)` that returns `Row[SizedBox(width: 83), Expanded(child)]` to mirror the shell (`MediaQuery` keeps reporting the window width while the screen gets width − 83), and a `wrapForTest(Widget home, {ThemeData theme, Locale locale = const Locale('vi'), List<Override> overrides, bool rail = false})` that builds the `ProviderScope` + `MaterialApp` with `AppLocalizations` delegates used by the existing harnesses.

**Checkpoint**: `flutter test test/unit/core/theme test/widget/core/widgets` green; the primitives and fixtures exist.

---

## Phase 3: User Story 1 - Record an expense on a laptop-sized window (Priority: P1) 🎯 MVP

**Goal**: Chi tiêu shows amount, the 12 pad keys, the account chooser and Save with no scrolling from 600 × 640 dp, works with the physical keyboard, and is unchanged below 600 dp.

**Independent Test**: In 1440 × 900, 1366 × 650 and 1000 × 640 browser windows, record an expense of 100.000 ₫ from a chosen account using only the mouse, then only the keyboard; both succeed with no scrolling, and the compact layout is unchanged.

### Tests for User Story 1 (write first; confirm they fail)

- [X] T009 [P] [US1] Write `test/unit/features/expenses/expense_entry_layout_test.dart` for the not-yet-existing `ExpenseEntryLayout.of(Size)` (data-model §1.3): `isWide` false at 599.9 and true at 600; `keyHeight` is 48 at heights 500 and 640, 56 at 704, 64 at 768, 900 and 1300, and identical at widths 600, 1200, 2560 (it never depends on width); `amountPinned` is false in compact, false in wide mode at heights 390 and 499.9, and true in wide mode at 500 and above (`pinAmountMinHeight == 500`); compact values (`chooserWraps` false, `tabsTopPadding` 16, `saveBottomPadding` 20, `saveHeight` 52, `keyGap` 8) and wide values (`chooserWraps` true, `chooserMaxHeight` 106, `tabsTopPadding` 8, `saveBottomPadding` 12, `saveHeight` 48, `keyGap` 6).
- [X] T010 [P] [US1] Write `test/unit/features/expenses/expense_key_mapping_test.dart` for `expenseKeyActionFor` (contracts/expense-entry-ui.md K1–K7, data-model §1.4) as a table: `'0'`–`'9'` with main-row keys and with numpad keys (`LogicalKeyboardKey.numpad5`, character `'5'`) → `digit`; `Backspace` → `backspace`; `'.'` and `','` → `decimal`; `Enter` and `NumpadEnter` → `save`; any of `ctrl`/`meta`/`alt` held with `'0'` → `null`; letters, `'!'` (Shift+1), arrows, Tab, Escape → `null`.
- [X] T011 [P] [US1] Write `test/widget/features/expenses/expense_screen_adaptive_layout_test.dart` (layout contract L1–L13) using T008's fixtures: (L2) with 8 accounts (`accounts(8)`, names ≤ 9 characters) and a visible preview banner at 600×640 **wrapped in `withRail`** (a 517 dp viewport and a 481 dp panel, exactly as in the shell), 1000×640, 1366×650 and 1440×900, the amount, all 12 keys (`ValueKey('expense-keypad-<k>')`), all chips (`expense-item-chip-<id>`), the banner and Save are fully inside the screen rect and the manual tab's scroll position has `maxScrollExtent == 0`; (L1) the panel is ≤ 520 wide and centered within 1 px at 1440×900 and 1000×700; (L3) key heights at heights 640/704/768/900 follow the formula and are the same at widths 600/1200/2560 and never above 72; (L4) every key, chip, tab and Save is ≥ 48×48; (L5) 16 accounts, and 8 accounts with `nameLength: 14`, keep the chooser at ≤ 106 high and it scrolls on its own controller, with the amount, pad and Save still in the viewport; (L6) at 1000×500 the pad region scrolls while the amount and Save stay in view and every key can be scrolled to and tapped; (L7) at 2560×900 and 1440×1300 the panel stays 520 wide and keys 64 high; (L8) the scan tab at 1440×900 uses the same panel width and its behavior test from `expense_screen_test.dart` still holds; (L9) at 410×864 keys have the 2.2 aspect ratio and the chooser is a horizontal `ListView`; (L11) at 844×390 the amount is not pinned (it scrolls with the pad), Save is pinned and every key and chip can be scrolled to and tapped; (L12) hovering a key, chip, mode tab and Save with a mouse `TestGesture` shows hover feedback and Tab focus shows a focus ring on chips, tabs and Save; (L13) the `⌫` key carries a `Tooltip` whose message is `l10n.expenseKeypadDeleteSemantic` (vi and en) and a semantics node with that label, at 410×864 and at 1440×900; every case in light and dark. Confirm it fails.
- [X] T012 [P] [US1] Write `test/widget/features/expenses/expense_screen_keyboard_test.dart` (K1–K10, K5b) at 1440×900: type `1 0 0 0 0 0` with `tester.sendKeyEvent` → amount text `100.000 ₫` (`ValueKey('expense-amount-display')`); `Backspace` removes the last digit; `.` and `,` change nothing; with an account picked by a pointer tap and a valid amount, `Enter` calls `recordExpense` once with the right item and amount (K4); with no account, `Enter` saves nothing and shows today's error text; the keyboard-only flow: digits, `Tab` to an unchosen chip, `Enter` picks it and does **not** save (K5), the next `Enter` (focus still on that now-chosen chip) saves exactly once (K4); `Tab` to a mode tab or Back and `Enter` activates that control, not Save (K5); the stale-focus flow: `Tab` to a chip, tap a pad key with the pointer, `Enter` saves (K5b: the pointer press returned focus to the panel); two quick `Enter` presses (key repeat included) produce one save (K6); `Ctrl+0` is not consumed (K7: the handler returns `KeyEventResult.ignored`); no key handler is active on the scan tab or under an open dialog (K8); the pad keys are not in the Tab order (K9) and the Tab order is Back → mode tabs → chips → Save (K10). Do not rely on `FocusManager.highlightMode` anywhere. Confirm it fails.
- [X] T013 [P] [US1] Write `test/widget/features/expenses/expense_screen_resize_state_test.dart` (S1–S3): type `1500`, pick the second account, then set `tester.view.physicalSize` 1440×900 → 410×864 → 1440×900: the amount still reads `1.500 ₫`, the same account stays selected, the preview banner still shows; switch to the scan tab and resize across 600: still the scan tab; scroll the pad region at 1000×500, widen to 1440×900: no exception. Confirm it fails or is not yet meaningful.

### Implementation for User Story 1

- [X] T014 [P] [US1] Create `lib/features/expenses/presentation/expense_entry_layout.dart`: the pure `ExpenseEntryLayout` (fields and formula of data-model §1.3 and research Decision 3, `factory ExpenseEntryLayout.of(Size window)`, named constants including `pinAmountMinHeight = 500`, no `BuildContext`). Make T009 pass.
- [X] T015 [P] [US1] Create `lib/features/expenses/presentation/expense_key_mapping.dart`: the sealed `ExpenseKeyAction` (`digit(int)`, `backspace`, `decimal`, `save`) and `expenseKeyActionFor({String? character, required LogicalKeyboardKey key, bool ctrl = false, bool meta = false, bool alt = false})` per data-model §1.4. Make T010 pass.
- [X] T016 [P] [US1] Add the one new user-visible string of this feature, `expenseKeypadDeleteSemantic` (the tooltip and screen-reader label of the number pad's delete key `⌫`, an icon-only control that has neither today; vi "Xóa số cuối", en "Delete last digit"), with an `@expenseKeypadDeleteSemantic` description, to `lib/core/l10n/app_vi.arb` (primary) and `lib/core/l10n/app_en.arb`; run `flutter gen-l10n` and keep the regenerated `lib/core/l10n/app_localizations*.dart`; then extend `test/unit/core/l10n/l10n_key_parity_test.dart` the way the Security feature did: add a list `_adaptiveWebFeatureKeys = ['expenseKeypadDeleteSemantic']` checked exactly like `_securityFeatureKeys` (the key exists in both ARB files and the template has a non-empty `@expenseKeypadDeleteSemantic` description), because that file only verifies descriptions for the keys it lists; this is a deliberate edit to an l10n test, not to a changed-screen test, so it does not touch the compact-unchanged rule. Run the whole file.
- [X] T017 [US1] In `lib/features/expenses/presentation/expense_screen.dart`, bound the whole body (mode-tab strip and the active tab) with `AdaptiveGutters(maxWidth: AppLayoutTokens.entryContentMaxWidth, activatesAt: WindowSizeClass.medium)`: the tab strip uses `Padding(horizontal: gutter, top: layout.tabsTopPadding)`; keep `_isManualTab` in `_ExpenseScreenState`. Below 600 the numbers must equal today's (18 horizontal, 16 top).
- [X] T018 [US1] In `_ManualEntryTab` (same file) restructure into the same-shape slot tree of research Decision 4: `Column[amountSlot, Expanded(ListView[listAmountSlot, pad, eyebrow, chooserSlot, banner, error]), Save]`, where when `layout.amountPinned` `amountSlot` holds the amount block (pinned) and `listAmountSlot` is `SizedBox.shrink()`, and the reverse otherwise (compact, or wide and shorter than `pinAmountMinHeight`); the amount block keeps `ValueKey('expense-amount-display')`; wide mode reduces its vertical padding 8 → 4. Make the list and the pinned bars use the gutter. Compact structure/sizes stay byte-for-byte today's.
- [X] T019 [US1] In `_Keypad` (same file) replace `GridView.count(childAspectRatio: 2.2)` with a `GridView` whose `SliverGridDelegateWithFixedCrossAxisCount` uses `mainAxisExtent: layout.keyHeight` and `layout.keyGap` in wide mode and the current `childAspectRatio: 2.2`/8 gaps in compact; vertical padding 14 → 6 in wide mode; set `canRequestFocus: false` on each key's `InkWell` and wrap the keys in `ExcludeFocus` (K9) without changing their semantics or `expense-keypad-<key>` keys; give the `⌫` key a `Tooltip(message: l10n.expenseKeypadDeleteSemantic, excludeFromSemantics: true)` (so a screen reader does not announce the string twice) and a `Semantics(button: true, label: l10n.expenseKeypadDeleteSemantic)` (L13), so the icon-only control is labelled for the mouse and for screen readers at every width (needs the string of T016).
- [X] T020 [US1] In `_ManualEntryTab` (same file) make the chooser slot width-dependent: compact keeps the 54 dp horizontal `ListView.separated`; wide renders a new small stateful widget `_WrappingAccountChooser` that owns its own `ScrollController` (disposed in `dispose`) and builds `ConstrainedBox(maxHeight: layout.chooserMaxHeight)` → `Scrollbar(controller: c)` → `SingleChildScrollView(controller: c, primary: false)` → `Wrap(spacing: 8, runSpacing: 6)` of the same `_ItemChip`s (same keys, `minHeight` 50), so a chip focused by Tab scrolls into view (L5) and the scroll bar never attaches to the tab's outer `ListView` (research Decision 4, chooser implementation note). Only this slot may remount across the 600 dp boundary.
- [X] T021 [US1] In `_ManualEntryTab` (same file) pin Save below the scroll region in the shared gutters (`layout.saveHeight`, `layout.saveBottomPadding`, top padding 8 in wide mode), keep the preview banner and the error text in the scrolling list, and apply the budget of research Decision 3. Do not change Save's behavior or label.
- [X] T022 [US1] Add the keyboard layer to `_ManualEntryTab` (same file): one `Focus(autofocus: true, onKeyEvent: …)` with its own `FocusNode` around the tab content; map `KeyDownEvent`/`KeyRepeatEvent` through `expenseKeyActionFor` (use `event.character`, `HardwareKeyboard.instance` for modifiers) to the existing controller calls (`appendDigit`, `backspace`, `save`); `decimal` consumes the key and does nothing; `save` ignores `KeyRepeatEvent`; Enter follows research Decision 5 and contract K4/K5 and is decided by the focus target only: with the primary focus on the panel node or on no control, or on an `_ItemChip` whose `selected` is true (found with `primaryFocus?.context?.findAncestorWidgetOfExactType<_ItemChip>()`), it saves; with the primary focus on any other control (an unchosen chip, a mode tab, Save, Back) it returns `KeyEventResult.ignored` so that control activates itself; wrap the tab content in a `Listener(onPointerDown: …)` that requests focus on the panel node (K5b); return `ignored` for everything unmapped and for modified keys. Make T012 pass.
- [X] T023 [US1] Give `_ScanTab` (same file) the same gutters and panel width as the manual tab with no behavior change (L8).
- [X] T024 [US1] Run T011–T013 and the existing `test/widget/features/expenses/expense_screen_test.dart`; apply the first permitted exception (the `_useTallSurface` viewport adjustment) only if a failure is caused by the wide layout (see the Compact-unchanged rule), and note it in `verification/README.md`.
- [X] T025 [US1] Budget calibration (research Decision 3): at 1000×640 with 8 accounts and the preview banner showing, measure the real layout in the widget test (T011) and in Chrome; trim paddings in the order tab strip 8 → 6, banner margin, eyebrow spacing until `maxScrollExtent == 0`; if it still overflows, move the banner into the pinned area above Save. Never go below 48 dp for a key or chip. Write the final numbers into `research.md` Decision 3's table and into `ExpenseEntryLayout`'s constants.
- [X] T026 [US1] Real-browser verification of Chi tiêu (quickstart §2, row 1) with a throwaway script: at 1440×900, 1366×650, 1000×640 and 600×640 with the QA account's 7 accounts, assert every control is inside the viewport (the `flt-semantics` boxes of the 12 keys, chips, Save) and that the `⌫` key now exposes the label "Xóa số cuối" (it was missing from the labelled nodes before T016/T019) and shows its tooltip on hover, click `1 0 0 0 0 0` and confirm the display reads `100.000 ₫`, pick an account but do not save, recording the wall-clock time of the flow (8 clicks, must be < 30 s); then repeat with the keyboard only (digits, `Tab` to a chip, `Enter` picks it, `Enter` saves) and time it (< 30 s), confirming `100.000 ₫` before the final Enter; press Save exactly once in the whole pass, in the keyboard run, after Backspace-ing the amount down to `1.000 ₫` (the QA account's data is real test data in the shared project: note the created transaction in the README and remove it through the app if the app offers a delete for it); at 1000×500 confirm the region scrolls with the amount and Save in view; at 844×390 confirm the amount scrolls with the pad, Save stays pinned and every key is usable; resize 1440 → 412 → 1440 mid-entry (S1, S2); zoom emulation 720×450; light and dark; wheel over x = 150. Record pass/fail and the two timings per row in `verification/README.md` ("US1"); delete any screenshots.
- [X] T027 [US1] Compact regression for Chi tiêu: compare 412×915 in Chrome against the T003 baseline (key and chip positions, chooser strip) and check the screen on the Android emulator (Pixel_10) and the iOS simulator (iPhone 17): keys, chooser strip, Save, entering an amount. Record "no difference" (or the difference and its fix) in `verification/README.md`.
- [X] T028 [US1] Gate: `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze` (only the 2 existing infos), full `flutter test` green. Tick the US1 tasks; list in the verification README the contract rows L1–L13, K1–K10, K5b, S1–S4 each with its evidence. When the pull request is opened, its description lists the `core/` changes it makes (new tokens and `adaptiveGutterFor` in `core/theme/app_layout.dart`, `core/widgets/adaptive_gutters.dart`) as the constitution's Development Workflow requires.

**Checkpoint**: US1 is shippable alone (pull request 1 = Phase 2 + Phase 3). Chi tiêu is fully usable on a laptop window with mouse or keyboard.

---

## Phase 4: User Story 2 - Record income on a wide window (Priority: P2)

**Goal**: Thu nhập sits in a bounded 520 dp column; each name is beside its amount; typed values survive resizes; compact unchanged.

**Independent Test**: At 1440 × 900, add two income sources, type their amounts with the keyboard and save; the task fits a bounded column with each name beside its amount.

### Tests for User Story 2

- [X] T029 [P] [US2] Write `test/widget/features/expenses/income_screen_adaptive_test.dart` using T008's fixtures and the harness pattern of `income_screen_test.dart` (I1–I8): at 1440×900 the total, eyebrow, rows, add-source button and Save share one column ≤ 520 wide, centered within 1 px; at an 840 window wrapped in `withRail` the column is centered within 1 px of the 757 dp viewport; each row's name-to-amount distance ≤ 520; with 12 sources at 1440×500 the list scrolls (a mouse-wheel `PointerScrollEvent` over the left gutter moves it) and Save stays pinned and reachable; typing amounts updates the total; typed amounts, total and focus survive 1440 → 410 → 1440 (rows are not remounted); the empty state is bounded and centered; at 410×864 the layout matches today's paddings (18); a mouse `TestGesture` over an amount field, the add-source button and Save shows hover feedback and Tab focus shows a focus ring (I8). Light and dark. Confirm it fails.

### Implementation for User Story 2

- [X] T030 [US2] In `lib/features/expenses/presentation/income_screen.dart` wrap the non-empty body in `AdaptiveGutters(maxWidth: AppLayoutTokens.entryContentMaxWidth, activatesAt: WindowSizeClass.medium)`: the `ListView` takes the gutter as its horizontal padding (top 20, bottom 20 as today) and the pinned Save bar takes the same gutter; do not touch the row widgets, controllers or formatters. Keep the empty state centered in the same bounds. Make T029 pass.
- [X] T031 [US2] Run the existing `test/widget/features/expenses/income_screen_test.dart` and confirm it passes unmodified.
- [X] T032 [US2] Real-browser verification (quickstart §2, row 2): at 1440×900, 1440×500 and 412×915, type two amounts and confirm the total (do not press Save: it would change the QA account's balances in the shared project), resize to 412 and back, confirm the typed values survive, check the 520 column and the wheel at x = 150; light and dark. Record in `verification/README.md` ("US2").
- [X] T033 [US2] Compact regression for Thu nhập (Chrome baseline of T003, Android, iOS), recorded as text.
- [X] T034 [US2] Gate (format, analyze, full `flutter test`); tick the US2 tasks and the I1–I7 evidence rows.

**Checkpoint**: US2 is shippable alone (pull request 2).

---

## Phase 5: User Story 3 - Use the Thu chi hub on a wide window (Priority: P3)

**Goal**: The Thu chi hub is one bounded column with side-by-side entry buttons and readable balance rows.

**Independent Test**: At 1440 × 900 the hub shows two entry buttons (48–72 dp high, each at most half the column) side by side, the history link and the balances in a bounded column.

### Tests for User Story 3

- [X] T035 [P] [US3] Write `test/widget/features/expenses/spending_screen_adaptive_test.dart` using the harness of `spending_screen_test.dart` (H1–H8): column ≤ 960 and centered within 1 px at 840, 1440 and 2560 (each also wrapped in `withRail`); at 600–839 (wrapped in `withRail`) the content width is the viewport (window − 83) minus 36; the two entry buttons are side by side, 64 high, each ≤ 50 % of the column at 600/840/1440/2560; a long account name (60 chars) and a 12-digit balance do not overflow at 320 and 1440; hover (a mouse `TestGesture` pointer) over a balance row shows a tint and a `Focus` traversal shows a focus ring; a wheel event over the left gutter scrolls a long balance list; groups expand and collapse; compact paddings equal today's. Light and dark. Confirm the width and wheel cases fail.

### Implementation for User Story 3

- [X] T036 [US3] In `lib/features/expenses/presentation/spending_screen.dart` wrap the body in `AdaptiveGutters()` (960 dp from `expanded`): the fixed header block (entry buttons, history link) and the balance list use the gutter as horizontal padding (today's 18 below 840). Do not change the buttons' size, labels or `context.push` targets. Make the width and wheel cases of T035 pass.
- [X] T037 [P] [US3] Audit hover and keyboard focus of `lib/features/expenses/presentation/widgets/balance_group_card.dart` and `balance_item_row.dart` against T035; where a tappable row or header lacks hover tint or a focus indication, add it with the theme's `InkWell` hover/focus colors (no hardcoded color) and keep a ≥ 48 dp target. Make the hover/focus cases of T035 pass.
- [X] T038 [US3] Run the existing `spending_screen_test.dart`, `balance_group_card_test.dart` and `balance_item_row_test.dart`; they pass unmodified.
- [X] T039 [US3] Real-browser verification (quickstart §2, row 3) at 600, 840, 1440 and 2560 wide: buttons side by side and 64 high, column centered, hover, each entry point opens and Back returns, wheel at x = 150; light and dark. Record ("US3").
- [X] T040 [US3] Compact regression for Thu chi (Chrome baseline, Android, iOS), recorded as text.
- [X] T041 [US3] Gate (format, analyze, full `flutter test`); tick the US3 tasks and the H1–H8 evidence rows.

**Checkpoint**: US3 is shippable alone (pull request 3).

---

## Phase 6: User Story 4 - Plan spending on a wide window (Priority: P4)

**Goal**: Kế hoạch is a bounded column where each item's name and allocation box are side by side, every action still works, and every pop-up in the app is centered and ≤ 560 dp with sensible Enter/Escape behavior.

**Independent Test**: At 1440 × 900, expand a group, edit an item through its pop-up, add an item, reorder two groups and delete an item; each action works and the layout stays bounded.

### Tests for User Story 4

- [X] T042 [P] [US4] Write `test/widget/core/theme/dialog_constraints_test.dart`: with `AppTheme.light` and `AppTheme.dark` at 1440×900, an `AlertDialog` whose content is a 2000-wide `SizedBox` renders ≤ 560 wide and centered, and at 410×864 stays within the window; the minimum width is 280. Confirm it fails.
- [X] T043 [P] [US4] Write `test/widget/features/expense_control/expense_control_adaptive_test.dart` using T008's fixtures and the harness of `expense_control_screen_test.dart` (P1–P10): at 1440 and 2560 the banner, group cards, dashed add button, summary banner and pending-changes block are one column ≤ 960 and centered within 1 px; at 1440 an item row's allocation box (`ExpenseFormulaLabel`) is ≤ 200 wide, 40 high, sits between the name and the edit button, and the right edges of the boxes of different rows align (P3); at 410 the box stays below the name; a top-level leaf's header shows its box inline at 1440; the pending-changes Save is ≤ 360 wide and centered at 1440, full width at 410 (P4); 60-character names ellipsize without moving the box; a 12-digit fixed amount fits or ellipsizes at the box edge (P8); expand/collapse, add child, delete leaf and reorder (`ReorderableDragStartListener` drag) work at 410, 840 and 1440 (P5); expanded groups and pending edits survive 1440 → 410 → 1440 (P9); wheel over the left gutter scrolls (P6); hover over the group header shows feedback, icon buttons keep tooltips, and the reorder drag handle shows a tooltip equal to the existing `expenseControlReorderSemantic` text (P7). Light and dark. Confirm it fails.
- [X] T044 [P] [US4] Write `test/widget/features/expense_control/expense_control_dialogs_test.dart` (D1–D4, D8): the item form is centered and ≤ 560 wide at 1440×900 and fully visible at 410×864; initial focus is the name field; `Enter` in the last field submits only when the Save button would be enabled and does nothing when invalid; `Escape` closes it; the delete-group confirmation focuses **Cancel** initially, `Enter` cancels and deletes nothing, and `Escape` cancels; resizing while a dialog is open keeps it centered and visible with its typed text. Confirm it fails.
- [X] T045 [P] [US4] Write `test/widget/core/router/app_shell_discard_prompt_focus_test.dart` (D7) following the harness of `test/widget/core/router/app_shell_discard_prompt_test.dart` (new file; leave that one untouched): the discard-changes prompt is ≤ 560 wide at 1440, focuses the safe option ("keep editing") initially, `Enter` keeps editing, `Escape` keeps editing. Confirm it fails.
- [X] T046 [P] [US4] Write `test/widget/features/account/biometric_enable_prompt_dialog_test.dart` (D6): the biometric offer is ≤ 560 wide at 1440, focuses its primary button initially, `Enter` confirms, `Escape` behaves as the existing "not now" dismissal (read `biometric_enable_prompt.dart` first and assert today's result for dismissal). Confirm it fails or documents the current behavior.

### Implementation for User Story 4

- [X] T047 [US4] In `lib/core/theme/app_theme.dart` add `dialogTheme: DialogThemeData(constraints: BoxConstraints(minWidth: 280, maxWidth: 560))` to both `AppTheme.light` and `AppTheme.dark` (research Decision 6; no per-call-site wrapper). Make T042 pass; run `test/unit/core/theme/app_theme_test.dart` unmodified.
- [X] T048 [P] [US4] In `lib/features/expense_control/presentation/widgets/expense_item_row.dart` extract the private `_FormulaLabel` into a public `ExpenseFormulaLabel` (same content and 40 dp height, but wrapped in `ConstrainedBox(constraints: BoxConstraints(minWidth: 96, maxWidth: 200))` and left-aligned text inside a box that sizes to content on wide windows; unchanged full-row behavior below 600), and render it inline (name · box · edit · delete) when the window is ≥ 600, below the name otherwise. Keep `ExpenseItemRow`'s public parameters.
- [X] T049 [US4] In `lib/features/expense_control/presentation/widgets/expense_group_card.dart` render a top-level leaf's `ExpenseFormulaLabel` inline in the header row on wide windows (below the name on compact, as today); keep `_expanded` state, the `ValueKey`, drag handle, semantics labels and ≥ 48 dp targets. Add hover/focus feedback to the group header if T043 finds it missing, and give the icon-only reorder drag handle a `Tooltip(message: l10n.expenseControlReorderSemantic(item.name), excludeFromSemantics: true)` (an existing string; its `Semantics` label stays) if T043 finds it without one.
- [X] T050 [US4] In `lib/features/expense_control/presentation/expense_control_screen.dart` wrap `_ScreenContent`'s `ListView` in `AdaptiveGutters()` and use the gutter as its horizontal padding (top 16, bottom 20 as today); leave the 62 dp title strip full-width; bound the pending-changes Save to 360 dp centered on wide windows (full width below 600). Do not touch the `ReorderableListView.builder` configuration. Make T043 pass.
- [X] T051 [US4] In the same file, apply the pop-up contract D3/D4 to `_ItemFormDialog` and the delete-group confirmation: name field `autofocus`; `textInputAction: TextInputAction.done` on the last field with `onSubmitted` calling the same handler as the Save button only when it is enabled (all three only on a desktop platform, `_hasHardwareKeyboard`, found in the device review: on a phone they raised the on-screen keyboard by themselves and made its "done" key save the form); the delete-group confirmation gives its Cancel button initial focus (`autofocus: true`). Make T044 pass.
- [X] T052 [P] [US4] In `lib/core/router/app_router.dart` make the discard-changes prompt (`_DiscardPromptChoice`, line ~252) focus the safe option initially and treat `Escape` as "keep editing" (D7). Make T045 pass; run `app_shell_discard_prompt_test.dart` unmodified.
- [X] T053 [P] [US4] In `lib/features/account/presentation/biometric_enable_prompt.dart` give the primary button initial focus (D6) and keep today's dismissal. Make T046 pass; run its existing tests unmodified.
- [X] T054 [US4] Run the existing `expense_control_screen_test.dart`, `expense_group_card_test.dart`, `expense_item_row_test.dart` and `icon_picker_test.dart` unmodified; fix any compact regression at the source.
- [X] T055 [US4] Real-browser verification (quickstart §2, row 4) at 1440×900 with the QA account's plan: expand a group, open an item's edit pop-up (`Enter`/`Escape` behavior, width ≤ 560), add a test item and delete it (leave the plan as found), drag-reorder two groups and drag them back, delete-group confirmation focuses Cancel; allocation boxes ≤ 200 and aligned; hover and tooltips; wheel at x = 150; resize 1440 → 412 → 1440 with a group expanded and a pop-up open; light and dark. Record ("US4").
- [X] T056 [US4] Compact regression for Kế hoạch and the pop-ups (Chrome baseline, Android, iOS), recorded as text.
- [X] T057 [US4] Gate (format, analyze, full `flutter test`); tick the US4 tasks and the P1–P10, D1–D4, D6–D8 evidence rows. When the pull request is opened, its description lists the `core/` changes it makes (the dialog theme in `core/theme/app_theme.dart`, the discard-prompt change in `core/router/app_router.dart`).

**Checkpoint**: US4 is shippable alone (pull request 4). It also bounds every pop-up app-wide through the theme.

---

## Phase 7: User Story 5 - Use Hồ sơ on a wide window (Priority: P5)

**Goal**: Hồ sơ uses the same column as Bảo mật, so moving between them never shifts the content.

**Independent Test**: At 1440 × 900, Hồ sơ and Bảo mật show their content at the same column width and position (difference ≤ 8 px).

### Tests for User Story 5

- [X] T058 [P] [US5] Write `test/widget/features/account/account_screen_adaptive_test.dart` using the harness of `account_screen_test.dart` and the providers of `security_screen_test.dart` (A1–A8; the 560 dp pop-up bound needs the dialog theme of T047, so ship this story after US4 or include T047): at 840, 1200, 1440, 1600 and 2560 the content column of `AccountScreen` ≤ 960 and centered, and its left edge and width equal those of `SecurityScreen` pumped with the same size within 8 px; at 700 both use the viewport minus 36; the menu rows are ≥ 48 high with hover tint and focus ring; the language pop-up is ≤ 560 wide, focuses the selected language initially, `Enter` confirms and `Escape` dismisses (D5); wheel over the left gutter scrolls at 1440×500; compact paddings equal today's (18). Light and dark. Confirm it fails.

### Implementation for User Story 5

- [X] T059 [US5] In `lib/features/account/presentation/account_screen.dart` wrap the body in `AdaptiveGutters()` and use the gutter as the `ListView`'s horizontal padding (top 20, bottom 20 as today); keep the title strip full-width. Make the width cases of T058 pass.
- [X] T060 [US5] In the same file make the language pop-up (`showDialog`, line ~393) focus the selected language initially and confirm with `Enter` (D5); keep the sign-out and appearance behavior. Add hover/focus feedback to `lib/features/account/presentation/widgets/account_menu.dart` rows if T058 finds it missing. Make T058 pass.
- [X] T061 [US5] Run the existing `account_screen_test.dart` and `security_screen_test.dart` unmodified.
- [X] T062 [US5] Real-browser verification (quickstart §2, row 5): at 840, 1200, 1440, 1600 and 2560 wide measure the content column of Hồ sơ and Bảo mật and confirm the same x and width (SC-007); Hồ sơ → Bảo mật → Back shows no jump; language pop-up Enter/Escape; wheel at x = 150; light and dark. Record ("US5").
- [X] T063 [US5] Compact regression for Hồ sơ (Chrome baseline, Android, iOS), recorded as text.
- [X] T064 [US5] Gate (format, analyze, full `flutter test`); tick the US5 tasks and the A1–A8 and D5 evidence rows.

**Checkpoint**: US5 is shippable alone (pull request 5; depends only on the dialog theme of T047 for D1).

---

## Phase 8: User Story 6 - See intentional "not available yet" pages on a wide window (Priority: P6)

**Goal**: The three placeholder entry points show a centered, bounded message with working Back navigation.

**Independent Test**: At 1440 × 900 each placeholder shows its icon and message centered within the bounded area and Back returns to the previous screen.

### Tests for User Story 6

- [X] T065 [P] [US6] Write `test/widget/core/widgets/not_available_placeholder_screen_adaptive_test.dart` (N1–N4; leave the existing `not_available_placeholder_screen_test.dart` untouched): at 1440 and 2560 the `EmptyStateView` is centered inside a ≤ 960 area; at 320 the message wraps with no overflow exception; at 2560×500 and 320×400 the message scrolls instead of overflowing; the back button has a tooltip and a ≥ 48 dp target. Light and dark. Confirm the bounded-width case fails.

### Implementation for User Story 6

- [X] T066 [US6] In `lib/core/widgets/not_available_placeholder_screen.dart` wrap the `EmptyStateView` in `AdaptiveBody(child: …)` (default 960 dp, activated at `expanded`; the placeholder has no scroll view of its own to span the window, per `contracts/profile-and-placeholders-ui.md`). Make T065 pass; check `lib/core/widgets/empty_state_view.dart` needs no change (it scrolls internally).
- [X] T067 [US6] Run the existing `not_available_placeholder_screen_test.dart`, `empty_state_view_test.dart` and the router tests that open the placeholders unmodified.
- [X] T068 [US6] Real-browser verification (quickstart §2, row 6) at 320 and 1440 wide: Thông báo from the Tổng quan bell and from Hồ sơ, and Trợ giúp; centered, nothing clipped; the back button and the browser Back return to the previous screen. Record ("US6").
- [X] T069 [US6] Compact regression for the placeholder (Chrome baseline, Android, iOS), recorded as text.
- [X] T070 [US6] Gate (format, analyze, full `flutter test`); tick the US6 tasks and the N1–N5 evidence rows.

**Checkpoint**: US6 is shippable alone (pull request 6).

---

## Phase 9: User Story 7 - No screen is left behind at any window width (Priority: P7)

**Goal**: Every screen in the app, finished or not, has been checked across the width range in light and dark, and every defect found is fixed in this feature.

**Independent Test**: For each inventory screen (data-model §3), at widths 320, 412, 600, 840, 1200, 1600 and 2560 in both appearances, and additionally at 412 and 1440 in a 500 dp-high window and at 130 % text size, nothing overflows, clips or overlaps and every scrolling screen scrolls from its margins.

### Tests for User Story 7

- [X] T071 [US7] Create `test/support/adaptive_sweep.dart`: `const sweepWidths = [320.0, 412.0, 600.0, 840.0, 1200.0, 1600.0, 2560.0]`, `const sweepThemes` (light, dark), three case groups `sweepWidthCases` (every width × both themes at height 800, text scale 1.0), `sweepShortCases` (height 500 at widths 412 and 1440, both themes) and `sweepTextCases` (text scale 1.3 at widths 320, 412 and 1440, both themes, height 800), a `pumpScreen(tester, widget, {width, height, textScale, theme, rail})` that pins the view, wraps in `MediaQuery(textScaler: TextScaler.linear(textScale))`, optionally mirrors the rail, pumps, settles, and asserts `tester.takeException() == null`; and an `expectNoDeadZone(tester, finder)` helper that sends a `PointerScrollEvent` at x = 10 and x = width − 10 and checks the scrollable moved.
- [X] T072 [P] [US7] Write `test/widget/core/adaptive_sweep_auth_test.dart`: Đăng nhập, Đăng ký, Quên mật khẩu, Đặt lại mật khẩu and the sign-in lock mode, each across `sweepWidthCases`, `sweepShortCases` and `sweepTextCases` via T071 (providers copied from each screen's own test into `test/support/`; the originals stay untouched); asserts no exception and content width ≤ 450.
- [X] T073 [P] [US7] Write `test/widget/core/adaptive_sweep_overview_report_test.dart`: Tổng quan and Báo cáo across all three case groups (providers copied from `overview_screen_test.dart` and `report_screen_test.dart` into `test/support/`); no exception, column ≤ 960, wheel dead-zone check.
- [X] T074 [P] [US7] Write `test/widget/core/adaptive_sweep_history_test.dart`: Lịch sử giao dịch and Lịch sử theo khoản (the filtered route reuses the same screen) across all three case groups (providers copied from `transaction_history_screen_test.dart`); no exception, column ≤ 960, wheel dead-zone check.
- [X] T075 [P] [US7] Write `test/widget/core/adaptive_sweep_spending_test.dart`: Thu chi, Thu nhập, Chi tiêu (manual and scan) and Kế hoạch across all three case groups with T008's fixtures; no exception; entry screens ≤ 520, others ≤ 960; wheel dead-zone check on the scrolling ones.
- [X] T076 [P] [US7] Write `test/widget/core/adaptive_sweep_account_test.dart`: Hồ sơ, Bảo mật and Đổi mật khẩu across all three case groups (providers copied from `account_screen_test.dart`, `security_screen_test.dart`, `change_password_screen_test.dart`); no exception, column ≤ 960 (Đổi mật khẩu ≤ 450), Hồ sơ and Bảo mật columns equal within 8 px at ≥ 840.
- [X] T077 [P] [US7] Write `test/widget/core/adaptive_sweep_static_test.dart`: the Thông báo / Trợ giúp placeholder (`NotAvailablePlaceholderScreen`) and `StartupErrorApp` (both `StartupFailureReason`s) across all three case groups; no exception, placeholder column ≤ 960.
- [X] T078 [US7] Run T072–T077. Record every failure (screen, width, theme, symptom) in `verification/README.md` under "Sweep log", with the root cause. Expected at least: the wheel dead zone of Tổng quan, Báo cáo and Lịch sử giao dịch.

### Implementation for User Story 7

- [X] T079 [US7] Reproduce the wheel dead zone in Chrome (1440×500, wheel at x = 250 vs x = 720) on Tổng quan, Báo cáo, Lịch sử giao dịch, Lịch sử theo khoản and, as a check, Bảo mật, Đổi mật khẩu and the sign-in screens; record which screens reproduce it in the sweep log.
- [X] T080 [P] [US7] Fix Tổng quan (`lib/features/expenses/presentation/overview_screen.dart`): give the scroll view the whole viewport by replacing `Expanded(AdaptiveBody(ListView(padding: 18…)))` with `AdaptiveGutters` + `ListView(padding: gutter…)`, keeping the same look at every width. In `test/widget/features/expenses/overview_screen_test.dart` only the width test at ~line 709–724 changes: it measured `find.byType(ListView)` as 960 wide at x = 120, which no longer holds because the list is now viewport-wide; re-point it to the list's resolved horizontal padding (`(tester.widget<ListView>(…).padding as EdgeInsets).left == 120`) and the content child's `Rect` (960 wide at x = 120), keeping the intent "content is capped at 960 and centered"; every other assertion stays untouched (this is the second permitted exception to the compact-unchanged rule); extend the sweep case.
- [X] T081 [P] [US7] Fix Báo cáo (`lib/features/expenses/presentation/report_screen.dart`) the same way if T079 reproduced it, and re-point only the equivalent width test in `report_screen_test.dart` (~line 446–461) as in T080.
- [X] T082 [P] [US7] Fix Lịch sử giao dịch and Lịch sử theo khoản (`lib/features/expenses/presentation/transaction_history_screen.dart`) the same way if T079 reproduced it, keeping its same-shape guarantee and virtualized list. In `transaction_history_screen_test.dart` only the assertion at ~line 340–347 (a `ConstrainedBox` under `AdaptiveBody` equals `contentMaxWidth`) changes: re-point it to the content's resolved horizontal inset or `Rect` (960 wide, centered) with the same intent; `transaction_history_performance_test.dart` and every other assertion stay untouched.
- [X] T083 [P] [US7] Fix the sign-in screens and Đổi mật khẩu only if T079 reproduced a dead zone there (their forms may not scroll at all; then record "n/a"): `lib/features/account/presentation/{sign_in,sign_up,forgot_password,reset_password,change_password}_screen.dart`, keeping `authContentMaxWidth` 450 and their tests unmodified.
- [X] T084 [US7] Browser matrix pass (layer 2 of `contracts/final-sweep.md`) over the 18 inventory rows and the pop-ups: widths 320/412/600/840/1200/1600/2560 × heights 915/900/650/640/500 (and 844×390 for Chi tiêu), light and dark: overflow, clipping, centering within 8 px (SC-004), Hồ sơ ↔ Bảo mật alignment (SC-007), keyboard Tab order and visible focus, hover and tooltips on every icon-only control (including Chi tiêu's `⌫` key and Kế hoạch's reorder handle), Escape/Enter in pop-ups, resize mid-task on Chi tiêu/Thu nhập/Kế hoạch (SC-006), zoom 200 % and 400 %. Record each row in the sweep log.
- [X] T085 [US7] Fix every further defect from T078/T079/T084, whatever its size, at the shared source when it comes from shared code (constitution root-cause rule), add a regression test next to each fix, re-run its matrix row, and log "found → fixed (commit/file)". Repeat until the sweep log has no open row.
- [X] T086 [US7] Large-text spot check on the Android emulator (`adb shell settings put system font_scale 1.3`, restore to `1.0` afterwards) for Kế hoạch, Chi tiêu and Hồ sơ at the phone size, complementing the automated 130 % text-size cases of T072–T077 (a browser has no text-scale setting for Flutter web): nothing clipped or overflowing; fix what is found and add a regression test.
- [X] T087 [US7] Compact regression across the six changed screens on the Android emulator and the iOS simulator against the pre-change baseline (SC-005), recorded as text, including the places where this story migrated finished screens (Tổng quan, Báo cáo, Lịch sử).
- [X] T088 [US7] Gate (format, analyze, full `flutter test` with the new sweep files); tick the US7 tasks; the sweep log shows every inventory row passing and no open defect. When the pull request is opened, its description lists the `core/` changes and every finished screen it migrates or fixes (Tổng quan, Báo cáo, Lịch sử giao dịch, and any other defect fixed), and calls out the four re-pointed assertions.

**Checkpoint**: US7 is shippable (pull request 7). No known layout defect remains on any screen.

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Close the feature.

- [X] T089 [P] Re-read `research.md` Decision 3 and `data-model.md` §1.3 against the shipped numbers (T025) and correct any drift; check `quickstart.md` §1's test-file names and `plan.md`'s test tree against the files actually created (`expense_screen_adaptive_layout_test.dart`, `expense_screen_keyboard_test.dart`, `expense_screen_resize_state_test.dart`, `adaptive_sweep_{auth,overview_report,history,spending,account,static}_test.dart`).
- [X] T090 [P] Confirm no secret or image was committed: `git status --short` and `git diff --stat origin/master` show no `.png`/`.jpg`, no `tool/env.json`, no `.env*`; `git diff origin/master | grep -inE "password|secret|service_role"` shows only test-dummy or existing text; no screenshot left in the scratchpad that is referenced by the README.
- [X] T091 Run `quickstart.md` end to end as the final validation (§1 gate, §2 each row, §3 compact) and tick every box of its Done checklist for the whole feature.
- [X] T092 Final report to the owner (in Vietnamese): per story what changed, what was measured before/after, defects found and fixed in the sweep, and any deviation (for example the `_useTallSurface` viewport change if it was needed, and the four re-pointed assertions of the finished screens).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: depends on Setup; **blocks every story** (tokens, `adaptiveGutterFor`, `AdaptiveGutters`, test fixtures).
- **US1 (Phase 3)**: depends on Phase 2. MVP; ships with Phase 2 as pull request 1.
- **US2, US3, US4, US6 (Phases 4, 5, 6, 8)**: each depends only on Phase 2 (US6 on nothing but the existing `AdaptiveBody`); independent of one another and of US1's screen code.
- **US5 (Phase 7)**: depends on Phase 2 **and on T047** (the dialog theme of US4): its test T058 asserts the 560 dp pop-up bound, so US5 ships after US4, or carries T047 itself if it must ship first.
- **US7 (Phase 9)**: depends on US1–US6 being merged (the sweep must see the finished state); T080–T083 can run in parallel with each other.
- **Polish (Phase 10)**: after US7.

### Within Each Story

- Pure-logic and widget tests are written first and seen failing; models/pure classes before widgets; widget changes before the browser pass; the browser pass before the compact regression; the gate last.
- Tasks that edit the same file (`expense_screen.dart`: T017–T023; `expense_control_screen.dart`: T050–T051) are sequential.

### Parallel Opportunities

- Phase 2: T004, T005 and T008 in parallel (three different files); T006 then T007.
- US1 tests T009–T013 in parallel; T014, T015 and T016 in parallel; T017–T023 sequential (one file).
- US4 tests T042–T046 in parallel; T048 and T052/T053 in parallel with each other (different files); T047 before T050.
- US7 T072–T077 in parallel after T071; T080–T083 in parallel.
- Different stories can be built in parallel by different people after Phase 2, but they are delivered one pull request at a time in the clarified order.

### Parallel Example: User Story 1 tests

```text
Task: "Write expense_entry_layout_test.dart"            (T009)
Task: "Write expense_key_mapping_test.dart"             (T010)
Task: "Write expense_screen_adaptive_layout_test.dart"  (T011)
Task: "Write expense_screen_keyboard_test.dart"         (T012)
Task: "Write expense_screen_resize_state_test.dart"     (T013)
```

---

## Implementation Strategy

### MVP First (User Story 1 only)

1. Phase 1 → Phase 2 (primitives, fixtures) → Phase 3 (Chi tiêu).
2. **Stop and validate**: the browser pass of T026 at 1440×900, 1366×650 and 1000×640, plus the compact regression. This is pull request 1 and already removes the worst defect (hidden controls, unusable keyboard).

### Incremental Delivery

1. US2 → US3 → US4 → US5 → US6, one pull request each, each validated alone (full suite, browser, compact).
2. US7 last: the sweep, the shared wheel-dead-zone fix and every other defect it finds.
3. Each pull request is built from `origin/master` after the previous one merges; commit and pull-request creation happen only when the owner asks.

### Task Count Summary

| Phase | Tasks | Parallelizable ([P]) |
|-------|-------|----------------------|
| 1 Setup | 3 | 0 |
| 2 Foundational | 5 | 3 |
| 3 US1 (P1, MVP) | 20 | 8 |
| 4 US2 (P2) | 6 | 1 |
| 5 US3 (P3) | 7 | 2 |
| 6 US4 (P4) | 16 | 8 |
| 7 US5 (P5) | 7 | 1 |
| 8 US6 (P6) | 6 | 1 |
| 9 US7 (P7) | 18 | 10 |
| 10 Polish | 4 | 2 |
| **Total** | **92** | **36** |
