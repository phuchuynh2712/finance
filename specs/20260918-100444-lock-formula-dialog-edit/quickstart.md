# Quickstart: Align Expense Control Screen with Design

How to verify this feature once implemented, mapped to the spec's acceptance scenarios. Requires a signed-in test account with at least one existing group item that has 2+ children (e.g. "Gia đình" with "Ăn uống" and another leaf), so both leaf- and group-dialog paths, and both collapsed/expanded group states, can be exercised.

## Prerequisites

- Signed in, Expense Control tab has at least one group with 2+ leaf children and at least one top-level leaf
- `flutter analyze` clean, full `flutter test` suite passing (including the updated tests from research.md Decision 6) before manual verification

## Verify: Edit a formula through the dialog instead of inline (User Story 1)

1. On the Expense Control list, tap directly on a leaf's allocation-value display (where the old `TextField` used to be) → confirm nothing happens: no keyboard, no cursor, no dialog.
2. Tap that leaf's edit (pencil) icon → confirm a dialog opens pre-filled with its current name, icon, description, allocation mode (%/₫), and allocation value, all editable — the mode selector is the compact pill toggle, not the old dropdown (FR-013).
3. Change the value (e.g. from a percentage to a longer fixed amount like `4000000`) and tap "Lưu" inside the dialog → confirm: the dialog closes, the list's static label now shows the new value in full (not clipped), the allocation-summary banner reflects it, and "Lưu công thức" becomes enabled — then confirm via a fresh app restart *without* pressing "Lưu công thức" that the database value is unchanged (nothing was written yet, SC-002).
4. Reopen the same leaf's edit dialog before pressing "Lưu công thức" → confirm it shows the staged value from step 3, not the original database value (FR-008).
5. Enter a value that would push the total allocation over budget and tap "Lưu" inside the dialog → confirm the dialog stays open with an inline over-budget error and nothing was staged (FR-006).
6. Tap the edit (pencil) icon on a **group** (not a leaf) → confirm the dialog shows only name/icon/description — no formula/mode/value fields (FR-003).

## Verify: Commit staged formula changes explicitly (User Story 2)

1. Stage edits for two different leaves via their dialogs (per User Story 1 steps above) → confirm neither is in the database yet, then press "Lưu công thức" → confirm both are now persisted (check via a fresh restart) and the button becomes disabled again.
2. Stage a combination of edits that together exceed the allowed budget → press "Lưu công thức" → confirm the save is blocked, the offending total is identified in the error, and nothing was written.
3. With zero staged edits, confirm "Lưu công thức" is not shown (or is disabled).

## Verify: Warn before losing unsaved staged edits by switching tabs (User Story 3)

1. Stage a formula edit via a dialog, then tap a different bottom-navigation tab (e.g. Tổng quan) → confirm a confirmation prompt appears with exactly three buttons: "Lưu", "Không lưu", "Hủy" — and that navigation has not yet happened.
2. Tap "Lưu" → confirm the staged edit is persisted (same validation as "Lưu công thức") and only then does the tab switch complete.
3. Repeat with a fresh staged edit, this time tap "Không lưu" → confirm the staged edit is discarded (not persisted) and the tab switch completes immediately.
4. Repeat again, this time tap "Hủy" → confirm you remain on the Expense Control tab and the staged edit is still intact (reopen its dialog to confirm).
5. Stage an over-budget combination, trigger the tab-switch prompt, tap "Lưu" → confirm the error surfaces inside the prompt, the staged edits remain intact, and navigation does not proceed.
6. With zero staged edits, tap a different tab → confirm navigation happens immediately with no prompt.

## Verify: Group allocation summary shown only when collapsed (User Story 4)

1. Collapse a group whose name + summary text is long enough that it used to show "..." → confirm the full summary text is now visible, wrapped across as many lines as needed, with no truncation.
2. Expand that same group → confirm the summary line disappears entirely — only the name/icon/edit/delete header row remains above the now-visible children.
3. Toggle collapsed ⇄ expanded a few times → confirm the summary's visibility updates immediately each time.

## Verify: Bottom navigation bar visual details match the design (User Story 5)

1. Open any screen and look at the bottom navigation bar → confirm the selected tab's indicator pill is the app's brand primary color (matching, e.g., the "Lưu công thức" button's color), not the default teal.
2. Look at all five tab labels → confirm every one ("Tổng quan", "Kiểm soát", "Thu chi", "Báo cáo", "Hồ sơ") renders on a single line, none wrapping to two.
3. Look at the top edge of the bar → confirm a thin border line is visible separating it from the screen content above.
4. Switch between all five tabs → confirm the indicator color and single-line labels hold on every tab, not just the first.

## Regression check: existing flows untouched

- Create a brand-new item via "Thêm khoản mới" → confirm it still saves immediately (no staging) — Assumption §4.
- Edit a group's name/icon/description → confirm it still saves immediately, exactly as before this feature (FR-003).
- Run the full existing Expense Control quickstart/test suite from `specs/20260904-144604-expense-control/quickstart.md` where still applicable, to confirm nothing outside this feature's scope regressed.
