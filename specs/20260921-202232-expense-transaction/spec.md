# Feature Specification: Expense Transaction Recording

**Feature Branch**: `20260921-202232-expense-transaction`

**Created**: 2026-09-21

**Status**: Draft

**Input**: User description: "Trao đổi bằng tiếng việt. viết spec, plan,... code bằng tiếng anh. Đọc tất cả nội dung trong folder \"E:\Study\design\bao-cao-package\". Lưu giữ những cái liên quan để làm reference về lâu dài. Tôi muốn làm trang báo cáo để xem." — refined during specification: the requested "Báo cáo" (Report) screen has no real data to report on, because the app currently has no transaction history at all (income only accumulates into each budget item's running `balance`, and there is no way to record an actual expense against that balance). The user confirmed building the full transaction-recording layer first — this feature — with the "Báo cáo" screen itself deferred to a follow-up feature that reads from what this one produces. Design reference for this feature's own screen ("Chi tiêu") was found at `E:\Study\design\chi-tieu-package`, following the "Chi tiêu" button already present on the Thu chi (Spending) screen, which currently opens a placeholder.

## Clarifications

### Session 2026-09-21

- Q: When recording an expense, does the user pick a specific budget item (khoản) to deduct from, or can an expense be unassigned? → A: The user picks one budget item per expense (optional at the picker-UI level per the reference mockup's scroll list, but required to actually submit — the reference has no "no item selected" example and the whole point of tracking is knowing which item absorbed the spend).
- Q: If an expense amount exceeds the picked item's current balance, is the transaction blocked or allowed to go negative? → A: Allowed to go negative — the app only warns (the reference mockup's preview banner explicitly renders a negative-balance example: "-600.000 đ" in red), it never blocks the save action.
- Q: Should this feature also start recording income as timestamped history (not just accumulating into `balance`), since a future Report screen needs both income and expense history by month? → A: Yes — a `financial_transactions`-style history is needed for both income and expense records; income recording (`applyIncomeAllocation`) is updated to also insert one history row per allocation so the same table backs both directions (see FR-013).
- Q: The "Quét hoá đơn" (Scan receipt) mock result includes a merchant name (e.g. "Coopmart") — should the transaction record gain an optional note/merchant column now, to avoid a second schema migration when real OCR is built later? → A: No — scanning only needs to capture the correct amount and let the user pick which budget item to deduct from, identical to manual entry; it does not need a merchant name. If a name/note field is ever added, it must apply consistently to manual entry too (the same picked-item + amount + optional label shape for both entry paths), not be introduced asymmetrically via the scan path alone — deferred as a future, symmetric enhancement rather than added here (see FR-014).
- Q: Does recording an income allocation's history need to be atomic with the balance increments it produces, the same way FR-009 requires for expenses? → A: Yes — one "Lưu thu nhập" action is one atomic unit of work covering every affected item's balance increment AND every corresponding history row together; a partial outcome (balances updated but history missing, or vice versa) is never acceptable, symmetric to how an expense's balance-decrement-plus-history-write must succeed or fail together (see FR-013, SC-004).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Record an expense against a budget item (Priority: P1)

A user just paid for something (e.g. groceries) and wants to log it against their "Ăn uống" (Food) budget item so its remaining balance reflects reality. They open the "Chi tiêu" screen from Thu chi, type the amount, pick the item, see a live preview of what that item's balance will be after this transaction, and save.

**Why this priority**: This is the only capability the app currently lacks that blocks every other money-out feature (transaction history, monthly reports, "how much do I have left" accuracy). Every other story in this feature is a refinement of this core loop.

**Independent Test**: From Thu chi, tap "Chi tiêu", enter an amount, pick a budget item, confirm the preview shows the item's balance minus the amount, tap "Lưu giao dịch", and verify on Thu chi that the item's balance decreased by exactly that amount.

**Acceptance Scenarios**:

1. **Given** the user is on the "Chi tiêu" screen with the "Nhập tay" (Manual entry) tab active (the default), **When** they type an amount, pick a budget item from the horizontal list, and tap "Lưu giao dịch", **Then** the picked item's balance decreases by the entered amount, a new expense transaction record is created with the current timestamp, and the user returns to Thu chi seeing the updated balance.
2. **Given** the user has entered an amount and picked an item, **When** the picked item's current balance is less than the entered amount, **Then** the preview banner shows the resulting (negative) balance in a distinct warning color, but the "Lưu giao dịch" button remains enabled and saving still succeeds.
3. **Given** the user has entered an amount of 0 or left it blank, **When** they attempt to tap "Lưu giao dịch", **Then** the save is blocked with an inline message, and no transaction is created.
4. **Given** the user has entered a valid amount but has not picked a budget item, **When** they attempt to tap "Lưu giao dịch", **Then** the save is blocked with an inline message identifying that a budget item must be picked, and no transaction is created.
5. **Given** the user picks a different budget item after already picking one, **When** the preview banner re-renders, **Then** it reflects the newly picked item's own current balance (not the previously picked item's), and the "Trừ vào khoản nào" list visibly shows the newly picked item as selected.

