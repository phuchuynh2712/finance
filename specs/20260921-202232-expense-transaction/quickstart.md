# Quickstart: Manual Verification

Run these after implementation, on a real device/emulator, to confirm each user story independently.

## Prerequisites

- Signed in, with at least 2 leaf items set up in Kiểm soát chi tiêu (one with a comfortable balance, one with a small balance for the negative-balance scenario).

## US1: Record an expense (P1)

1. From Thu chi, tap "Chi tiêu".
2. On the "Nhập tay" tab (default), enter an amount using the keypad.
3. Pick a leaf item from the "Trừ vào khoản nào" list.
4. **Verify**: The preview banner shows the item's balance minus the entered amount, in neutral color.
5. Tap "Lưu giao dịch".
6. **Verify**: Returns to Thu chi; the picked item's displayed balance decreased by exactly the entered amount.

## US1 edge cases

1. Leave the amount blank, tap "Lưu giao dịch" → blocked with an inline message, no navigation.
2. Enter a valid amount but pick no item, tap "Lưu giao dịch" → blocked with an inline message, no navigation.
3. Pick the small-balance item, enter an amount larger than its balance.
4. **Verify**: Preview banner shows the negative result in danger color; "Lưu giao dịch" remains tappable.
5. Tap "Lưu giao dịch" → succeeds; the item's balance on Thu chi is now negative, displayed as such.

## US2: Live preview (P2)

1. On "Chi tiêu", pick an item, enter an amount.
2. Change the amount → **verify** the banner updates immediately without needing to save.
3. Pick a different item → **verify** the banner switches to reflect the newly picked item's own balance, not the previous one.
4. Clear the amount or deselect (if possible) → **verify** the banner disappears entirely.

## US3: Scan-a-receipt tab (P3)

1. On "Chi tiêu", tap the "Quét hoá đơn" tab.
2. **Verify**: Camera-frame placeholder and "Chụp hoá đơn" button render, no manual-entry content visible.
3. Tap "Chụp hoá đơn".
4. **Verify**: A static "Đã nhận diện" mock card appears with a hard-coded amount, plus its own leaf-item picker.
5. Pick an item, tap "Xác nhận & lưu".
6. **Verify**: Returns to Thu chi; the picked item's balance decreased by the mock's hard-coded amount — same effect as US1.

## Cross-cutting: income allocation now also produces history (FR-013)

1. Go to Thu nhập, enter one or more income sources totaling an amount that covers every leaf item's formula.
2. Tap "Lưu thu nhập".
3. **Verify** (requires dev/debug DB inspection): one `financial_transactions` row with `direction: income` exists for every leaf item that received a non-zero delta, all sharing the same `occurredAt`, and the sum of their `amount`s equals the total income entered.
4. Repeat with an income amount too small to cover every item (truncated allocation) — **verify** history rows exist only for the items that actually received a non-zero delta, matching `IncomeAllocationResult.deltas`.

## Cross-cutting: atomicity (requires dev/debug fault injection or code inspection)

1. Confirm (via code review or a debug build with a simulated write failure) that `recordExpense` and the income-allocation history insert both live inside their respective single `_db.transaction()` — a failure partway through leaves neither balance nor history changed, never one without the other (FR-009, FR-013, SC-002, SC-004).

## Dark mode

1. Switch to dark appearance (Hồ sơ → Giao diện → Tối).
2. Repeat the negative-balance scenario from US1 edge cases.
3. **Verify**: The preview banner's danger styling uses the app's actual dark-mode danger tokens, not a light-looking background (research.md Decision 11 — a known mockup rendering artifact to NOT replicate literally).
