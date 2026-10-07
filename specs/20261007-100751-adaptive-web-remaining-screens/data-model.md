# Data Model: Adaptive Web Layout for the Remaining Screens

**Feature**: `20261007-100751-adaptive-web-remaining-screens` | **Date**: 2026-10-07

This feature stores nothing and changes no schema, repository, sync rule, calculation or saved value (FR-016). There is
no Drift table, no Supabase column and no new provider state. What the plan does define is (1) the layout values the
screens compute from the window, (2) the existing state that must survive a resize, and (3) the screen inventory the
final sweep covers.

## 1. Layout values (pure, derived from the window; never stored)

### 1.1 Shared tokens (`core/theme/app_layout.dart`, existing file)

| Token | Value | Used by |
|-------|-------|---------|
| `contentMaxWidth` (existing) | 960 dp | Thu chi, Kế hoạch, Hồ sơ, placeholders (activated at `expanded`) |
| `authContentMaxWidth` (existing) | 450 dp | sign-in screens (unchanged) |
| `entryContentMaxWidth` (new) | 520 dp | Chi tiêu, Thu nhập (activated at `medium`) |
| `screenGutter` (new) | 18 dp | the minimum horizontal inset; equals the padding the screens use today |

### 1.2 `adaptiveGutterFor` (pure function, `core/theme/app_layout.dart`)

```text
adaptiveGutterFor({
  required double windowWidth,     // MediaQuery.sizeOf(context).width: picks the size class
  required double viewportWidth,   // the width this scroll view / bar actually gets (beside the rail)
  double maxWidth = contentMaxWidth,
  WindowSizeClass activatesAt = WindowSizeClass.expanded,
  double minGutter = screenGutter,
}) -> double

  if windowSizeClassFor(windowWidth).index < activatesAt.index:  return minGutter
  return max(minGutter, (viewportWidth - maxWidth) / 2)
```

