# Quickstart: Verifying the Adaptive Web Layout

**Feature**: `20261007-100751-adaptive-web-remaining-screens` | **Date**: 2026-10-07

How a reviewer (or the implementer, after each story) proves a page is done. Run it per story, in the order of the
stories; each page must pass alone.

## 0. Prerequisites

```bash
flutter pub get                       # Flutter 3.47.5 / Dart 3.13.4
cp tool/env.example.json tool/env.json  # then fill the public URL + publishable key (README "Setup")
```

The QA account lives in `.env.test-credentials` (keys `TEST_ACCOUNT_EMAIL`, `TEST_ACCOUNT_PASSWORD`,
`TEST_ACCOUNT_USER_ID`) and is read only by scripts, never printed. Nothing in this feature changes a password. Never
create accounts in the real project, and never read `.env`'s database/service keys.

## 1. Automated gate (every story)

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test                          # whole suite; the existing compact tests must pass UNMODIFIED
```

Per story, the new tests named in the contracts must exist and pass:

| Story | New tests |
|-------|-----------|
| US1 | `test/unit/core/theme/adaptive_gutter_test.dart`, `test/widget/core/widgets/adaptive_gutters_test.dart`, `test/unit/features/expenses/expense_entry_layout_test.dart`, `…/expense_key_mapping_test.dart`, `test/widget/features/expenses/expense_screen_adaptive_layout_test.dart`, `…/expense_screen_keyboard_test.dart`, `…/expense_screen_resize_state_test.dart` (shared fixtures: `test/support/expense_control_fixtures.dart`) |
| US2 | `test/widget/features/expenses/income_screen_adaptive_test.dart` |
| US3 | `test/widget/features/expenses/spending_screen_adaptive_test.dart` |
| US4 | `test/widget/features/expense_control/expense_control_adaptive_test.dart`, `test/widget/core/theme/dialog_constraints_test.dart`, `…/expense_control_dialogs_test.dart`, `test/widget/core/router/app_shell_discard_prompt_focus_test.dart`, `test/widget/features/account/biometric_enable_prompt_dialog_test.dart` |
| US5 | `test/widget/features/account/account_screen_adaptive_test.dart` |
| US6 | `test/widget/core/widgets/not_available_placeholder_screen_adaptive_test.dart` (new file; the existing `not_available_placeholder_screen_test.dart` is untouched) |
| US7 | `test/widget/core/adaptive_sweep_{auth,overview_report,history,spending,account,static}_test.dart` (helper: `test/support/adaptive_sweep.dart`) |

Every adaptive widget test pins its viewport explicitly (`tester.view.physicalSize` with `devicePixelRatio = 1`) at a
compact width (412 × 915) and an expanded width (1440 × 900), as the constitution requires, plus the extra sizes in the
contracts.

## 2. Real browser, per page

```bash
flutter build web --dart-define-from-file=tool/env.json
python3 -m http.server 5000 --directory build/web          # any static server on a free port
```

Open it in Chrome (or drive it with a scratchpad Playwright script; Flutter exposes `flt-semantics` nodes, and the
`flt-semantics-placeholder` must be clicked once to enable them). Sign in with the QA account (the first press now
navigates). Thu chi is the third item of the rail.

| Page | Sizes (w × h) | What to do | Pass |
|------|---------------|------------|------|
| Chi tiêu | 1440 × 900, 1366 × 650, 1000 × 640, 600 × 640, 1000 × 500, 844 × 390 | with 7 accounts: click `1 0 0 0 0 0`, pick an account, Save (8 clicks); repeat with the keyboard only (digits, Tab to a chip, Enter picks it, Enter saves), timing each flow | all controls visible at once at the first four sizes; the amount reads `100.000 ₫`; each scripted flow < 30 s; at 1000 × 500 the region scrolls and amount + Save stay visible; at 844 × 390 the amount scrolls with the pad and Save stays pinned |
| Thu nhập | 1440 × 900, 1440 × 500, 412 × 915 | type two amounts, add a source, Save; resize to 412 and back | name and amount ≤ 520 dp apart; values survive the resize |
| Thu chi | 600, 840, 1440, 2560 wide | open each entry point and Back | buttons side by side 64 dp high, ≤ half the column; column centered |
| Kế hoạch | 1440 × 900 | expand a group, edit an item in its pop-up, add an item, drag-reorder two groups, delete an item | allocation boxes ≤ 200 dp, aligned; every action works; dialogs ≤ 560 dp; Escape closes |
| Hồ sơ | 840, 1440, 2560 wide | Hồ sơ → Bảo mật → Back | same column x and width on both |
| Placeholders | 320, 1440 | bell on Tổng quan, Hồ sơ → Thông báo / Trợ giúp, Back | centered, no clip |
| Sweep | the matrix of `contracts/final-sweep.md` | every inventory screen | recorded table, no open defect |

Light and dark: repeat the first row of each page in both (`prefers-color-scheme`, or the in-app appearance toggle in
Hồ sơ).

Wheel check (all scrolling pages): move the mouse to x = 150 and to x = window − 150 and scroll; the content must move
exactly as it does over the column.

## 3. Compact regression (every story that touches layout)

Android emulator (Pixel_10) and iOS simulator (iPhone 17): open the changed screen at its normal phone size and confirm
it matches the pre-change build (same positions, same behavior). For Chi tiêu also check the pad keys and the horizontal
chooser strip. Record as text in `verification/README.md`; commit no images.

## 4. Done checklist (per story)

- [x] Contract rows of the story all pass (table in `verification/README.md`).
- [x] `flutter analyze`, `dart format`, `flutter test` green; existing compact tests unmodified (the exceptions are listed in `tasks.md` "Compact-unchanged rule").
- [x] Browser pass at the listed sizes, light and dark; wheel dead-zone check.
- [x] Compact checked on Android and iOS.
- [x] The only new user-visible text is the delete key's label (`expenseKeypadDeleteSemantic`, in both `vi` and `en` ARB files); any other new string needs both too.
- [x] `tasks.md` items checked off.
- [ ] When the pull request is opened, its description lists the `core/` changes it makes (tokens, `AdaptiveGutters`, dialog theme, migrated finished screens) as the constitution's Development Workflow requires.
