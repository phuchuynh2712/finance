# Quickstart: Income Entry & Automatic Allocation ("Thu nhập")

How to verify this feature once implemented, mapped to the spec's acceptance scenarios.

## Prerequisites

- Signed in, with at least one leaf item with a percentage formula and one leaf item with a fixed-amount formula already set up in Kiểm soát chi tiêu (e.g. "Ăn uống" — 20%, "Tiền nhà" — 3.000.000đ fixed)
- `flutter analyze` clean, full `flutter test` suite passing before manual verification
- A device/emulator with the app already at schema v3 (from the prior feature) to exercise the v3→v4 migration realistically, OR a fresh install (schema created at v4 directly)

## Verify: Record income and see it distributed automatically (User Story 1)

1. On "Thu chi", tap "Thu nhập" → confirm it opens the new income-entry screen (not the old "not yet available" placeholder).
2. Enter one income source (e.g. "Lương chính" — 10.000.000đ) → confirm the total shown equals 10.000.000đ.
3. Tap "Lưu thu nhập" → confirm the screen returns to "Thu chi".
4. On "Thu chi", confirm "Ăn uống"'s balance increased by exactly 2.000.000đ (20% of 10.000.000đ) and "Tiền nhà"'s balance increased by exactly 3.000.000đ (its fixed amount) — assuming "Tiền nhà" appears before or after "Ăn uống" per their actual `sortOrder`, confirm both received their full formula share since 10.000.000đ comfortably covers both regardless of order.
5. Leave the amount field blank or enter 0 → confirm "Lưu thu nhập" is blocked with an inline message, and no navigation/allocation happens.

## Verify: Manage multiple income sources before saving (User Story 2)

1. On "Thu nhập", tap "Thêm nguồn thu nhập khác" → confirm a second, empty income source row appears.
2. Enter a name and amount for the second row → confirm the total updates to include both rows.
3. Tap the delete icon on the first row → confirm it disappears and the total recalculates to only the second row's amount.
4. Leave a row's name blank while its amount is filled in → confirm saving is blocked with a message identifying that row.

## Verify: Insufficient income truncates then halts (Edge Case / FR-006, FR-007)

1. Set up three leaf items in `sortOrder`: A (fixed 5.000.000đ), B (fixed 5.000.000đ), C (fixed 5.000.000đ).
2. Enter income of 7.000.000đ and save.
3. Confirm A's balance increased by exactly 5.000.000đ (fully covered).
4. Confirm B's balance increased by exactly 2.000.000đ (all that remained — 7.000.000 − 5.000.000).
5. Confirm C's balance is unchanged (the sequence halted at B; C was never reached).

## Verify: Designate a savings receiver and confirm leftover lands there (User Story 3)

1. In Kiểm soát chi tiêu, open a leaf item's edit dialog → confirm a toggle exists to mark it as the item that receives leftover income, off by default.
2. Turn the toggle on and save → confirm the item is now marked.
3. Attempt to mark a second leaf item as the receiver → confirm the save is blocked with an inline error, and the first item's mark is unchanged.
4. With formulas that intentionally sum to less than 100% of a test income amount (e.g. one 20%-percentage item, income of 10.000.000đ, leftover = 8.000.000đ), save that income → confirm the marked item's balance increased by its own formula's share PLUS the full leftover, in the same save.
5. Open the "add child" dialog for the currently-marked leaf → confirm a warning is shown on that same dialog, before/while creating the child, explaining that saving will clear the parent's savings-receiver mark. Save the child → confirm the parent's mark is now cleared.
6. With no item marked, save an income entry with formulas summing to less than 100% → confirm the leftover is not applied anywhere (no item's balance reflects it) and no error is shown.

## Regression check: existing flows untouched

- Open Kiểm soát chi tiêu → confirm creating, editing, and deleting items/groups still works exactly as before this feature (the only visible change to this screen's dialog is the new savings-receiver toggle on leaf items).
- Open "Thu chi" → confirm "Chi tiêu" and "Xem lịch sử giao dịch" still navigate to their existing "not yet available" placeholders, unaffected by this feature.
- Confirm the app still builds and runs against a pre-existing local database, both for a fresh install (schema created at v4 directly) and an upgrade path (v3 → v4, exercising the new `is_savings_receiver` column migration).
