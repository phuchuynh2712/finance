# Verification log: Adaptive Web Layout for the Remaining Screens

**Feature**: `20261007-100751-adaptive-web-remaining-screens`

Evidence is recorded as text; no screenshots are committed. Browser runs use throwaway Playwright scripts (Chrome, the QA account read from `.env.test-credentials`, never printed). Nothing here changes a password.

## Baseline (before any change, 2026-10-07)

- Branch `20261007-100751-adaptive-web-remaining-screens`, Flutter 3.47.5.
- `flutter analyze`: 2 existing `onReorder` infos only.
- `flutter test`: **723 passed**.
- Web release build of the unchanged tree, signed in as the QA account; the `flt-semantics` boxes of the six screens were recorded at 412 × 915 (compact baseline for SC-005) and 1440 × 900 (wide "before").

### Before (1440 × 900, rail 83 px, viewport 1357 px)

| Screen | What was measured |
|--------|--------------------|
| Chi tiêu | keys 435 × 198 px (3 per row, 4 rows); bottom pad row and account chooser below the visible area; Save pinned; the amount scrolls out of view when the pad region is scrolled; `⌫` key has no label |
| Thu nhập | rows and Save bar 1321 px wide |
| Thu chi | two entry buttons 656 × 64 px each (full width / 2), history link 1321 px, balance list 1321 px |
| Kế hoạch | cards and allocation boxes ~1271–1321 px wide |
| Hồ sơ | rows 1319–1357 px wide (unbounded) |
| Thông báo | message centered in 1357 px, no bounded area |

## US1 — Chi tiêu (web, Chrome, release build, QA account)

Numbers are from throwaway Playwright scripts reading the `flt-semantics` boxes. The rail takes 83 px, so a window of width W gives the screen a W − 83 px viewport.

### Layout (contract L1–L7, L11, L13)

| Window (w × h) | Keys (12) | Chips (7) | Save | Pad width / key size | Result |
|----------------|-----------|-----------|------|----------------------|--------|
| 1440 × 900 | all inside | all inside | y 840–888 | 520 px, x 501–1021 (centered in the 1357 px viewport), keys 169 × 64 | pass |
| 1366 × 650 | all inside | all inside | y 590–638 | 520 px, keys 169 × 49 | pass |
| 1000 × 640 | all inside | all inside | y 580–628 | 520 px, keys 169 × 48 | pass |
| 600 × 640 (beside the rail, 517 px viewport) | all inside | all inside | y 580–628 | 481 px, keys 156 × 48 | pass |
| 1000 × 500 | all inside | two chips below the fold | y 440–488 | amount pinned; the pad region scrolls | pass (scrolls as designed) |
| 844 × 390 (phone held sideways) | reachable by wheel + click | reachable | y 330–378 | amount scrolls with the pad, Save pinned | pass |
| 720 × 450 (200 % zoom of 1440 × 900) | reachable | reachable | y 390–438 | Save pinned, everything reachable by scrolling | pass |

Dark appearance repeated at 1440 × 900, 1000 × 640 and 600 × 640: same positions, all controls inside the viewport.

### Interaction (K1–K10, S1–S2)

| Check | Result |
|-------|--------|
| Mouse: click `1 0 0 0 0 0`, pick an account | amount `100.000 ₫`, banner shown, 8 clicks, scripted run 0.4 s (< 30 s) |
| Keyboard: type `1 0 0 0 0 0` | `100.000 ₫` |
| Keyboard: `Tab` from the panel | goes straight to the first account chip (the pad keys are skipped), then the second chip row, then Save |
| Keyboard: `Enter` on an unchosen account | picks it, no save (banner appears), scripted run 0.8 s including two `Backspace` presses (`100.000 ₫` → `1.000 ₫`) |
| `Backspace`, digits while a chip has focus | work (the key handler sits above the chip) |
| Pointer cursor over a pad key | `pointer`; over empty space `auto` |
| Mouse wheel over the left margin (x = 150, in the area between the rail and the panel) | scrolls the list (key `0` moved 348 → 256) |
| Resize 1440 × 900 → 412 × 915 → 1440 × 900 mid-entry | amount `1.500 ₫` and the chosen account (banner `"Rac" 48.500 ₫`) kept at every step |
| `⌫` key | now has the label "Xóa số cuối" in the semantics tree |