---

### User Story 2 - Live preview of the resulting balance (Priority: P2)

While filling out an expense, the user wants to see, before committing, exactly what the picked item's balance will become — so they can catch a typo or reconsider before saving.

**Why this priority**: This is a refinement of US1's data (US1 already computes and persists the same math) — it's the always-visible confirmation surface, not new business logic, so it's ranked below the core save flow but still core to the reference design's own emphasis (the mockup gives it a dedicated, color-coded banner).

**Independent Test**: On the "Chi tiêu" screen, change the amount or the picked item and confirm the preview banner's text and color update immediately, without needing to save first.

**Acceptance Scenarios**:

1. **Given** an item is picked and a valid amount is entered, **When** either value changes, **Then** the preview banner immediately recalculates and displays "Sau giao dịch này, "[tên khoản]" còn lại **[số tiền]**" using the item's current balance minus the entered amount.
2. **Given** the resulting balance would be zero or positive, **When** the preview renders, **Then** it uses the neutral/informational color styling (not the warning color).
3. **Given** the resulting balance would be negative, **When** the preview renders, **Then** it uses the warning (danger) color styling, and the displayed amount shows the negative value.
4. **Given** no item is picked yet, or the amount is blank/zero, **When** the screen renders, **Then** no preview banner is shown at all.

---

### User Story 3 - Scan-a-receipt tab (UI scaffold only) (Priority: P3)

A user wants a faster way to log an expense by pointing their camera at a paper receipt, instead of typing the amount manually.

