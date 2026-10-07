# Research: Adaptive Web Layout for the Remaining Screens

**Feature**: `20261007-100751-adaptive-web-remaining-screens` | **Date**: 2026-10-07

All measurements below were taken on `master` (`80d9a66`) in Chrome with the QA account, unless a decision says
otherwise. No `NEEDS CLARIFICATION` remains: the spec's open points were settled in `/speckit-clarify`, and the
planning decisions the spec deferred (entry reading width, key size, chooser behavior) are made here.

## Decision 1: Bound content with horizontal gutters on a window-wide scroll view, not with `AdaptiveBody` around it

**Decision**: add one pure function `adaptiveGutterFor(...)` to `core/theme/app_layout.dart` and one widget
`AdaptiveGutters` (`core/widgets/adaptive_gutters.dart`) that hands its builder the horizontal inset
`max(minGutter, (viewportWidth − maxWidth) / 2)` once the window reaches `activatesAt`, and `minGutter` below it. The
scroll views of the remaining screens keep spanning the whole viewport and use that inset as their horizontal
padding; fixed (non-scrolling) parts use the same inset as `Padding`. `AdaptiveBody` stays for the screens that
already use it until the final sweep decides about them (Decision 10).

**Rationale**:
- Measured on the finished Tổng quan at 1440 × 500: a mouse-wheel over the side gutter (x = 250) scrolls nothing
  (content stays at y = 80), the same wheel over the column (x = 720) scrolls it (y = 62). `AdaptiveBody` wraps the
  `ListView`, so the scroll view is only as wide as the column and the empty sides are dead zones for wheel,
  trackpad and the scroll bar. On a 1600–2560 px window these dead zones are most of the screen. This is a shared
  defect, so by the constitution's root-cause rule the new screens must not copy it and the finished ones are fixed in
  the final sweep.
