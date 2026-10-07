# Feature Specification: Adaptive Web Layout for the Remaining Screens

**Feature Branch**: `20261007-100751-adaptive-web-remaining-screens`

**Created**: 2026-10-07

**Status**: Draft

**Input**: User description: "refactor adaptive web cho tất cả các màn hình còn lại và làm theo thứ tự từng trang nhé." (make every remaining screen adaptive on the web, one page at a time, in order)

## Background

Observed on `master` (`80d9a66`) on 2026-10-07, in Chrome with the QA account, at window sizes from phone width up to 1440 px wide.

The app shell already adapts (bottom bar on narrow windows, side rail from 600 dp up), and these screens already keep their content in a bounded, centered column on wide windows: **Tổng quan, Báo cáo, Lịch sử giao dịch, the four sign-in screens (Đăng nhập, Đăng ký, Quên mật khẩu, Đặt lại mật khẩu), Bảo mật and Đổi mật khẩu**. Everything else still lays out as a phone screen stretched to the window:

| Screen | What a person sees on a wide window today |
|--------|--------------------------------------------|
| **Nhập chi tiêu** (Thu chi → Chi tiêu) | The number pad fills the window: keys are about 435 × 198 px. The amount, the pad and the account chooser scroll together as one list while Save is pinned at the bottom, so the bottom pad row (`.`, `0`, delete) and the "Trừ vào khoản nào" account chooser sit **below the visible area** (at 1440 × 900 the `0` key starts at 831 px and the chooser at 1067 px; at 1366 × 650 only the first three pad rows show, and the `7 8 9` row is half-hidden behind Save). They can be reached only by scrolling, and scrolling moves the amount out of sight, so a person cannot see what they are typing. **Typing digits on a physical keyboard does nothing.** At window widths up to about 700 px everything is visible and works. |
| **Nhập thu nhập** (Thu chi → Thu nhập) | Each income row and the Save bar span the whole window; the amount box sits at the far right, far from its label. |
| **Thu chi** (the hub) | Two very wide entry buttons, a full-width history link and a full-width balance list. |
| **Kế hoạch** (Kiểm soát chi tiêu) | One column of group cards; each item's allocation box (its percentage or fixed amount, read-only: editing happens in the item's pop-up) is about 1250 px wide. |
| **Hồ sơ** | Every row spans the window, unlike the Bảo mật screen it opens, which is bounded and centered. |
| **Thông báo** (two entry points) and **Trợ giúp** | "Not available yet" placeholders with no bounded content area. |

The Chi tiêu screen also has a "Quét hoá đơn" (scan receipt) mode; its layout is part of the same page.

## Clarifications

### Session 2026-10-07

- Q: On wide windows, which layout should the remaining pages use — one bounded centered column, a column plus multi-column card grids, or multi-pane / list-detail layouts? → A: One bounded, centered column everywhere (like Tổng quan, Báo cáo and Bảo mật), with label-beside-value reflow inside rows; no multi-column grids and no multi-pane or list-detail layouts in this feature.
- Q: From what window height must the Chi tiêu screen show everything (amount, 12 pad keys, account chooser, Save) without scrolling? → A: From 640 px high (at any width from 600 px up), which covers a 1366 × 768 laptop whose browser view is only about 650 px high; below that the content scrolls and Save stays reachable.
- Q: In what order should the pages be done? → A: By impact, as written: Chi tiêu → Thu nhập → Thu chi → Kế hoạch → Hồ sơ → placeholders → final sweep (a screen that is broken is fixed before one that is merely stretched).
- Q: If the final sweep finds a layout defect on an already-finished screen, what happens? → A: Every defect found is fixed in this feature, whatever its size; the feature is not done while a known layout defect remains on any screen.
- Q: On Chi tiêu, what should Enter do once the amount is valid and an account is chosen? → A: Save, exactly like the Save control (same validity rules; when something is missing it does nothing except explain what, as Save does); no extra confirmation step.

## User Scenarios & Testing *(mandatory)*