**Why this priority**: The reference design explicitly scopes this tab as a static UI mockup — no real OCR/image-recognition logic is part of this feature (per the design package's own notes). It's included at low priority purely so the segmented tab control and its placeholder content exist and don't look broken; real receipt-scanning is out of scope entirely (see Out of Scope).

**Independent Test**: From the "Chi tiêu" screen, tap the "Quét hoá đơn" (Scan receipt) tab and confirm it renders the camera-frame placeholder, the "Chụp hoá đơn" button, and (after tapping it) the static "recognized" mock card — with no real camera capture or recognition occurring.

**Acceptance Scenarios**:

1. **Given** the user is on the "Chi tiêu" screen, **When** they tap the "Quét hoá đơn" tab, **Then** the manual-entry content is replaced by the camera-frame placeholder and the "Chụp hoá đơn" button, matching the reference design.
2. **Given** the user is on the "Quét hoá đơn" tab, **When** they tap "Chụp hoá đơn", **Then** a static, hard-coded "recognized" result card is shown (per the reference mockup's mock data) — no real image is captured or processed.
3. **Given** the "recognized" mock card is shown, **When** the user picks a leaf budget item via its picker and taps "Xác nhận & lưu", **Then** the same save behavior as US1 applies using the mock card's hard-coded amount and the picked item, producing a real expense transaction — the mock's merchant text is not persisted (per Clarifications).

---

### Edge Cases

- What happens if the user rapidly taps "Lưu giao dịch" more than once? The second tap MUST NOT create a duplicate transaction — the button MUST be disabled while a save is in progress (existing pattern already used by the app's other save flows).
- What happens if the picked budget item is a group (has children) rather than a leaf? Only leaf items (items with no children, the same restriction the existing formula-editing screen already applies) are selectable in the "Trừ vào khoản nào" list — a group has no directly-editable balance of its own (its displayed balance is the sum of its children's), so deducting from it would be ambiguous.
- What happens if there are zero leaf budget items at all (a brand-new user who hasn't set up Kiểm soát chi tiêu yet)? The "Trừ vào khoản nào" list is empty and a message directs the user to set up Kiểm soát chi tiêu first, mirroring the existing empty-state pattern used by the Income screen (FR-018 of the income-allocation feature).
- What happens to the amount's currency formatting while the user is actively typing on the custom keypad? Matches the existing shared currency-formatting convention already used elsewhere in the app (grouped digits, VND suffix) — reformatted live as digits are entered, since this screen's keypad is the only input method (no raw text field to lose cursor position in).
- What happens if the user navigates away (back button) mid-entry without saving? No transaction is created and no balance changes — this screen has no autosave/draft-persistence behavior, matching how the existing Income screen's entry state is also fully discarded on navigating away without saving.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST replace the "Chi tiêu" button's current placeholder destination (on the Thu chi screen) with a real "Chi tiêu" screen.
- **FR-002**: The "Chi tiêu" screen MUST present two tabs — "Nhập tay" (default/active) and "Quét hoá đơn" — as a segmented control, matching the reference design.
- **FR-003**: On the "Nhập tay" tab, the user MUST be able to enter a monetary amount via a dedicated numeric keypad (digits 0-9, decimal separator, backspace) — not the device's system keyboard.
- **FR-004**: On the "Nhập tay" tab, the system MUST display a horizontally scrollable list of the user's leaf (non-group) budget items from Kiểm soát chi tiêu, each showing its name and its parent group's name (if any), allowing exactly one to be picked at a time.
- **FR-005**: The system MUST display a live preview banner showing the picked item's current balance minus the entered amount, updating immediately whenever the amount or the picked item changes, once both an amount and an item are present.
- **FR-006**: The preview banner MUST use a distinct warning (danger) color when the resulting balance would be negative, and a neutral/informational color otherwise.
- **FR-007**: The system MUST NOT show any preview banner when the amount is blank/zero or no item has been picked.
- **FR-008**: The "Lưu giao dịch" (Save transaction) action MUST be blocked, with an inline message, when the amount is blank or zero, or when no budget item has been picked.
- **FR-009**: On a successful save, the system MUST atomically (a) create a new expense transaction record carrying the amount, the picked item's id, and the current timestamp, and (b) decrement the picked item's `balance` by that amount — both MUST succeed or both MUST fail together (no partial state).
- **FR-010**: The system MUST allow a budget item's `balance` to go negative as a result of an expense transaction — it MUST NOT block the save when the amount exceeds the item's current balance (per Clarifications).
- **FR-011**: Only leaf budget items (items with no children) MUST be selectable in the "Trừ vào khoản nào" picker — group items MUST NOT appear in this list.
- **FR-012**: The "Quét hoá đơn" tab MUST render the camera-frame placeholder, the "Chụp hoá đơn" action, and — after tapping it — a static mock "recognized" result showing a hard-coded amount, per the reference design; the user picks which budget item to deduct from via the same kind of picker used on the "Nhập tay" tab (not a hard-coded target). The mock's merchant text ("Coopmart" in the reference) is display-only flavor on this static mock screen and is NOT persisted anywhere (per Clarifications — recording a merchant/note name is deferred, and would need to apply to both entry paths symmetrically if ever added). Tapping "Xác nhận & lưu" MUST create a real expense transaction using the same save behavior as FR-009, using the mock card's amount and the picked item. No real camera capture or receipt-recognition logic is implemented (see Out of Scope).
- **FR-013**: The system MUST record every income allocation (each "Lưu thu nhập" action from the existing Income screen) as one or more timestamped history entries in the same underlying transaction history the expense recording in this feature writes to — so that a future report can read both income and expense history from a single, consistent source. This does not change the existing income-allocation math or the `balance` increments it already performs (per the income-allocation feature); it adds a history record alongside that existing behavior. Per Clarifications, this MUST be atomic exactly like FR-009: for a single "Lưu thu nhập" action, every affected budget item's `balance` increment AND every corresponding income transaction history row MUST succeed together or fail together — there MUST be no outcome where the balances reflect the allocation but the history is missing some or all of it, or vice versa. One income allocation touching multiple budget items is still ONE atomic unit of work, not one atomic step per item.
- **FR-014**: Every transaction record (income or expense) MUST carry, at minimum: an amount, the budget item it affected, a direction (income vs. expense), and a timestamp — sufficient for a future feature to group and total them by month and by item. No merchant/note field is included in this feature (per Clarifications); it is deferred as a future, symmetric enhancement across both entry paths if ever needed.
- **FR-015**: The "Chi tiêu" screen's visual style (colors, spacing, icons, typography) MUST follow the existing design token system already implemented in the app (`AppColors`/`AppSemanticColors`), matching the reference mockup's intent even where an exact token name differs (the same convention already established by prior features).

### Key Entities

- **Expense Transaction**: A single record of money leaving a specific budget item — amount, the budget item id, and the moment it was recorded. Always associated with exactly one leaf budget item.
- **Income Transaction** *(new history record, not a new allocation mechanism)*: A single record of one income-allocation event's effect on one budget item — the same shape as an Expense Transaction but recording money arriving rather than leaving, written automatically whenever an income allocation runs (FR-013). One "Lưu thu nhập" action can produce several Income Transaction rows (one per budget item the allocation touched), mirroring how one allocation already produces several `balance` deltas today.
- **Financial Transaction** *(the shared underlying record both of the above are)*: amount, budget item id, direction (income/expense), timestamp — the minimal shape a future Report feature needs to reconstruct monthly totals and per-item breakdowns.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can record an expense against a budget item, from opening the "Chi tiêu" screen to seeing the updated balance on Thu chi, in under 15 seconds for a typical entry.
- **SC-002**: 100% of saved expense transactions result in both a persisted transaction record and a correctly decremented budget item balance — never one without the other, verified even under a simulated write failure mid-save.
- **SC-003**: The live preview banner reflects the correct post-transaction balance and correct color (neutral/warning) within one UI frame of any amount or item-selection change — no stale or delayed preview.
- **SC-004**: Every income allocation performed after this feature ships produces a matching set of income transaction history rows whose total exactly equals that allocation's total distributed amount, verified for both a fully-covered allocation and a truncated (insufficient-income) allocation — and, symmetric to SC-002, never produces a partial outcome (balances updated with no matching history, or history written with no matching balance update), even under a simulated write failure mid-allocation.

## Assumptions

- The reference mockup at `E:\Study\design\bao-cao-package` (the "Báo cáo" package) is preserved for the follow-up feature that will consume this feature's transaction history — it is not implemented as part of this feature, and its own reference files will be copied into that follow-up feature's own spec directory when that feature is specified. This feature's Assumptions section notes its existence only so the connection between the two features is traceable.
- "Nhập tay" produces a real expense transaction with real persistence; "Quét hoá đơn" (FR-012) produces a real expense transaction too, but only after a user taps through a hard-coded mock "recognition" result — there is no image capture, upload, or OCR processing anywhere in this feature. Building actual receipt scanning/OCR is a distinct, larger feature explicitly out of scope here.
- The currently existing `expense_control_items.balance` column remains the single source of truth for "how much is left in this item right now" — this feature does not introduce a separate running-total mechanism; it decrements that same column, exactly as the existing income-allocation feature increments it.
- Editing or deleting a previously saved expense transaction is out of scope for this feature (see Out of Scope) — once saved, a transaction and its balance effect are final within this feature's scope.
- The reference design's dark-mode preview banner screenshot renders with the same (light-mode-looking) danger-soft background as the light-mode screenshot rather than a dark-mode-adjusted tint — this is treated as a mockup rendering artifact to resolve using the app's existing dark-mode danger/success token pair during implementation, not copied literally (the same category of mockup inconsistency identified and resolved in the prior Profile-settings feature).
- Manual emulator walkthrough (T025) caught a real implementation bug, since fixed: the preview banner's neutral state and the "Quét hoá đơn" camera frame both used `theme.colorScheme.primaryContainer`/`primary` as background/foreground, but `AppTheme.light`/`AppTheme.dark` never set `primaryContainer` (it silently falls back to Flutter's default Material You seed, unrelated to the brand palette), making the text effectively invisible against it. Fixed by switching both to `AppSemanticColors.primarySoft` (already the correct brand-blue-50/blue-16%-alpha token, symmetric with the existing `dangerSoft` usage on the negative-balance branch). Confirmed visually on-device after the fix; the widget test asserting the banner's background color was also corrected — it had been comparing `primaryContainer` against itself, a tautology that passed while the pixels were invisible.
- Known, accepted deviation from `reference/chi-tieu-spec.md`: the mockup specifies "Chi tiêu" opens with no bottom nav bar, but the implemented `ExpenseScreen` (reached via `Navigator.push`, same as `IncomeScreen`) keeps the app's bottom nav visible, matching `IncomeScreen`'s own existing (pre-this-feature) behavior. Not fixed here because it's a shared navigation-shell pattern both screens inherit, not something unique to this feature — changing it for `ExpenseScreen` alone would create an inconsistency with `IncomeScreen` rather than resolve one. Revisit both screens together if this is ever prioritized.

### Out of Scope

- The "Báo cáo" (Report) screen itself — reading and aggregating this feature's transaction history by month is a separate, follow-up feature.
- Real camera capture and OCR/receipt-recognition logic for the "Quét hoá đơn" tab — only the static UI scaffold and its mock "recognized" result, per the reference design's own explicit note.
- Editing or deleting an already-saved transaction.
- Any list/history view of past transactions within this feature (e.g. the existing "Xem lịch sử giao dịch" row on Thu chi remains a placeholder — populating it is also a follow-up feature that would read from the same transaction history this feature creates).
- Recording expenses against a group budget item, or against no item at all.
- Undo/reversal of a saved transaction.
