# Contract: Chi tiêu (Nhập chi tiêu) on Wide Windows

**Feature**: `20261007-100751-adaptive-web-remaining-screens` | **Story**: US1 (P1) | **Date**: 2026-10-07
**Files**: `lib/features/expenses/presentation/expense_screen.dart`, `expense_entry_layout.dart` (new),
`expense_key_mapping.dart` (new)

## Layout contract

"Wide" = window width ≥ 600 dp (`WindowSizeClass.medium` and up). Below it nothing changes.

```text
┌ App bar (56) ─────────────────────────────────────────────┐   full width, as today
│        ┌ panel, ≤ 520 dp, centered in the area beside the rail ┐
│        │ [ Nhập tay ] [ Quét hoá đơn ]          (38)           │   pinned
│        │ Số tiền · 100.000 ₫                    (~71)          │   pinned (wide, height ≥ 500)
│        │ ┌────┬────┬────┐                                      │
│        │ │ 1  │ 2  │ 3  │  4 rows × K (48–64), gap 6           │   scroll region
│        │ │ …  │    │    │                                      │   (no scroll at ≥ 640 dp high)
│        │ │ .  │ 0  │ ⌫  │                                      │
│        │ TRỪ VÀO KHOẢN NÀO                                      │
│        │ [chip][chip][chip][chip][chip]   ≤ 2 rows, then       │
│        │ [chip][chip][chip]               scrolls inside        │
│        │ "Tên khoản" 1.234.000 ₫  (preview banner, if any)      │
│        │ [ Lưu giao dịch ]                       (48)          │   pinned
└────────┴────────────────────────────────────────────────────────┘
```

| ID | Rule | Verified by |
|----|------|-------------|
| L1 | Panel width ≤ `entryContentMaxWidth` (520) and centered within 8 px of the area beside the rail (SC-004). The app bar and the rail are untouched. | widget test at 1440 × 900 and 1000 × 700; browser measurement |
| L2 | In every window ≥ 600 × 640 with **8 accounts (names and group names ≤ 9 characters) and a visible preview banner**, the amount, the 12 keys, all chips, the banner and Save are fully inside the viewport and the scroll region has no scroll extent. At a 600 dp window the shell's rail leaves a 517 dp viewport and a 481 dp panel; the test mirrors that with `withRail`. | widget test at 600 × 640 (with rail), 1000 × 640, 1366 × 650, 1440 × 900 (`ScrollPosition.maxScrollExtent == 0`, `tester.getRect` inside the screen); browser at 1440 × 900, 1366 × 650, 1000 × 640, 600 × 640 |
| L3 | Key height `K = clamp(48 + (height − 640) / 8, 48, 64)`; the pad never grows with the width; no key is taller than 72 dp. | unit test of `ExpenseEntryLayout`; widget test reading key `Rect`s at three heights and widths 600 / 1200 / 2560 |
| L4 | Every key, chip, tab and Save is ≥ 48 × 48 dp. | widget test over `expense-keypad-*`, `expense-item-chip-*` |
| L5 | With more accounts than fit in two rows (16 accounts, or 8 with 14-character names) the chooser keeps its two-row height and scrolls vertically inside on its own controller; amount, pad and Save stay in view; a chip focused with Tab is scrolled into view. | widget test; browser Tab test |
| L6 | In a window between 500 and 640 dp high the pad/chooser region scrolls; the amount and Save stay pinned and visible; every control is reachable. | widget test at 1000 × 500; browser at 1000 × 500 |
| L7 | At very wide (2560) and very tall (1440 × 1300) windows the panel stays 520 dp and `K` stays 64. | widget test |
| L8 | Scan mode uses the same panel: its tab strip is the same pinned strip, its content inside the same gutters; behavior unchanged. | widget test (scan tab at 1440) |
| L9 | Compact (< 600 dp): the tree, sizes and behavior are today's. The existing `expense_screen_test.dart` passes unmodified (its 800 × 1400 surface counts as wide: the only permitted edit is its viewport helper, see `tasks.md`). | existing tests |
| L10 | Light and dark: no new color; the amount underline, key and chip colors come from the theme as today. | browser light + dark |
| L11 | In a wide window shorter than 500 dp (844 × 390, a phone held sideways) the amount scrolls with the pad (not pinned), only Save stays pinned, and every control can be reached and used. | widget test at 844 × 390; browser at 844 × 390 |
| L12 | Pad keys, chips, mode tabs and Save show hover feedback under a mouse and a visible focus ring from the keyboard (keys: hover only, they are not focusable). | widget test with a mouse `TestGesture`; browser |
| L13 | The `⌫` key has a `Tooltip` and a semantics label, both `expenseKeypadDeleteSemantic` (vi "Xóa số cuối", en "Delete last digit"), at every width; nothing else about the key changes. | widget test (tooltip message, semantics node) at 410 and 1440, in `vi` and `en`; browser hover |