- Same-shape tree: the gutter is always a `Padding` value (never a conditional wrapper), so crossing a breakpoint
  changes one number and does not remount anything (the lesson recorded in `AdaptiveBody`'s own comment). This matters
  for Thu nhập, whose row `TextEditingController`s live in widget state, and for Kế hoạch, whose group cards keep
  `_expanded` in widget state.
- `minGutter` equals today's padding (18 dp), so below the activation width the inset is exactly what the screens use
  now: compact is unchanged by construction.
- It works with every shape in play: `ListView(padding:)` (Thu chi, Hồ sơ, Kế hoạch's outer list, Thu nhập),
  `Padding` for pinned bars (Chi tiêu's amount and Save), and `ReorderableListView` stays untouched inside Kế hoạch's
  list.

**Alternatives considered**:
- *Keep `AdaptiveBody` around each screen's scroll view* (the Tổng quan pattern): rejected, reproduces the dead-zone
  defect above.
- *`AdaptiveBody` inside the `ListView`* (the Bảo mật pattern: `ListView → AdaptiveBody → Column`): works for finite
  children and is acceptable there, but it cannot wrap Chi tiêu's pinned bars, adds a `Center/ConstrainedBox` layer per
  screen, and gives the sliver list no say in its own padding. Bảo mật keeps it (finished and correct).
- *A third-party responsive package*: forbidden without a maintenance review (constitution Principle III) and
  unnecessary.

## Decision 2: Entry screens read at 520 dp, activated from 600 dp; the other pages use the shared 960 dp from 840 dp

**Decision**: new token `AppLayoutTokens.entryContentMaxWidth = 520`, used by Chi tiêu and Thu nhập and activated at
`WindowSizeClass.medium` (600 dp). Thu chi, Kế hoạch, Hồ sơ and the placeholders use the existing
`contentMaxWidth = 960` with the existing activation (`expanded`, 840 dp), exactly like Bảo mật and Tổng quan.

**Rationale**:
- 520 dp is inside the spec's 480–560 dp range. At 520 dp a three-key row is 168 dp wide per key (comfortable for a
  mouse, never cramped), and a chooser chip row holds about five chips, so eight accounts wrap onto two rows (the
  vertical budget of Decision 3 needs that).
- Activating at 600 dp is required: FR-005 promises the whole pad from 600 px wide, and the screen is already broken
  at 600–839 dp (the pad grows with the width because key height is derived from the width).
- Hồ sơ must match Bảo mật (FR-012): `AdaptiveBody` defaults (960 dp, activated at 840 dp) are what Bảo mật uses, so
  Hồ sơ takes the same values through `AdaptiveGutters` and the two columns land on the same position.

**Alternatives considered**: a 480 dp or a 560 dp entry width: 480 gives 156 dp keys and cramps the chooser to four
chips per row; 560 leaves the chooser at the same two rows but lets the pad look stretched. 720 dp for the hub:
rejected; it would break the "same shared maximum" rule (FR-001, SC-004) for a page that is not an entry screen.

## Decision 3: Chi tiêu vertical budget and the pad's key height

**Measured today** (Chrome, 1366 × 650): the content `ListView` holds amount (y 118–200), pad (214 → 985, keys
187–198 dp tall because `GridView` uses `childAspectRatio: 2.2`), chooser (y ≥ 1021), preview banner, error text;
Save is pinned at y = 578. Scrolling the list moves the amount out of view (after a scroll the amount node is gone
from the viewport), so a person using the pad cannot see the amount. At 1440 × 900 the keys `1–9` fit, the bottom row
starts at 831 and the chooser at 1067. Each `0` click does work once scrolled into view (verified by mouse), so the
defect is hidden and misplaced controls, not a dead key.

**Decision**: in wide mode (window ≥ 600 dp) the layout is

| Slice (top to bottom) | Height (dp), measured at 1000 × 640 | Notes |
|-----------------------|-------------------------------------|-------|
| App bar (existing) | 56 | unchanged |
| Mode tabs (Nhập tay / Quét hoá đơn) | 4 + 48 | top padding 16 → 4; height 38 → 48 in wide mode (touch target ≥ 48) |
| Gap, then amount block (pinned when the window is ≥ 500 dp high) | 4 + ≈ 70 | label + display + underline, vertical padding 8 → 2 |
| Pad | 4 + 4 × 48 + 3 × 6 + 4 = 218 | K = key height, see below; vertical padding 14 → 4, gap 8 → 6 |
| Eyebrow "Trừ vào khoản nào" | ≈ 17 + 4 | bottom padding 8 → 4 |
| Chooser | 2 rows × 50 + 6 = 106 | bounded, internal scroll beyond two rows |
| Preview banner | 36 + 6 margin | shown only after account + amount; bottom margin 14 → 6 |
| Save (pinned) | 6 + 48 + 12 | button 52 → 48 in wide mode; bottom padding 20 → 12 |

The first estimate (before measuring) added up to 643 dp. The widget test with 8 accounts **and** a visible banner then
showed a 26 dp overflow at 1000 × 640 (the mode tabs had to grow to the 48 dp touch target, which the estimate had not
counted), so the paddings were trimmed in the order tabs → gap above the amount → amount → pad → eyebrow → banner margin
until `maxScrollExtent == 0` with 2–4 dp to spare at 640 dp high (7 dp at 650 dp). The calibrated numbers live in
`ExpenseEntryLayout` (`expense_entry_layout.dart`) and are asserted by `expense_screen_adaptive_layout_test.dart` (L2) at
600 × 640 beside the rail, 1000 × 640, 1366 × 650 and 1440 × 900, in light and dark. K never goes below 48 (touch target).
If the real-browser measurement overflows, the next step is moving the preview banner into the pinned area above Save
(it is feedback, not a control).

Key height `K = clamp(48 + (windowHeight − 640) / 8, 48, 64)`: 48 at 640 dp, 56 at 704 dp, 64 from 768 dp up. Taller
windows get roomier keys, never above 64 (spec cap: 72), and the pad never grows with the *width* (the defect today).
The formula is pure and unit-tested; each extra dp of window height adds 0.5 dp to the pad and 1 dp of room, so
anything that fits at 640 fits above it.

**Rationale**: the budget is arithmetic on measured values, written down so the 640 dp promise is checkable by a
test instead of argued. Pinning the amount fixes the "cannot see what I type" problem for windows between 500 and 640 dp high,
where the pad region scrolls.

**Short windows**: the pinned parts cost 56 (app bar) + 54 (tabs) + 71 (amount) + 68 (Save) = 249 dp. In a window
only 390 dp high but wide (a phone held sideways, 844 × 390, which is ≥ 600 dp wide and so in wide mode) pinning the
amount would leave a 141 dp scroll region for a 4-row pad. So the amount is pinned only when the window is at least
500 dp high (`pinAmountMinHeight`, the smallest height FR-003 promises); below that it scrolls with the pad exactly as in
compact mode, and only Save stays pinned (178 dp pinned, 212 dp left to scroll).

**Alternatives considered**: fixed K = 56 (fails the budget at 640 dp); shrinking keys below 48 (violates the
constitution's touch-target rule); a two-column pad + chooser inside the panel (rejected by the clarification: one
column only); making the chooser a one-row horizontal strip on wide windows (a mouse user cannot scroll
horizontally without shift-wheel, and Flutter web does not drag-scroll with a mouse by default).

## Decision 4: Same-shape tree with slots; the chooser is the only subtree that is allowed to remount

**Decision**: `_ManualEntryTab` keeps the structure `Column[ amountSlot, Expanded(ListView[ listAmountSlot, pad,
eyebrow, chooser, banner, error ]), Save ]`. In compact mode `amountSlot` is `SizedBox.shrink()` and `listAmountSlot`
holds the amount block (as today, scrolling with the list); in wide mode the reverse. Slots keep their child indexes,
so Flutter reuses the `Column`, `Expanded` and `ListView` elements across the breakpoint. The chooser slot holds a
horizontal strip in compact mode and a bounded wrapping chooser in wide mode; those are different widget types, so
only the chooser subtree is rebuilt when the width crosses 600 dp. That is harmless: all chooser state is the
selected item id in `ExpenseFormController` (a Riverpod notifier), not widget state. The same holds for the amount
(`ExpenseFormState.amount`), the mode (`_isManualTab` on the route's `State`, which is not rebuilt), and the pad.

**Rationale**: FR-004/SC-006. The form state already lives outside the widgets, so the only things resizing could
lose are scroll offsets; keeping the `ListView` element preserves the vertical one.

**Chooser implementation note**: the wide chooser is a small stateful widget that owns its own `ScrollController` and
uses `Scrollbar(controller: …)` + `SingleChildScrollView(controller: …, primary: false)`. A scroll bar left on the
default `PrimaryScrollController` would attach to the tab's outer `ListView` (already using it), and the stateless
`_ManualEntryTab` cannot own a controller.

**Alternatives considered**: a single always-wrapping chooser at every width (changes the compact look, which must
not change); `LayoutBuilder` branching of the whole tab (remounts the `ListView`, loses the scroll offset).

## Decision 5: Physical keyboard on Chi tiêu

**Decision**: one `Focus(autofocus: true, onKeyEvent: …)` around the manual tab. A pure mapper
`expenseKeyActionFor(character, logicalKey)` returns `digit(d)`, `backspace`, `save`, `decimal` (maps to the same
no-op as the on-screen `.`) or `null`. The widget forwards actions to the existing `ExpenseFormController`
(`appendDigit`, `backspace`, `save`), so keyboard and pad share one code path and cannot diverge (SC-002).
Rules:
- Digits come from the key event's `character` (so a numpad, a Vietnamese Telex keyboard and `Shift`-digit symbols
  behave: only `'0'..'9'` count), with `Ctrl`/`Meta`/`Alt` held → ignored (browser shortcuts such as `Ctrl+0` zoom
  reset must keep working).
- Repeat events (`KeyRepeatEvent`) are accepted for Backspace and digits (holding Backspace deletes, as people expect)
  and ignored for Enter (a held Enter must not fire a second save; `save()` is also single-flight through
  `isSubmitting`).
- **Enter** is decided by the focus target alone: focus on the panel (or on no specific control) → save; focus on an
  account chip that is **already chosen** → save (re-picking it would do nothing); focus on an unchosen chip, a mode
  tab, Save or Back → that control's own activation. Any pointer press inside the manual tab hands focus back to the
  panel node, so stale keyboard focus never captures a later Enter. The keyboard-only flow is therefore: digits, `Tab` to
  a chip, `Enter` (pick), `Enter` (save) with no focus jump (moving focus after an activation would disorient
  keyboard and screen-reader users); the mouse flow is: click digits and a chip, `Enter` (save). This mirrors HTML
  implicit form submission, where `Enter` in a chosen radio group submits the form.
- The pad keys do not take focus (`canRequestFocus: false`, `ExcludeFocus`): typing is their keyboard path, and 12
  extra Tab stops before the chooser would make keyboard navigation worse. They stay clickable and keep their
  semantics, so screen readers are unaffected.
- The handler lives only on the manual tab; the scan tab and pop-ups (separate routes) never receive it, which
  satisfies "act only while the amount is the active input".

**Rationale**: constitution Principle III (keyboard activation of primary actions, visible focus order) and the
clarified "Enter saves exactly like Save".

**Alternatives considered**: deciding by `FocusManager.highlightMode` ("the last input was the keyboard"): rejected
because in `automatic` strategy any key event, including the digits being typed, flips the mode to *traditional*
(Flutter's `focus_manager.dart`, `handleKeyMessage`, ~lines 2222–2236: it sets `_lastInteractionRequiresTraditionalHighlights = false` and calls `updateMode()` on every key message), so after `Tab`, `Enter`, digits the focused chip would capture the next
`Enter` and the keyboard-only person could not save without another `Tab`; returning focus to the panel after a chip
activation (rejected: unexpected focus movement); `Shortcuts/Actions` with an `Intent` per key (12 digit intents and a lookup of
`character` through `LogicalKeySet` cannot express "any digit" and breaks on non-US layouts); a hidden `TextField`
bound to the amount (drags in IME, selection and clipboard behavior the spec did not ask for).

## Decision 6: Pop-ups are bounded in the shared dialog theme, and destructive ones default to Cancel

**Decision**: set `DialogThemeData(constraints: BoxConstraints(minWidth: 280, maxWidth: 560))` once in the shared
theme (`core/theme/`), so every `AlertDialog` in the app (item form, delete-group confirmation, language choice,
biometric offer, discard-changes prompt) is centered and at most 560 dp wide. Escape already dismisses every modal
route (`ModalRoute` installs `DismissIntent` → pop; Flutter `routes.dart`). Enter: the item form submits from its last
text field (`textInputAction: done` → the same handler as the Save button, only when valid); the language and biometric
pop-ups focus their primary button initially; the delete-group confirmation focuses **Cancel** initially, so Enter
cannot delete data by accident.

**Rationale**: the dialog default has only `minWidth: 280` (Flutter `dialog.dart:275`), so width today depends on the
content and the window; one theme entry is the root-cause fix instead of five call-site `ConstrainedBox`es. FR-011's
"Enter to confirm where the pop-up has a clear primary action" does not apply to a destructive confirmation.

**Alternatives considered**: `ConstrainedBox` in each dialog (five copies, drifts); making Enter confirm deletion
(data loss on a stray key).

## Decision 7: Thu nhập changes only its container

**Decision**: Thu nhập keeps its row (`icon · name · 150 dp amount field`, already side by side) and its pinned Save.
Its `ListView` and Save take the 520 dp gutters of Decision 1. No row, controller or formatting change.

**Rationale**: the rows already satisfy FR-008 once the column is 520 dp wide (name and amount are at most 520 dp apart
instead of ~1250), and leaving widget state alone keeps typed amounts across resizes for free.

## Decision 8: Thu chi hub: gutters, plus a hover tint on the read-only balance rows

**Decision**: the hub's `Column` of fixed header (two entry buttons, history link) and `Expanded` balance list takes the
960 dp gutters. The two buttons are `Expanded` in one `Row` and 64 dp high, so they already satisfy FR-009 inside a
bounded column (each at most 480 dp, 48 ≤ 64 ≤ 72); no button change. Balance group cards and rows keep their layout.
A group's header is already an `InkWell` (hover and focus ring from the theme); the read-only child rows had no
hover feedback, so `BalanceItemRow` gains a hover tint (`theme.hoverColor`) and stays non-focusable (nothing on it can be
activated, and a focus ring on a non-interactive row would mislead keyboard and screen-reader users).

**Rationale**: the page is "awkward, not broken" and the clarified layout is one bounded column. Keeping the name left
and the balance right in a 960 dp row is the same pattern the finished Tổng quan and Lịch sử giao dịch use; a hover tint
lets the eye follow a row across the width, which is the measurable meaning the spec's US3 acceptance 3 now gives it.

## Decision 9: Kế hoạch puts each item's allocation box next to its name on wide windows

**Decision**: extract `_FormulaLabel` to a small public widget `ExpenseFormulaLabel` and, at window ≥ 600 dp, render
it inline between the name and the edit/delete buttons with `ConstrainedBox(minWidth: 96, maxWidth: 200)` (sized to its
text, never the row width); below 600 dp it stays below the name as today. The same applies to a top-level leaf's header
in `ExpenseGroupCard`. The outer `ListView` takes 960 dp gutters; the `ReorderableListView.builder` inside it is
unchanged (shrink-wrapped, drag handles intact, so reorder keeps working and `ValueKey(item.id)` cards keep their
`_expanded` state). The pending-changes Save button and the summary banner sit in the same list, so they are bounded by
the same gutters; the Save button is bounded to 360 dp on wide windows and centered (a 900 dp Save bar is the same
"stretched" defect).

**Rationale**: spec US4 / FR-008 / FR-010. Today's label is a `Container(alignment: …)`, which expands to the full row
width (~1250 px at 1440 px) despite the comment saying it sizes to content: that is why it looks like a giant input.

## Decision 10: Final sweep = an automated width × appearance matrix plus a recorded browser pass

**Decision**: add parametrized widget tests (`test/widget/core/adaptive_sweep_{auth,overview_report,history,spending,account,static}_test.dart`,
sharing `test/support/adaptive_sweep.dart`, one file per family of provider fakes) that mount every screen of the
inventory (see `contracts/final-sweep.md`) at 320, 412, 600, 840, 1200, 1600 and 2560 dp wide, light and dark, plus a
500 dp-high window (412 and 1440 wide) and 130 % text size (320, 412 and 1440 wide), and
fail on any framework exception (`RenderFlex overflowed`, `A RenderFlex…`), plus a Playwright pass in Chrome recorded
per screen in the sweep log. Every failure and every defect found by hand (including the gutter wheel defect of
Decision 1 on Tổng quan, Báo cáo and Lịch sử giao dịch, and the sign-in screens if they show it) is fixed in this
feature and listed in the log with the fix.

**Rationale**: FR-018 / SC-003; widget tests cannot see dead zones or hidden-behind-a-bar controls, so the browser pass is
not optional; the automated matrix catches overflow regressions forever at no per-run cost.

## Decision 11: Verification evidence stays out of the repository

**Decision**: browser and device checks are run with throwaway scripts in the session scratchpad and summarized as text
tables in the verification README (`specs/…/verification/README.md`) — no screenshots are committed (owner's
instruction of 2026-10-07). The QA account is used only through `.env.test-credentials` and is never printed; no real
password is ever changed in this feature (none of these screens change credentials).

## Decision 13: The number pad's delete key is labelled (the feature's only new string)

**Decision**: add one localized string, `expenseKeypadDeleteSemantic` (vi "Xóa số cuối", en "Delete last digit"), and use it
as the `Tooltip` message and the `Semantics` label of the `⌫` key. The Kế hoạch reorder drag handle, also icon-only, gets
a `Tooltip` that reuses the existing `expenseControlReorderSemantic` text (no new string; `excludeFromSemantics: true`
because its `Semantics` label already exists).

**Rationale**: the `⌫` key is an `InkWell` around an `Icon`: no tooltip and no semantics label (verified in the source,
`expense_screen.dart` ~lines 405–406, and in the browser, where it was absent from the labelled nodes). Constitution
Principle III requires tooltips on icon-only controls wherever a mouse can be attached and Semantics labels on custom
widgets, and spec FR-014 requires it on wide windows. A tooltip needs text, so the earlier "no new string" assumption
was wrong; FR-016 already permits new text when it exists in both languages. At compact widths the key looks and acts the
same: the only change is the label and a hover/long-press tooltip, an intentional exception recorded in FR-002 and
SC-005.

**Alternatives considered**: a hard-coded string (forbidden: no string literals in widgets); a visible text label on
the key (changes the look at compact, which must not change); labelling only on wide windows (a screen reader on a
phone needs it just as much).

## Decision 12: Delivery as one pull request per story, in order

**Decision**: US1 (with the shared primitives: tokens, `adaptiveGutterFor`, `AdaptiveGutters`) → US2 → US3 → US4 (with
the shared dialog theme) → US5 → US6 → US7. Each is a pull request that passes the full suite alone. Stories 2–6 depend
only on the primitives from US1, never on each other, so they can be reordered after PR 1 without rework (FR-017).