**Enter saves (K4), observed end to end.** A scripting mistake (a stray click on a pad key while an account that had been chosen by mouse was keyboard-focused) pressed `Enter` once with the amount `6.100.000 ₫`. It saved exactly one expense and the screen closed: the `Dien` balance went from 1.450.000 ₫ to −4.650.000 ₫ (one deduction of 6.100.000 ₫). This confirms the designed rule (Enter on the already chosen focused chip saves, once, and the screen pops), but it **wrote a 6.100.000 ₫ expense on `Dien` into the QA account's data in the shared project**. The app has no way to delete a transaction, so it is left as QA data and reported to the owner; no further Save was pressed in the browser pass.

### Compact 412 × 915 (SC-005)

Snapshot of the Chi tiêu semantics boxes after the change vs the baseline: 0 nodes moved or resized by more than 1 px. The only difference is the delete key, whose merged label gained "Xóa số cuối". Android emulator and iOS simulator checks for all changed screens are recorded in the final compact pass below.

## US2 — Thu nhập (web, Chrome, release build, QA account; no Save pressed)

| Check | Result |
|-------|--------|
| 1440 × 900, light and dark | Save and the add-source button 520 px wide at x = 501 (centered beside the rail), total / eyebrow / row in the same column; name and amount field ≤ 520 px apart |
| Type 3.000.000 and 2.000.000 into two sources | total `5.000.000 ₫` |
| Resize 1440 → 412 → 1440 → 700 × 700 | typed values and the total unchanged at every step (rows are not remounted) |
| Pointer cursor over the add-source button | `pointer` |
| 1440 × 500 with 10 sources | Save y 428–480, inside the window |
| Mouse wheel over the left margin (x = 150) | scrolls the list (eyebrow 154 → −46) |
| Compact 412 × 915 vs baseline | rows and buttons unmoved; only the scroll container's own semantics group is now the full viewport width (x 0, w 412 instead of x 18, w 376): the 18 px side padding moved from outside the list to inside it, visually identical |

## US3 — Thu chi (web, Chrome, release build, QA account)

Entry buttons and the column, read from the `flt-semantics` boxes (x, y, w, h):

| Window | Thu nhập / Chi tiêu buttons | History link and first balance card | Expected column |
|--------|-----------------------------|--------------------------------------|-----------------|
| 600 × 800 (viewport 517) | 236 × 64 each, side by side (x 101 and 346) | 481 wide at x = 101 | viewport − 36 = 481 |
| 840 × 800 (viewport 757) | 356 × 64 each | 721 wide at x = 101 | 721 |
| 1200 × 900 | 475 × 64 each | 960 wide at x = 161 | 960 |
| 1440 × 900, light and dark | 475 × 64 each (x 281 and 766) | 960 wide at x = 281 (centered beside the rail) | 960 |
| 2560 × 1000 | 475 × 64 each | 960 wide at x = 841 (centered beside the rail) | 960 |

| Check | Result |
|-------|--------|
| Each entry point (Thu nhập, Chi tiêu, Xem lịch sử) opens and Back returns to the hub | pass, 1440 × 900 |
| Pointer cursor over a group header | `pointer` |
| Wheel over the left margin (x = 150) at 1440 × 420 | scrolls the balance list (heading y 216 → 16) |
| Compact 412 × 915 vs baseline | 0 nodes moved or resized; the only differences are the balance amounts themselves (the QA data changed during the US1 pass) |

## US4 — Kế hoạch and pop-ups (web, Chrome, release build, QA account)

| Check | Result |
|-------|--------|
| Column width of the group cards, beside the rail | 600 → 481 (viewport − 36), 840 → 721, 1440 → 960 at x = 281 (centered), 2560 → 960 at x = 841 (centered) |
| Allocation box (1440 × 900, reviewed visually) | one bounded box per item beside the name, right edges aligned in a column next to the edit/delete icons, widths 96–110 px; no full-row box |
| "Thêm khoản trong …" button | 930 × 48 inside the card (was 34 high; 48 on wide windows) |
| Pointer cursor over a group header | `pointer` |
| Edit pop-up | 560 px wide, centered on the window, name field focused (`document.activeElement` = "Tên khoản"); `Escape` closes it |
| Delete-group confirmation (`Xoá Gia Dinh`) | focus starts on `Hủy`; `Enter` cancels and the group is still there; `Escape` also cancels; nothing deleted |
| Mouse drag-reorder (handle) | dragging the last group above the previous one reordered the list (`Gia Dinh, Tao Phuc, Tiet Kiem`), then dragging it back restored the original order (`Gia Dinh, Tiet Kiem, Tao Phuc`) |
| Compact 412 × 915 vs baseline | 0 nodes moved or resized, no node added or removed |