Each story is one page, ordered by how much a person is hurt today (a screen that cannot be used first, a screen that merely looks stretched last). Every page can be finished, verified and shipped on its own; the order can be changed without breaking the others.

### User Story 1 - Record an expense on a laptop-sized window (Priority: P1) 🎯 MVP

A person opens Thu chi → Chi tiêu in a desktop or laptop browser, enters the amount, picks which account the money comes out of, and saves — using the mouse, the keyboard, or both — without scrolling or hunting for hidden keys.

**Why this priority**: today the screen is awkward to the point of error on common window sizes (1000 × 700, 1440 × 900, 1366 × 650): the bottom pad row and the account chooser are out of view and reachable only by scrolling, which also hides the amount being typed, and the keyboard does not work. Recording an expense is the app's core action.

**Independent Test**: In 1440 × 900, 1366 × 650 (a typical laptop browser view) and 1000 × 640 browser windows, record an expense of 100.000 ₫ from a chosen account using only the mouse, then another using only the keyboard; both succeed with no scrolling.

**Acceptance Scenarios**:

1. **Given** a 1440 × 900 window, **When** the Chi tiêu screen opens, **Then** the amount, all twelve pad keys (1–9, `.`, `0`, delete), the account chooser and the Save button are all fully visible at once, nothing overlaps, and the pad sits in a bounded, centered panel with keys no taller than 72 dp.
2. **Given** a 1366 × 650 or a 1000 × 640 window, **When** the screen opens, **Then** the same controls are all visible without scrolling.
3. **Given** a window shorter than 640 px (for example 1000 × 500), **When** the screen opens, **Then** the content scrolls, no control is permanently hidden, and the Save button stays reachable; in windows at least 500 px high the amount also stays in view while the pad is used, and below 500 px high (for example a phone held sideways, 844 × 390) the amount scrolls with the pad.
4. **Given** the on-screen pad, **When** the person clicks `1`, `0`, `0`, `0`, `0`, `0`, **Then** the amount reads 100.000 ₫ (zeros and delete are reachable at every window size).
5. **Given** the keyboard, **When** the person types digits and Backspace, **Then** the amount changes exactly as if the matching on-screen keys had been clicked; the decimal separator does what the on-screen `.` key does today (nothing: amounts are whole VND), and other keys do nothing.
6. **Given** a valid amount and a chosen account, **When** the person presses Enter, **Then** the expense is saved exactly as if Save had been clicked; **given** no valid amount or no account, **Then** Enter saves nothing and the screen explains what is missing the way Save does; **given** keyboard focus is on an account that is not yet chosen, a mode tab or the Back button, **Then** Enter activates that control first (it picks the account), and Enter on the account that is already chosen saves, so a keyboard-only person can pick an account and save without leaving the chooser.
7. **Given** account chips, **When** the chooser is shown on a wide window, **Then** up to two rows of chips are visible at once inside the panel (at least eight accounts when their names, and their group names, are up to nine characters long, even in a 600 px-wide window next to the side rail); **given** more accounts than fit in two rows, **Then** the chooser scrolls inside its own two-row area while the amount, the pad and Save stay in view, and every account stays reachable by mouse and keyboard.
8. **Given** an amount already typed and an account chosen, **When** the window is resized across a size boundary (or the browser zoom changes), **Then** the amount, the chosen account and the selected mode (manual / scan) are kept.
9. **Given** the "Quét hoá đơn" mode, **When** it is shown on a wide window, **Then** it uses the same bounded, centered panel and its behavior is unchanged.
10. **Given** a phone-width window (under 600 dp), **When** the screen opens, **Then** it looks and behaves exactly as before.
11. **Given** a mouse, **When** it rests on the delete key, **Then** a tooltip names it, and a screen reader announces the key by that name (it has neither today).

---

### User Story 2 - Record income on a wide window (Priority: P2)

A person opens Thu chi → Thu nhập on a wide window and sees their income sources as a compact, readable list — each source's name next to its amount — with the add and Save controls close at hand.

**Why this priority**: it works today (amounts are typed into real text boxes), but the rows and the Save bar are stretched across the window, so a name and its amount are a screen apart.

