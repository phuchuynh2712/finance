# UI State Contract: "Chi tiêu" Screen

## Read side — what the "Nhập tay" tab renders

| Element | Source | Behavior |
|---|---|---|
| Amount display | Screen-local state (`int? amount`, raw digits accumulated from the keypad) | Rendered formatted via `CurrencyFormatter.format` at all times — no cursor-position concern since the keypad is the only input method (research.md Decision 9). |
| "Trừ vào khoản nào" list | `ExpenseControlPlanService`'s leaf-flattening (promoted to public — research.md Decision 8), fed from `ref.watch(expenseControlItemsStreamProvider)` | Horizontal list of leaf items only (FR-011), each showing name + parent group name if any (FR-004). Empty state (`EmptyStateView`) if zero leaf items exist (Edge Cases). |
| Picked item | Screen-local state (`String? pickedItemId`) | Exactly one at a time; tapping a different item replaces the previous pick (US1 Scenario 5). |
| Preview banner | Derived: `pickedItem.balance - amount`, only computed/shown when both `amount > 0` and `pickedItemId != null` (FR-007) | Neutral color when result `>= 0`, danger color when result `< 0` (FR-006). Text: `Sau giao dịch này, "[tên khoản]" còn lại **[số tiền]**` (US2 Scenario 1). |
| "Lưu giao dịch" button | Enabled state: `amount > 0 && pickedItemId != null && !isSubmitting` | Disabled (not hidden) while `isSubmitting`, preventing double-submit (Edge Cases). |

## Write side — user actions

| Action | Trigger | Effect |
|---|---|---|
| Tap a keypad digit/decimal/backspace | Keypad button tap | Updates screen-local `amount`. No persistence. |
| Tap a leaf item in the picker | Item tap | Updates screen-local `pickedItemId`. No persistence. |
| Tap "Lưu giao dịch" | Button tap, only reachable when enabled | `ref.read(expenseControlRepositoryProvider).recordExpense(itemId: pickedItemId!, amount: amount!)`. On success: `Navigator.pop()` back to Thu chi (matching the Income screen's own post-save navigation). On failure: inline error, `isSubmitting` reset to `false`, no navigation. |

## Read/write side — the "Quét hoá đơn" tab (US3, P3)

| Element | Source | Behavior |
|---|---|---|
| Camera-frame placeholder + "Chụp hoá đơn" button | Static | No real camera access (Out of Scope). |
| "Đã nhận diện" mock card | Static, hard-coded amount per the reference mockup | Shown only after "Chụp hoá đơn" is tapped (US3 Scenario 2). Includes its own leaf-item picker, same component as the "Nhập tay" tab's picker (FR-012 — not a hard-coded target). |
| "Xác nhận & lưu" button | Button tap | Same `recordExpense` call as "Nhập tay"'s "Lưu giao dịch", using the mock's hard-coded amount and this tab's own picked item (US3 Scenario 3). The mock's merchant text is display-only and never reaches `recordExpense` (Clarifications). |

## Repository contract

```dart
// lib/features/expense_control/domain/expense_control_repository.dart
abstract interface class ExpenseControlRepository {
  // ... existing methods unchanged ...

  /// FR-009/FR-010: atomically decrements [itemId]'s balance by [amount] and
  /// records one expense Financial Transaction row. [amount] MUST be > 0.
  /// [itemId] MUST be a leaf item (not enforced here — the picker only
  /// offers leaf items, FR-011). The balance is allowed to go negative;
  /// this method never blocks or throws for that reason (FR-010).
  Future<void> recordExpense({required String itemId, required int amount});
}
```

`applyIncomeAllocation`'s existing signature is UNCHANGED — `Future<void> applyIncomeAllocation(Map<String, int> balanceDeltas)`. Its behavior grows (research.md Decision 6) to also write one income Financial Transaction row per non-zero entry, inside the same transaction, but no caller (including `IncomeFormController.save()`) needs to change.

## `AppPreferencesStorage`-equivalent: none needed

Unlike the Profile-settings feature, this feature introduces no new device-level preference — all state here is either screen-transient (amount, picked item) or persisted straight to Drift via the repository. No new storage abstraction is needed.
