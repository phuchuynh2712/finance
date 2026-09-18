# Quickstart: Expense Control

## Prerequisites

- Flutter SDK matching `pubspec.yaml` (`sdk: ^3.11.0`).
- Repo already builds/runs today (this feature adds to the existing app, no new external services).

## Run the app

```bash
flutter pub get
flutter run
```

Sign in (or use biometric quick login, per the existing auth flow), then tap the **Kiểm soát** tab (2nd tab, right after Tổng quan) to reach the Expense Control screen.

## Manual verification checklist (maps to spec.md's Independent Tests)

1. **US1 — Define a formula**: On an empty plan, confirm the empty state (FR-023) shows with a prominent "Thêm khoản mới" CTA and no allocation banner. Tap it, create "Rent" as a fixed amount of 5,000,000₫, save, and confirm it's listed. Restart the app and confirm it persisted.
2. **US1 — Percentage cap**: Create items until percentages sum to 60%, then try to save one at 45% (would total 105%) — save must be blocked with the total flagged. Then save one at 30% instead — banner should read "90% đã phân bổ, 10% tự do."
3. **US1 — Fixed-item strict cap**: With a fixed-amount item already present and percentages at 70%, try to save a percentage item that would land at exactly 100% — save must be blocked (must be strictly < 100%).
4. **US2 — Grouping**: Create a leaf item, add a child to it — confirm it becomes a group (its own formula input disappears) and the running totals only count the child. Delete the child — confirm the parent reverts to a leaf and regains a formula input.
5. **US2 — Expand/collapse**: With a group containing children, tap the group name to collapse/expand; confirm it's independent of other groups' state.
6. **US3 — Edit name/icon/description**: Tap the pencil on an existing item and edit its name/icon/description via the dialog — confirm the change persists immediately (this dialog does NOT cover the formula; see item 7).
7. **US3 — Inline formula edit + "Lưu công thức"**: With existing items already on screen, type a new value directly into an item's inline value field (or toggle %/₫) — confirm the allocation summary banner updates live to reflect the *pending* (not-yet-saved) change, and confirm the change is NOT yet visible after an app restart at this point. Tap "Lưu công thức" while the pending edit would push the plan over budget — confirm it stays blocked and flags the violating total (FR-012). Fix the value so the plan is valid, tap "Lưu công thức" again — confirm it persists and survives an app restart. Then: make another pending inline edit, switch to a different bottom-nav tab and back to Kiểm soát without tapping "Lưu công thức" — confirm the pending edit was discarded and the field shows the last-saved value (Edge Case).
8. **US3 — Reorder/delete**: Drag-reorder two top-level groups, restart the app, confirm order persisted. Delete a leaf item — confirm it disappears immediately. Delete a group with children — confirm the cascade-delete warning appears before deletion.
9. **US4 — Navigation**: Confirm exactly 5 bottom tabs in order: Tổng quan, Kiểm soát, Thu chi, Lịch sử/Báo cáo, Hồ sơ. Confirm "Thu chi"/"Hồ sơ" (previously "Chi tiêu"/"Cá nhân") now show their existing empty states (old Envelope data was discarded by this feature's DB migration). Confirm "Lịch sử/Báo cáo" opens a placeholder screen, and that the old "Khoản" tab is gone entirely (not a 6th tab).
10. **Locale**: Switch the app language to English and confirm every string introduced by this feature (screen title, banners, buttons, the "Lưu công thức" button and its blocked-state message, validation/confirmation messages, Semantics labels, the two new/renamed tab labels) is translated — not falling back to Vietnamese or a raw key.

## Tests to run before considering the feature done

```bash
flutter analyze
flutter test test/unit/features/expense_control
flutter test test/widget/features/expense_control
flutter test test/integration
```

Domain-layer coverage (percentage/fixed validation, leaf⇄group transitions, totals computation) must stay ≥80% per the Constitution's Testing Standards principle.
