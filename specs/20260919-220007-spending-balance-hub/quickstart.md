# Quickstart: Spending Balance Hub & Envelope Retirement ("Thu chi")

How to verify this feature once implemented, mapped to the spec's acceptance scenarios.

## Prerequisites

- Signed in, with at least one group with 2+ leaf children and at least one standalone top-level leaf already set up in Kiểm soát chi tiêu (e.g. "Gia đình" with "Ăn uống"/"Điện, nước, rác", plus a standalone "Tiết kiệm")
- `flutter analyze` clean, full `flutter test` suite passing before manual verification
- One test run BEFORE upgrading: a device/emulator with an existing local database at schema v2, containing at least one `Envelope` row (and ideally one `ExpenseEntry` referencing it), to exercise the drop migration realistically
- A fresh app install/DB (or one that has gone through the schema migration) — confirm `balance` defaults to 0 by inspecting a pre-existing item

## Verify: View the current balance of every budget item at a glance (User Story 1)

1. Open the "Thu chi" tab → confirm every top-level item and group from Kiểm soát chi tiêu appears, each showing a balance amount formatted as currency (e.g., "0 đ" for a fresh install, matching FR-011's zero default).
2. Tap a group's row (e.g. "Gia đình") → confirm it expands, showing each child's own balance; tap again → confirm it collapses.
3. Confirm a group's own displayed balance equals the sum of its children's balances (verify arithmetic manually against the values shown).
4. If any item's balance is negative (may require directly editing the DB for this manual check, since no transaction feature exists yet to make it negative) → confirm it renders in the danger color with a visible minus sign.
5. With zero groups/items in Kiểm soát chi tiêu (a fresh user) → confirm "Thu chi" shows a message directing the user to set up items in Kiểm soát chi tiêu first, not an empty/blank list.
6. Create a brand-new item in Kiểm soát chi tiêu (save its formula) → return to "Thu chi" → confirm the new item already appears with a balance of 0, with no separate action needed.

## Verify: Distinguish this screen from the formula-editing screen (User Story 2)

1. On "Thu chi", confirm the balance list section is labeled to indicate actual current balances (e.g. "Số dư từng khoản"), not allocation formulas.
2. Confirm no group/item row on "Thu chi" exposes any percentage/fixed-amount toggle or formula-edit control — everything is read-only.

## Verify: Reach the (future) income/expense actions and history from one hub (User Story 3)

1. Confirm "Thu chi" shows two side-by-side buttons, "Thu nhập" (green/success styling) and "Chi tiêu" (red/danger styling), above the balance list.
2. Confirm a "Xem lịch sử giao dịch" row appears between the two buttons and the balance list.
3. Tap "Thu nhập" → confirm the app navigates to a placeholder screen with a clear "not yet available" message and a way back to "Thu chi" (not a crash, not a silent no-op).
4. Repeat for "Chi tiêu" and "Xem lịch sử giao dịch" → confirm each shows its own placeholder screen (distinct title/message per entry point) with the same back behavior.

## Verify: Bottom navigation shows selection with icon color, not a pill background (User Story 4)

1. Open any tab → confirm the selected tab's icon and label render in brand blue, with no pill/chip-shaped background behind the icon.
2. Confirm unselected tabs render in the existing muted/inactive color, unchanged from before this feature.
3. Switch between tabs several times → confirm the blue highlight always follows the currently selected tab, with no residual background shape left on a previously active tab.
4. Repeat in dark mode → confirm the selected tab's icon/label color matches the design's dark-mode accent (a lighter blue than the primary button color elsewhere in dark mode).

## Verify: Retire the legacy Envelope data model entirely (User Story 5)

1. On a device with a pre-existing v2 database (per Prerequisites), upgrade the app → confirm it launches without crashing, and that Kiểm soát chi tiêu's existing groups/items are all still intact and unchanged.
2. Open the "Tổng quan" tab → confirm it shows the same "not yet available" placeholder pattern as "Báo cáo" (not the old envelope list, not a crash, not a blank screen).
3. Confirm there is no floating action button, menu item, or any other way to reach a "Plan"/income-allocation screen anywhere in the app.
4. Confirm there is no way to reach an "add expense"/"Thêm chi tiêu" form anywhere in the app — the old `ExpenseFormScreen` no longer exists.
5. Run `grep -rn "Envelope\|AllocationEvent\|EnvelopeCoverage\|ExpenseEntry" lib/` from the repo root → confirm zero matches (SC-006).
6. Inspect the local SQLite database file directly (e.g. via a DB browser) → confirm the `envelopes`, `allocation_events`, `allocation_event_lines`, `expense_entries`, and `envelope_coverages` tables no longer exist, and that `expense_control_items` has the new `balance` column with existing rows correctly defaulted to 0.
7. Check the app's background sync logs/behavior → confirm no request to the Supabase `envelope_balances` view is made during a sync pass.

## Regression check: existing flows untouched

- Open Kiểm soát chi tiêu → confirm creating, editing, and deleting items/groups still works exactly as before this feature (formula editing is entirely unaffected).
- Confirm the app still builds and runs against a pre-existing local database, both for a fresh install (schema created at v3 directly) and an upgrade path (v2 → v3, exercising the combined add-column + drop-tables migration step).