Defects found on the way: the "Thêm khoản trong {name}" button overflowed by 253 px on a 320 px-wide window when the group name was long (the label is now `Flexible` with an ellipsis; listed in the sweep log). The 40 × 32 `%` / `₫` mode toggle of the item pop-up is below the 48 px touch-target minimum on purpose: its own code comment records the owner's explicit choice to match the design pixel for pixel, so it is left as is.

## US5 — Hồ sơ (web, Chrome, release build, QA account)

Hồ sơ language row vs Bảo mật change-password row, read from the `flt-semantics` boxes (x, width) beside the 83 px rail:

| Window | Hồ sơ (language row, sign-out row) | Bảo mật (change-password row) | Difference | Expected column |
|--------|-------------------------------------|-------------------------------|------------|-----------------|
| 840 × 900 | 101, 721 | 102, 719 | 1 px, 2 px | viewport − 36 = 721 |
| 1200 × 900 | 161, 960 | 162, 958 | 1 px, 2 px | 960 |
| 1440 × 900 | 281, 960 | 282, 958 | 1 px, 2 px | 960 |
| 1600 × 900 | 361, 960 | 362, 958 | 1 px, 2 px | 960 |
| 2560 × 1000 | 841, 960 | 842, 958 | 1 px, 2 px | 960 |

