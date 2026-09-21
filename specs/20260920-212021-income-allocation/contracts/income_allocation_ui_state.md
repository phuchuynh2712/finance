# UI Contract: Income Screen State & Allocation Write Path

This feature's network/API contract is an additive column on the remote schema (see data-model.md). What this file documents is the **contract between `IncomeScreen` and the domain/data layers it drives** — the income-entry state shape, the allocation write path, and the savings-receiver toggle's contract with the existing item create/edit dialog — so implementation matches research.md's decisions exactly.

## Read-side contract: what `IncomeScreen` reads before allocating

`IncomeScreen` MUST read from the same `expenseControlTreeProvider` (or an equivalent provider already wrapping `ExpenseControlPlanService.buildTree()`) that `SpendingScreen` and Kiểm soát chi tiêu already use — NOT a new provider, NOT a second query path for the same items. It passes that tree, plus the validated total from its own income-source-line-items state, into the new allocation function (data-model.md's "New computation" section).

| Data | Source | Notes |
|---|---|---|
| The tree of items eligible for allocation | `expenseControlTreeProvider` | Same stream every other screen reading items already uses |
| Income source line items (name, amount) | New screen-local state (`income_providers.dart`) | Transient — never read from or written to any repository; exists only for the duration of this screen |
| Total income amount | Derived (sum of the above) | Recomputed live as rows are added/removed/edited (FR-003) |

## Write-side contract: what happens on save

1. Validate (FR-004): total `> 0`, every row has a non-empty name and a positive amount. If invalid, block save, show inline errors, do not proceed to steps 2–4.
2. Run the pure allocation function (data-model.md) against the current tree snapshot and the validated total. This produces a delta map (`Map<String, int>`, item id → amount to add) and an `unallocatedAmount` (see data-model.md step 5).
3. Call `ExpenseControlRepository.applyIncomeAllocation(deltaMap)` — a single call, one transaction, one set of outbox rows (data-model.md's Contract section). The delta map can legitimately be empty (e.g. the tree has zero leaves, or every leaf's formula produced a zero share and no savings receiver was marked to catch a leftover) — this call is a no-op in that case (an empty map is valid input, not an error).
4. On success, navigate back to "Thu chi" (`Navigator.pop` — this screen is reached via `Navigator.push` from `SpendingScreen`, per spec.md Assumptions: no bottom-nav tab of its own). On failure, keep the user on "Thu nhập" with the entered income line items still present, and show an error — nothing was persisted (FR-014's atomicity guarantee means there is no partial-success state to reconcile the UI against).

`IncomeScreen` MUST NOT call `ExpenseControlRepository.create()`, `.update()`, `.delete()`, `.reorderTopLevel()`, or `.saveFormulas()` — the only write this feature performs is the one `applyIncomeAllocation()` call per successful save (spec.md FR-014).

## Contract: the savings-receiver toggle in the existing create/edit dialog

| Trigger | Behavior |
|---|---|
| Opening the create/edit dialog for a leaf item (no children) | Toggle is visible and interactive, reflecting the item's current `isSavingsReceiver` value (`false` for a brand-new item) |
| Opening the create/edit dialog for a group (has children) | Toggle is NOT shown — mirrors how formula fields are already hidden for a group in this same dialog (FR-010) |
| User turns the toggle on and saves, no other item currently marked | Save succeeds; this item's `isSavingsReceiver` becomes `true` |
| User turns the toggle on and saves, another item is already marked | Save is blocked entirely (not just the toggle — the whole dialog's save action), with an inline error naming the conflict (FR-009); the dialog remains open with the user's other staged edits intact so they can turn the toggle back off and retry |
| The user opens the "add child" dialog for an item currently marked `true` as the savings receiver | The dialog itself MUST show an inline warning, at the point of that child-creation dialog, explaining that saving this child will clear the parent's savings-receiver mark (FR-011, per spec.md Clarifications — the warning is shown on the child-create dialog, not deferred to a later visit to the parent) |
| The user saves that child (confirming the creation) | In the same transaction that already clears the parent's formula (prior feature's documented behavior), the parent's `isSavingsReceiver` is also cleared to `false` |

## Explicitly unchanged contracts

- `ExpenseControlRepository`'s existing method signatures (`watchAll`, `getAll`, `create`, `update`, `delete`, `reorderTopLevel`, `saveFormulas`) are unchanged in shape — only one new method (`applyIncomeAllocation`) is added.
- `ExpenseControlPlanService.buildTree()`/`computeTotals()`/`validateBudget()`/`computeItemBalance()` — unchanged; the new allocation function is additive (a new function or method alongside these, not a modification of any of them).
- `SpendingScreen`'s balance display (`computeItemBalance`) — unchanged; it will simply reflect whatever `applyIncomeAllocation` wrote, the same as it already reflects any other balance change, live via the existing stream.