| Rule | Why |
|------|-----|
| Below `activatesAt` the result is exactly `minGutter` | compact stays identical (FR-002) |
| The result never shrinks below `minGutter` | content never touches the window edge |
| `viewportWidth`, not the window, feeds the centering | the rail takes 83 dp; centering on the window would be off by ~41 dp (SC-004's 8 px tolerance) |
| The class is chosen from the window width | one breakpoint scale, as the constitution requires |

`AdaptiveGutters` (`core/widgets/adaptive_gutters.dart`) is the only widget that calls it:
`AdaptiveGutters(maxWidth:, activatesAt:, builder: (context, double gutter) => …)`, built on `LayoutBuilder` +
`MediaQuery.sizeOf`.

### 1.3 `ExpenseEntryLayout` (pure class, `features/expenses/presentation/expense_entry_layout.dart`)

Computed from `Size` (the window) — no `BuildContext`, so it is unit-testable.

| Field | Compact (< 600 dp) | Wide (≥ 600 dp) |
|-------|--------------------|-----------------|
| `isWide` | false | true |
| `keyHeight` | derived from width (today: `childAspectRatio 2.2`) | `clamp(48 + (height − 640) / 8, 48, 64)` |
| `keyGap` | 8 | 6 |
| `amountPinned` | false (amount scrolls with the list, as today) | true when `height >= pinAmountMinHeight` (500), otherwise false |
| `chooserWraps` | false (horizontal strip, 54 dp high) | true |
| `chooserMaxHeight` | n/a | 2 × 50 + 6 = 106 dp (scrolls inside beyond two rows) |
| `tabHeight` | 38 | 48 |
| `tabsTopPadding` / `saveBottomPadding` | 16 / 20 | 4 / 12 |
| `contentTopGap` / `amountVerticalPadding` | 8 / 8 | 4 / 2 |
| `keypadVerticalPadding` / `eyebrowBottomPadding` | 14 / 8 | 4 / 4 |
| `bannerBottomMargin` / `saveTopPadding` | 14 / 0 | 6 / 6 |
| `saveHeight` | 52 | 48 |

The wide paddings are the calibrated values that make amount, pad, chooser, banner and Save fit a 640 dp-high window
(research Decision 3 explains the calibration; `expense_entry_layout.dart` is the source of truth).

`pinAmountMinHeight = 500` is a named constant: below it the amount scrolls with the pad (only Save stays pinned), so a
wide but short window (844 × 390) keeps a usable scroll region (research Decision 3, "Short windows").

Validation: `keyHeight` is always in `[48, 64]` in wide mode (≥ 48 touch target; spec cap 72); the compact column is
byte-for-byte today's layout, which the unmodified existing tests enforce.

### 1.4 Keyboard mapping (`features/expenses/presentation/expense_key_mapping.dart`)

```text
sealed ExpenseKeyAction:  digit(int 0..9) | backspace | decimal | save

expenseKeyActionFor({String? character, LogicalKeyboardKey key, bool ctrl, bool meta, bool alt}) -> ExpenseKeyAction?
  ctrl || meta || alt           -> null
  character in '0'..'9'         -> digit
  key == backspace              -> backspace
  character == '.' or ','       -> decimal   (the same no-op as the on-screen `.` key)
  key in {enter, numpadEnter}   -> save
  otherwise                     -> null
```

Each action maps 1:1 to the controller call the matching on-screen key already makes (`appendDigit`, `backspace`, no
call for `decimal`, `save`), so there is a single code path.

## 2. Existing state that must survive resizing (FR-004 / SC-006)

None of it moves; the list records where it lives and why a breakpoint crossing cannot reset it.

| State | Lives in | Survives because |
|-------|----------|------------------|
| Chi tiêu amount, chosen account, `isSubmitting`, `saveError` | `ExpenseFormController` (Riverpod notifier) | provider, not widget state |
| Chi tiêu mode (manual / scan) | `_ExpenseScreenState._isManualTab` | the route's `State` is not rebuilt by a resize |
| Chi tiêu vertical scroll offset | the manual tab's `ListView` | same-shape tree (slots, research Decision 4) keeps the element |
| Thu nhập typed amounts | `TextEditingController`s in `_IncomeSourceRowWidgetState` + `IncomeFormController` | gutters are a `Padding` value, so no row is remounted |
| Kế hoạch expanded/collapsed groups | `_ExpenseGroupCardState._expanded`, keyed `ValueKey(item.id)` | gutters keep the `ReorderableListView` elements; keyed cards survive |
| Kế hoạch unsaved item edits | `pendingItemEditsProvider` | provider |
| Open pop-up (item form, language, …) | its own route | a route is re-laid-out, not rebuilt, on resize |

## 3. Screen inventory for the final sweep (FR-018, SC-003)

| # | Screen | Route | State |
|---|--------|-------|-------|
| 1 | Đăng nhập | `/sign-in` | finished |
| 2 | Đăng ký | `/sign-up` | finished |
| 3 | Quên mật khẩu | `/forgot-password` | finished |
| 4 | Đặt lại mật khẩu | `/reset-password` | finished |
| 5 | Tổng quan | `/overview` | finished |
| 6 | Lịch sử giao dịch (all) | `/overview/history`, `/spending/history` | finished |
| 7 | Lịch sử theo khoản | `/overview/history/group/:accountName` | finished (checked in the sweep) |
| 8 | Thông báo | `/overview/notifications` | story 6 |
| 9 | Kế hoạch | `/expense-control` | story 4 |
| 10 | Thu chi | `/spending` | story 3 |
| 11 | Thu nhập | `/spending/income` | story 2 |
| 12 | Chi tiêu (manual, scan) | `/spending/expense` | story 1 |
| 13 | Báo cáo | `/history` (tab) | finished |
| 14 | Hồ sơ | `/account` | story 5 |
| 15 | Trợ giúp / Thông báo (profile entry) | `/account/placeholder/:feature` | story 6 |
| 16 | Bảo mật | `/account/security` | finished |
| 17 | Đổi mật khẩu | `/account/security/change-password` | finished |
| 18 | Sign-in in its lock mode (a persisted session at start) and the startup-error app (`StartupErrorApp`, `lib/main.dart`) | (non-route states) | finished (checked in the sweep) |
| P | Pop-ups: item form, delete-group confirmation, language choice, biometric offer, discard-changes prompt | dialogs | stories 4–5 + sweep |