(The 1–2 px difference is the border of Bảo mật's bordered menu card; the columns coincide within the 8 px tolerance of SC-007.) Hồ sơ → Bảo mật → Back showed no jump of the content at any width. Dark appearance at 1440 × 900: language row x 281, width 960.

| Check | Result |
|-------|--------|
| Language pop-up | 280 px wide, centered on the window; the selected language (`Tiếng Việt`) has the initial focus (`document.activeElement`); `Enter` confirms it and closes; `Escape` closes without changing |
| Wheel over the left margin (x = 150) at 1440 × 420 | scrolls the list (language row y 252 → 120) |
| Compact 412 × 915 vs baseline | 0 nodes moved or resized, none added or removed |

## US6 — placeholders: Thông báo and Trợ giúp (web, Chrome, release build)

| Window | Thông báo from the Tổng quan bell | Result |
|--------|-----------------------------------|--------|
| 1440 × 900 | message box x 649, width 225 → center 761.5 (center of the 1357 px viewport beside the rail) | centered; Back returns to Tổng quan |
| 2560 × 1000 | x 1209, width 225 → center 1321.5 (center of the viewport) | centered; Back returns to Tổng quan |
| 320 × 700 | x 48, width 225 → center 160.5 (center of the window) | centered, nothing clipped; Back returns to Tổng quan |

From Hồ sơ at 1440 × 900: Thông báo and Trợ giúp both open the same centered message (x 649, width 225) and Back returns to Hồ sơ. Compact 412 × 915 vs baseline: 0 nodes moved or resized, none added or removed (the placeholder is only reachable from the Tổng quan bell and the Hồ sơ rows, both unchanged).

## US7 — final sweep (automated matrix, browser matrix, defects)

### Layer 1: automated matrix (committed tests)

`test/widget/core/adaptive_sweep_{auth,overview_report,history,spending,account,static}_test.dart` mount every screen of the inventory (data-model §3) with the real Lexend font loaded, in three case groups: every width of 320, 412, 600, 840, 1200, 1600, 2560 dp × light and dark at 800 dp high; a 500 dp-high window at 412 and 1440 dp wide; 130 % text size at 320, 412 and 1440 dp wide. Each case fails on any framework exception (overflow, layout assertion; the failure message names the source line), checks the column width of bounded screens (≤ 960 / 520 / 450) and, at ≥ 1200 dp, that the page's scroll view spans the viewport and reacts to the mouse wheel over the side margin.

| Family | Screens | Cases |
|--------|---------|-------|
| auth | Đăng nhập, Đăng nhập (khoá, nút vân tay), Đăng ký, Quên mật khẩu, Đặt lại mật khẩu | 120 |
| overview_report | Tổng quan, Báo cáo | 48 |
| history | Lịch sử giao dịch, Lịch sử theo khoản | 48 |
| spending | Thu chi, Thu nhập, Chi tiêu (manual), Chi tiêu (scan, after a capture), Kế hoạch | 120 |
| account | Hồ sơ, Bảo mật, Đổi mật khẩu | 72 |
| static | Thông báo / Trợ giúp placeholder, the two startup-error screens | 72 |

All 480 cases pass after the fixes below.

### Layer 2: browser matrix (Chrome, release build, QA account, light and dark)

Twelve screens (Tổng quan, Kế hoạch, Thu chi, Báo cáo, Hồ sơ, Thu nhập, Chi tiêu, Lịch sử, Bảo mật, Đổi mật khẩu, Thông báo, Lịch sử theo khoản) × windows 320 × 700, 412 × 915, 600 × 800, 840 × 800, 1200 × 900, 1600 × 900, 2560 × 1000, 1440 × 500, 412 × 500 (108 rows per theme). For every row: no semantics node leaves the window horizontally, and from 840 dp the content column (buttons, fields, tabs beside the rail) is within its limit (960 shared, 924 on the three migrated list screens, 520 entry screens, 450 on Đổi mật khẩu) and centered within 8 px (SC-004).

| Result | Detail |
|--------|--------|
| light | 108 / 108 rows pass; the only horizontal exceptions are the compact account-chip strip of Chi tiêu (a horizontal scroller by design) |
| dark | 108 / 108 rows pass, same exception |
| zoom 200 % (720 × 450) | 12 / 12 screens pass |
| zoom 400 % (360 × 225) | the loader could not reach two screens (their buttons are below a 225 px-high viewport), the other ten pass; the only horizontal exception is Tổng quan's account-card carousel (a horizontal scroller by design) |
| Hồ sơ ↔ Bảo mật | same column x and width within 1–2 px at 840, 1200, 1440, 1600 and 2560 (see US5) |
| Resize mid-task | Chi tiêu, Thu nhập, Kế hoạch: values and state kept at every step (see US1, US2, US4) |

### Sweep log: defects found and their fixes

| # | Screen / size | Symptom | Cause | Fix | Evidence |
|---|---------------|---------|-------|-----|----------|
| 1 | Tổng quan, Báo cáo, Lịch sử giao dịch, Lịch sử theo khoản at ≥ 1200 dp wide | mouse wheel, trackpad and scroll bar do nothing over the empty side margins; on a 2560 px window that is most of the screen | `AdaptiveBody` (`Center > ConstrainedBox`) wrapped the scroll view, so the list was only column-wide | the three screens use `AdaptiveGutters` with the content width they always had (`AppLayoutTokens.paddedListMaxWidth`, 924 dp); the scroll view spans the viewport | browser measurement before: wheel at x = 150 / x = 1290 → no scroll, at x = 760 → scrolls; sweep cases `Tổng quan`, `Báo cáo`, `Lịch sử …` at 1440 × 500 failed, now pass |
| 2 | Chi tiêu (compact strip and scan strip) at 130 % text | account chips overflowed their fixed 54 dp strip by 8 dp (two lines of text) | fixed strip height | the strip height and the wide chooser height follow the text size (`chipStripHeight`, `chipTextFactor`; 54 dp at the default size, unchanged) | sweep cases `Chi tiêu (manual / scan) … text 130%` failed, now pass |
| 3 | Kế hoạch, 320 dp, long group name | "Thêm khoản trong {name}" overflowed its card by 253 dp | the label was not flexible | `Flexible` + one line + ellipsis | widget test P8 |
| 4 | Kế hoạch, wide windows | reorder grab area 15 × 15 dp and the add-child button 34 dp high, below the 48 dp minimum | fixed small sizes | 40 × 48 grab area and 48 dp button on wide windows (compact unchanged) | widget tests P7, browser (button 930 × 48) |
| 5 | Chi tiêu | the delete key `⌫` had no tooltip and no screen-reader label | icon-only control | `expenseKeypadDeleteSemantic` tooltip + label (vi, en) | widget test L13, browser (label "Xóa số cuối") |

Checked and **not** a defect: the 40 × 32 `%` / `₫` toggle of the item pop-up (owner's documented choice, see US4); the sign-in screens, Đổi mật khẩu and Bảo mật already keep their scroll view outside `AdaptiveBody` (no dead zones); Quên mật khẩu and Đặt lại mật khẩu have no scroll view but fit down to 500 dp high and 130 % text in the automated cases.

## Compact pass on real platforms (T087, plus the compact lines of T033, T040, T056, T063, T069)

Method: the pre-change baseline (a detached worktree of `master` at 80d9a66) and the current tree were each built as a debug app, installed over the same local data and walked with the same script; every visible accessibility node (label, x, y, width, height) of each screen was captured and compared with a 2 px tolerance. The QA account was used; the walk only taps tabs and rows and goes back, no Save is pressed.

| Platform | Screens walked | Moved or resized | Added | Removed |
|----------|----------------|------------------|-------|---------|
| Android emulator (Pixel 10) | Tổng quan, Thông báo, Kế hoạch, Thu chi, Thu nhập, Chi tiêu, Hồ sơ, Bảo mật | 0 | 1 (`Xóa số cuối`, the new label of the delete key on Chi tiêu) | 0 |
| iOS simulator (iPhone 17) | the same 8 screens | 0 | 1 (the same label) | 0 |

Finished screens that this feature migrated to the new scroll/gutter pattern (T087). Tổng quan is part of the walk above (0 moved). Báo cáo and Lịch sử giao dịch were walked on the iOS simulator only, with the same method, in the months with and without data and with a filter applied:

| Screen state | Nodes | Moved or resized |
|--------------|-------|------------------|
| Báo cáo, tháng 10 (no activity) | 13 | 0 |
| Báo cáo, previous month (with data) | 17 | 0 |
| Lịch sử giao dịch, tháng 10 (empty) | 16 | 0 |
| Lịch sử giao dịch, previous month (list) | 26 | 0 |
| Lịch sử giao dịch, previous month, filter `Thu nhập` | 21 | 0 |

Lịch sử theo khoản is the same screen widget with a name filter; its compact layout is covered by the browser walk (US7 layer 2) and the automated matrix, not by a separate device walk.

One thing to know when repeating the iOS walk: the first baseline walk was taken before the device had synced the 6.100.000 ₫ expense described in the Baseline section, and the current walk after it. That made Tổng quan differ (total 10.677.778 ₫ → 4.577.778 ₫, the hero card taller by its two extra link rows). It was data, not layout: re-running the baseline on the same data gave 0 moved nodes on all eight screens.

Pop-ups (item form, delete confirmation, language list, biometric prompt, discard prompt) were not opened in the native walks. At compact the shared dialog theme cannot change them: the 560 dp cap is above the 332 dp a 412 dp window leaves (Flutter's default inset is 40 dp a side) and the 280 dp minimum is Flutter's own default. `dialog_constraints_test.dart` asserts that a 410 × 864 dialog stays inside the window and that a narrow dialog keeps the 280 dp minimum.

## Large text on Android (T086)

`adb shell settings put system font_scale 1.3` (restored to 1.0 afterwards), Kế hoạch, Chi tiêu and Hồ sơ at the phone size: no overflow, no clipped text or hidden control on any of the three screens (fix 2 of the sweep log is what made Chi tiêu pass).

Observation outside this feature: with 130 % text the bottom navigation bar wraps the labels `Tổng quan` and `Kế hoạch` onto two lines and the first label sits against the left edge. The bar is the stock Material `NavigationBar` of the app shell, which this feature does not change (not in the diff), so the behaviour is the same before and after; nothing is clipped. It is listed in the final report as a decision for the owner, not changed here, because the compact look of the shell must stay as it is.

## Gate (T028 … T088)

`dart format --output=none --set-exit-if-changed lib test` → 0 changed; `flutter analyze` → only the 2 existing `onReorder` infos; full `flutter test` → 1406 tests pass (re-run after the device-review fixes below; 1387 before them).

## Device review before the commit (Android emulator and Chrome)

A second look at the real screens, in particular the places the earlier walks did not open: pop-ups, Lịch sử theo khoản, a phone held sideways (923 × 411 dp), 130 % text. The QA account was used and nothing was saved; the one data change was the reorder test (two groups swapped on a touch drag and swapped back; the original order was confirmed).

| # | Where | Symptom | Cause | Fix | Evidence |
|---|-------|---------|-------|-----|----------|
| 6 | Kế hoạch item pop-up, phone (Android, iOS) | the on-screen keyboard opened the moment the pop-up did, and the keyboard's "done" key saved the form (before: it only closed the keyboard) | the name field's `autofocus` and the `textInputAction` / `onSubmitted` added for the desktop Enter contract applied on every platform | all three apply only on a desktop platform (`_hasHardwareKeyboard`); phones keep today's behaviour | `expense_control_dialogs_test.dart`, three window sizes without a hardware keyboard; emulator: the pop-up opens without the keyboard; Chrome: the name field has the focus, Enter does not save an invalid form, Escape closes |
| 7 | every screen with a header, phone held sideways with a camera cutout | the header was indented by the cutout inset (54 dp) a second time and a screen without a `SafeArea` (Hồ sơ) did not line up with its own header | the rail pads itself by the left inset, and the content beside it kept the same inset in its `MediaQuery`, so each `AppBar` and `SafeArea` applied it again | the shell removes the left padding from the content beside the rail | `app_shell_display_inset_test.dart` (fails without the fix); emulator: the Hồ sơ header moved from 70 dp to 16 dp after the rail, in line with its cards (18 dp); the Kế hoạch content moved from 72 dp to 18 dp |

Checked and fine: Kế hoạch pop-ups (item, delete) at 100 % and 130 % (the item form scrolls inside the pop-up, both buttons stay visible), the language pop-up (280 dp wide, the selected language marked), Lịch sử theo khoản opened from the Tổng quan warning, touch drag-reorder of the groups, the touch keypad of Chi tiêu (digits, delete, choosing an account), Chi tiêu, Kế hoạch, Thu chi, Thu nhập and Hồ sơ in landscape (the amount scrolls with the pad and Save stays pinned on Chi tiêu, as designed below 500 dp high), and every screen and pop-up in Chrome at 1440 × 900 light and dark and at 600 × 640.

Not reached on the emulator: the discard-changes prompt (it needs a staged formula edit, which the UI offers only through paths the walk did not take; it is covered by `app_shell_discard_prompt_*_test.dart` and the Chrome pass) and the biometric offer (the emulator has no enrolled biometrics; covered by `biometric_enable_prompt_dialog_test.dart`).

Two more findings of the same review, fixed at the owner's request:

| # | Where | Symptom | Cause | Fix | Evidence |
|---|-------|---------|-------|-----|----------|
| 8 | bottom navigation bar, phone | `Tổng quan` (and `Kế hoạch`) wrapped onto two lines and their icons sat higher than the other three: at text 130 % on a 412 dp phone, and already at the default size on a phone 360 dp wide or narrower | the theme gave the label a colour but no size, so it fell back to the 14 sp body text instead of Material 3's 12 sp label: "Tổng quan" is 73 dp at 14 sp, the slot is 82 / 72 / 64 dp at 412 / 360 / 320 | label size 12 sp in the light and dark themes (63 dp, fits all three widths), and the labels are drawn at no more than 110 % text scale (`MediaQuery.withClampedTextScaling`); the rest of the app keeps scaling | `app_shell_nav_text_scale_test.dart` with the real font (fails at 14 sp and without the clamp): one line at 320 / 360 / 412 dp at the default size, at 360 dp at the cap, and at 412 dp at 130 % and 200 %; emulator at 130 %: five labels on one line, icons level |
| 9 | Thu chi and the placeholders (Thông báo, Trợ giúp, …), all platforms | a bare `Text` title: centered on iOS and on a desktop browser, left-aligned on Android, and no icon chip unlike the other tabs | plain `AppBar(title: Text)` | one shared `PageTitle` (34 dp tinted chip with the page's icon, then the title, left-aligned) used by Hồ sơ, Thu chi and the placeholders | `page_title_test.dart` (on a macOS-platform theme, where a bare title is centered: the chip starts at 16 dp at 412 and 1440 wide, for the widget and for the three pages); emulator and Chrome: chip and left-aligned title |

Intentional visible change on phones (compact): the headers of Thu chi and of the placeholders now show the icon chip, as Hồ sơ already did. It is the only compact change of this feature besides the new `Xóa số cuối` label. The existing test of the placeholder (`not_available_placeholder_screen_test.dart`) was given the app theme (the chip reads the app's semantic colors, as every other screen does) and its icon assertion now looks inside the empty state and inside the title separately.

The earlier decision to accept the wrap (adaptive-layout-foundation spec, FR-017 note: "never fits on one line at any realistic phone width, only 8 sp would") was most likely measured with the test engine's placeholder font, which is twice as wide as Lexend; with the real font the label fits (see row 8), so the note in that spec now carries an update.

The side rail needs no change: it grows with its labels and stays on one line at every text size tested (100–200 %).

The owner confirmed that the negative balance of the `Dien` item (−4.650.000 ₫, left by the unintended 6.100.000 ₫ expense of the first walks, without its history row) is acceptable test data; nothing was changed in the real project.