## Behavior contract (keyboard)

The manual tab wraps its content in one `Focus(autofocus: true, onKeyEvent: …)`.

| ID | Input | Result |
|----|-------|--------|
| K1 | `0`–`9` (main row or numpad), no `Ctrl`/`Meta`/`Alt` | `controller.appendDigit(d)`, identical to clicking the key |
| K2 | `Backspace` (repeat allowed) | `controller.backspace()` |
| K3 | `.` or `,` | the same no-op as the on-screen `.` key (whole-VND amounts) |
| K4 | `Enter` / `NumpadEnter` with focus on the panel (no specific control) **or** on the account chip that is already chosen | `controller.save()` with today's validity rules; when invalid, today's error text is shown and nothing is saved |
| K5 | `Enter` with focus on an unchosen account chip, a mode tab, Save or Back | that control's own activation (an unchosen chip picks its account; Save saves) |
| K5b | Any pointer press inside the manual tab | focus returns to the panel node, so a stale keyboard focus never captures a later `Enter` |
| K6 | A held `Enter` | one save (repeat ignored; `save()` is single-flight through `isSubmitting`) |
| K7 | Any other key; any key with `Ctrl`/`Meta`/`Alt` | ignored and **not consumed** (browser zoom `Ctrl+0`, reload, dev tools keep working) |
| K8 | Keys while a pop-up or the scan tab is showing | no effect (the handler exists only on the manual tab; pop-ups are separate routes) |
| K9 | Pad keys | clickable, in the semantics tree, **not** in the Tab order (`canRequestFocus: false`) |
| K10 | Tab order | Back → mode tabs → account chips (in visual order, wrapping rows left-to-right) → Save |

Tests: `test/unit/features/expenses/expense_key_mapping_test.dart` (every row of K1–K7 as a table);
`test/widget/features/expenses/expense_screen_keyboard_test.dart` (type `1 0 0 0 0 0` → `100.000 ₫`; type digits +
Backspace; Tab to a chip + Enter picks it and does not save, the next Enter saves; click digits + Enter saves; no account → error text and no
save; two quick Enters → one save; `Ctrl+0` not consumed) at 1440 × 900. The keyboard-only flow (digits, `Tab` to a chip, `Enter` picks it without saving, `Enter` saves once) and the stale-focus flow (Tab to a chip, click a pad key, `Enter` saves) are pinned too.

## State contract (resize)

| ID | Scenario | Expected |
|----|----------|----------|
| S1 | Type `1500`, pick account B, resize 1440 → 412 → 1440 | amount `1.500 ₫`, B still selected, preview banner still shows |
| S2 | Switch to Quét hoá đơn, resize across 600 | still in scan mode |
| S3 | Scroll the region in a short window, resize wider | no crash; offset may clamp |
| S4 | Browser zoom 200 % at 1440 × 900 (a 720 × 450 viewport) | behaves as a 720 × 450 window: scrolls, Save reachable, amount visible |

Tests: widget test using `tester.view.physicalSize` changes mid-test; browser resize script.

## Out of scope for this page

`.` producing a decimal, changing what the keys do, scanning a receipt, changing which accounts are listed, the web
address bar (`/spending` stays while the pushed screen shows).