**Independent Test**: At 1440 × 900, add two income sources, type their amounts with the keyboard and save; the whole task fits a bounded column with each name beside its amount.

**Acceptance Scenarios**:

1. **Given** a wide window, **When** the screen opens, **Then** the list, the total, the "add another source" control and the Save control sit in a bounded, centered column.
2. **Given** a wide window, **When** an income source is shown, **Then** its name and its amount are side by side with a bounded-width amount box.
3. **Given** many income sources, **When** the list is longer than the window, **Then** the list scrolls while Save stays reachable.
4. **Given** the keyboard, **When** the person types an amount, **Then** the total updates as it does today.
5. **Given** typed amounts, **When** the window is resized across a size boundary, **Then** the typed values are kept.
6. **Given** a phone-width window, **When** the screen opens, **Then** it is unchanged.

---

### User Story 3 - Use the Thu chi hub on a wide window (Priority: P3)

A person lands on Thu chi and finds the two entry actions, the history link and the balance of each account arranged for a wide window instead of stretched.

**Why this priority**: it is the doorway to stories 1 and 2 and the first thing seen on the tab, but nothing is broken — only awkward.

**Independent Test**: At 1440 × 900, the hub shows two entry buttons of reasonable size (48–72 dp high, each at most half the content width) side by side, the history link and the balances, all within a bounded column.

**Acceptance Scenarios**:

1. **Given** a wide window, **When** Thu chi opens, **Then** the content sits in a bounded, centered column.
2. **Given** a wide window, **When** the two entry buttons are shown, **Then** they are side by side, each 48–72 dp high and at most half the width of the bounded area (not tall, not spanning the window).
3. **Given** the balance list, **When** a group is expanded or collapsed, **Then** it works as before, and each balance row (name on the left, balance on the right) shows a hover tint under the mouse so the eye can follow it across the width; a group's header, the only part that can be activated, also shows hover feedback and a visible focus ring from the keyboard.
4. **Given** the history link, **When** it is chosen, **Then** it opens Lịch sử giao dịch as before.
5. **Given** a phone-width window, **When** the tab opens, **Then** it is unchanged.

---

### User Story 4 - Plan spending on a wide window (Priority: P4)

A person opens Kế hoạch (Kiểm soát chi tiêu) on a wide window and edits their groups and items in a bounded layout where each item's name and amount are side by side, with every existing action still available.

**Why this priority**: it is the densest screen (groups, items, edit, delete, reorder, add), so it needs the most care, but it works today.

**Independent Test**: At 1440 × 900, expand a group, edit an item through its pop-up, add an item, reorder two groups and delete an item; each action works and the layout stays bounded.

**Acceptance Scenarios**:

1. **Given** a wide window, **When** Kế hoạch opens, **Then** the banner, the group cards and the add controls sit in a bounded, centered column.
2. **Given** a group card, **When** its items are shown on a wide window, **Then** each item's name and its allocation box (percentage or fixed amount) are side by side and the allocation box has a bounded width.
3. **Given** a wide window, **When** the person expands or collapses a group, edits an item through its pop-up, adds or deletes an item or group, or reorders groups, **Then** each action works as it does on a phone.
4. **Given** the add / edit item pop-up and the delete confirmation, **When** they open on a wide window, **Then** they are centered, fully visible and no wider than 560 dp, and Enter / Escape behave as people expect from a pop-up.
5. **Given** unsaved edits, **When** the window is resized across a size boundary, **Then** the edits are kept.
6. **Given** a phone-width window, **When** the tab opens, **Then** it is unchanged.

---

### User Story 5 - Use Hồ sơ on a wide window (Priority: P5)

A person opens Hồ sơ on a wide window and sees the same bounded, centered column as the Bảo mật screen it leads to, so moving between them does not make the content jump.

**Why this priority**: purely visual consistency; the rows already work.

**Independent Test**: At 1440 × 900, Hồ sơ and Bảo mật show their content at the same column width and position.

**Acceptance Scenarios**:

1. **Given** a wide window, **When** Hồ sơ opens, **Then** the identity header, the appearance and language rows, the menu rows and the sign-out row sit in the same bounded, centered column as Bảo mật.
2. **Given** a wide window, **When** the person goes Hồ sơ → Bảo mật → back, **Then** the content column keeps the same width and horizontal position.
3. **Given** the language choice pop-up and the sign-out action, **When** used on a wide window, **Then** they work as before and the pop-up is centered, fully visible and no wider than 560 dp.
4. **Given** a phone-width window, **When** the tab opens, **Then** it is unchanged.

---

### User Story 6 - See intentional "not available yet" pages on a wide window (Priority: P6)

A person who opens Thông báo (from the bell on Tổng quan or from Hồ sơ) or Trợ giúp on a wide window sees a tidy, centered message inside the bounded content area, with working back navigation.

**Why this priority**: the pages are placeholders; they only need to look deliberate until real content exists.

**Independent Test**: At 1440 × 900, each placeholder shows its icon and message centered within the bounded area and Back returns to the previous screen.

**Acceptance Scenarios**:

1. **Given** a wide window, **When** a placeholder opens, **Then** its message is centered within the bounded content area and nothing is clipped or stretched.
2. **Given** any placeholder, **When** the person presses Back, **Then** they return to the screen they came from.
3. **Given** a phone-width window, **When** it opens, **Then** it is unchanged.

---

### User Story 7 - No screen is left behind at any window width (Priority: P7)

A maintainer can confirm that **every** screen in the app — finished and remaining — has been checked across the whole range of window widths, in light and dark appearance, so nothing is forgotten when the last page lands.

**Why this priority**: it closes the work and prevents the backlog from silently growing back; it adds no new behavior of its own, only fixes for what the sweep finds.

**Independent Test**: For each screen, check widths of 320, 412, 600, 840, 1200, 1600 and 2560 px in both appearances and record that nothing overflows, clips or overlaps.

**Acceptance Scenarios**:

1. **Given** the full list of screens, **When** each is checked across the widths above in light and dark, **Then** there is no overflow, clipped control or overlap, and the result is recorded per screen.
2. **Given** a screen that fails a check, **When** it is found, **Then** it is fixed within this feature — including screens that were already finished — and re-checked; no layout defect is left open.

---

### Edge Cases

- **Very short windows** (about 500 px high) and **browser zoom at 200–400 %** (the window behaves as if it were much narrower): content scrolls, nothing is permanently hidden, and Save is reachable.
- **Very tall windows** (for example 1440 × 1300) and **very wide windows** (2560 px): content stays bounded and centered; the number pad does not grow without limit.
- **Resizing or zooming mid-task** (typed amount, chosen account, expanded groups, unsaved edits, an open pop-up): values and state are kept, and the layout re-flows without a flash of the wrong layout.
- **Keyboard users**: Tab order follows the visual order; the focused control is always visible; keyboard-operable everything that the mouse can do; the physical-keyboard digits and Backspace on Chi tiêu work only while the amount is the active input (they must not fire while another field or pop-up has focus).
- **Pop-ups open during a resize**: stay centered and fully visible.
- **Long group, item or account names** and **large amounts** wrap or truncate cleanly inside the bounded column without pushing controls out.
- **Larger text sizes** chosen in the browser or system: nothing is clipped at narrow widths.
- **Unchanged phone layouts**: at under 600 dp every screen must look and behave exactly as before.
- **Light and dark appearance** on every changed screen.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Each remaining screen (Chi tiêu entry, Thu nhập entry, Thu chi, Kế hoạch, Hồ sơ, and the Thông báo / Trợ giúp placeholders) MUST keep its content in a bounded, horizontally centered area on expanded and larger windows, using the same shared maximum content width as the screens that are already finished; the two entry screens MAY use a narrower reading width because they are centered on a number pad and short lists.
- **FR-002**: At under 600 dp wide, every screen MUST look and behave exactly as it does today; the only exception, at every width, is the delete key of the Chi tiêu number pad, which gains a screen-reader label and a tooltip (FR-014).
- **FR-003**: No screen MAY overflow, clip, overlap or hide a control at any window width from 320 to 2560 px, in any window height down to about 500 px, or at larger text sizes; where the content is taller than the window it MUST scroll.
- **FR-004**: Resizing the window or changing the browser zoom, at any moment, MUST NOT lose typed values, selections (such as the chosen account or mode), expanded/collapsed state or unsaved edits.
- **FR-005**: On Chi tiêu, the amount, all twelve pad keys, the account chooser (two rows of chips at once, which holds at least eight accounts with names of up to nine characters, even in a 600 px-wide window next to the side rail; with more, the chooser scrolls inside its own two-row area) and the Save control MUST all be fully visible at once, without scrolling the screen, in every window at least 600 px wide and 640 px high; in shorter windows the content MUST scroll and Save MUST stay reachable, and in windows at least 500 px high the amount being typed MUST remain visible while the pad is used (below 500 px high the amount scrolls with the pad).
- **FR-006**: On Chi tiêu, the pad MUST have a bounded size that does not grow with the window: keys no taller than 72 dp and the pad no wider than the screen's reading width.
- **FR-007**: On Chi tiêu, a person MUST be able to enter the amount with the physical keyboard — digits and Backspace — with exactly the same results as the matching on-screen keys (the decimal separator maps to the on-screen `.` key, which has no effect today), and MUST be able to save with Enter under the same validity rules as the Save control; the keys MUST act only while the amount is the active input.
- **FR-008**: On wide windows, rows that show a label and a value or an input (income sources, plan items, balance rows) MUST place them side by side, with input and value boxes of a bounded width.
- **FR-009**: On Thu chi, the Thu nhập and Chi tiêu entry buttons MUST sit side by side within the bounded area on wide windows, each 48–72 dp high and at most half the width of that area.
- **FR-010**: On Kế hoạch, expanding and collapsing groups, editing amounts, adding, editing and deleting items and groups, and reordering groups MUST all keep working at every window width.
- **FR-011**: Pop-ups opened from these screens (item add/edit, delete confirmation, language choice, biometric offer) MUST be centered, fully visible and no wider than 560 dp on wide windows and MUST support Enter to confirm and Escape to dismiss where the pop-up has a clear primary action or a cancel.
- **FR-012**: Hồ sơ MUST use the same content column width and position as Bảo mật, so moving between them does not shift the content.
- **FR-013**: The placeholders MUST keep working back navigation and MUST show their message centered inside the bounded area.
- **FR-014**: Interactive elements MUST keep a touch target of at least 48 × 48 dp on every window size, and on wide windows every screen MUST provide hover feedback, tooltips on icon-only controls (the number pad's delete key and the plan screen's reorder handle included), a visible keyboard focus and keyboard activation of primary actions.
- **FR-015**: Both light and dark appearance MUST be correct on every changed screen.
- **FR-016**: No data, balance, saving rule, calculation or wording MAY change; the one new piece of text, the delete key's label and tooltip, and any other new visible text MUST exist in Vietnamese and English.
- **FR-017**: The pages MUST be delivered and verified one at a time in the order of the stories; each page's work MUST NOT depend on a later page.
- **FR-018**: A final sweep MUST check every screen in the app (the finished ones included) across the width range in light and dark appearance, and every layout defect it finds MUST be fixed in this feature, on whichever screen it appears.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In 1440 × 900, 1366 × 650 and 1000 × 640 windows, 100 % of the controls on Chi tiêu (amount, 12 keys, account chooser, Save) are fully visible at the same time, and a person can record an expense of 100.000 ₫ end to end with no scrolling, with the mouse (six keys, one account, Save: eight clicks) or with the keyboard alone, and a scripted run of each flow completes in under 30 seconds.
- **SC-002**: On Chi tiêu, every physical-keyboard key in the supported set (0–9, decimal separator, Backspace, Enter) gives the same result as its on-screen equivalent in 100 % of a scripted test matrix.
- **SC-003**: Across widths of 320, 412, 600, 840, 1200, 1600 and 2560 px, in light and dark, and additionally at 412 and 1440 px in a 500 px-high window and at 130 % text size, every screen in the app shows 0 overflowing, clipped, overlapping or unreachable controls.
- **SC-004**: At 840 px and wider, no remaining screen's content column is wider than the shared maximum content width (entry screens: no wider than their narrower reading width), and the content is horizontally centered within the area beside the rail (within 8 px).
- **SC-005**: Under 600 dp, every changed screen is visually and behaviorally identical to before the change: the existing phone-layout tests pass without modification and a before/after comparison shows no difference (apart from the delete key's new label and tooltip).
- **SC-006**: Resizing across every size boundary in the middle of a task loses 0 typed values, selections or edits on every changed screen.
- **SC-007**: Hồ sơ and Bảo mật show their content at the same column width and position (difference of at most 8 px).
- **SC-008**: Each of the six pages (stories 1–6) is verified and can be shipped independently, in order; after each, the app's full automated test suite passes.

## Assumptions

- **Layout language** follows the finished screens (confirmed by the owner on 2026-10-07): a bounded, centered column using the shared maximum content width (960 dp). No multi-pane or list-detail layouts are introduced here; wide windows get a tidy, readable single column with in-row reflow (label beside value), not extra columns. Multi-column card grids and list-detail layouts stay Out of Scope and can be proposed later if the bounded column proves too plain.
- **Window size classes** are the project's existing ones: compact under 600 dp, medium 600–839, expanded 840–1199, large 1200–1599, extra-large 1600 and up. "Wide" below means medium and above unless a requirement says otherwise.
- **The entry screens' reading width** is expected to be about 480–560 dp (a pad plus a short chooser); the exact value is a planning decision, as long as every control fits in a window 640 px high.
- **Order of delivery** is by impact (Chi tiêu, Thu nhập, Thu chi, Kế hoạch, Hồ sơ, placeholders, then the final sweep), confirmed by the owner on 2026-10-07 in answer to "one page at a time, in order"; because each page is independent, the order could still be rearranged later without rework.
- **Physical keyboard on Chi tiêu**: digits 0–9 add to the amount, the decimal key produces whatever the on-screen decimal key produces today (nothing: the on-screen `.` key is inert because amounts are whole VND), Backspace deletes the last character, and Enter saves when the form is valid, exactly like the Save control (confirmed by the owner on 2026-10-07; no extra confirmation step). Enter first activates a control that has keyboard focus, except that on the account that is already chosen it saves (picking it again would do nothing), so the keyboard-only flow is: digits, Tab to an account, Enter (pick), Enter (save). The keyboard never offers anything the on-screen pad does not.
- **Browser zoom** is treated as a change of window width and height; no separate behavior is required.
- **Scan receipt mode** keeps its current behavior on every platform, including whatever it does on the web today; only its layout is in scope.
- **Dark and light** appearance already exist for these screens; this feature only has to keep them correct.
- **Verification** follows the previous features' practice: real browser at the sizes above (plus the phone-size emulator and simulator for the unchanged compact layouts), light and dark, with automated tests at a compact and an expanded width for every changed screen.

## Out of Scope

- Native desktop apps (Windows, macOS, Linux) and tablet-specific orientation handling.
- Multi-pane, list-detail or card-grid layouts, and any redesign of colors, icons, spacing language or copy.
- New features or behavior: no change to how amounts, balances or plans are calculated or saved.
- Making the web address bar show pushed sub-screens (Thu nhập, Chi tiêu, Lịch sử, Thông báo currently stay on the parent's address) — a separate, small routing change.
- The app lock, PIN fallback and the known cold-start lock race.
- Real content for Thông báo and Trợ giúp, and the receipt-scanning capability itself.
- Redesigning screens that are already adaptive (Tổng quan, Báo cáo, Lịch sử giao dịch, the sign-in screens, Bảo mật, Đổi mật khẩu): they are re-checked in the final sweep and any layout defect found is fixed, but their design does not change.
