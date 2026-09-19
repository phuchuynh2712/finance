# UI Contract: Expense Control Screen State

This feature has no network/API contract to document — no Supabase schema change, no new endpoint. What changes is the **contract between UI layer and the existing `ExpenseControlRepository`/provider layer**: which calls fire when, for which dialog invocation. This file documents that contract so widget/controller implementation matches research.md's routing decision exactly.

See also: `specs/20260904-144604-expense-control/contracts/expense_control_repository.md` (the repository interface's own original contract — unchanged in shape by this feature; only *call-site timing* changes, per research.md Decision 3).

## Dialog save() → repository call matrix

| Dialog invocation | `existingItem` | `isFormulaEditable` | On "Lưu" tap | Which repository method fires, and when |
|---|---|---|---|---|
| Create new item | `null` | `true` | Validate → close | `repository.create(item)` — immediately, same as today |
| Edit existing **group** | non-null | `false` | Validate → close | `repository.update(item)` — immediately, same as today (FR-003) |
| Edit existing **leaf** | non-null | `true` | FR-006 validate → close | **No repository call.** Writes `pendingItemEditsProvider[item.id] = PendingItemEdit(...)` only. |

## Pending-edit flush → repository call matrix

| Trigger | Precondition | On success | On over-budget failure |
|---|---|---|---|
| "Lưu công thức" button pressed | `pendingItemEditsProvider` non-empty (FR-007) | For each pending entry: commit its staged fields (name/icon/description via `repository.update()`; formula via the existing `saveFormulas()` batch call) → clear the map to `{}` | Error surfaced inline (FR-006/FR-007 style), map untouched, no repository call |
| Tab-switch confirmation, "Lưu" chosen (FR-010) | User attempted to leave the Expense Control tab while the map is non-empty | Identical to the "Lưu công thức" success path above, then navigation proceeds | Identical to the "Lưu công thức" failure path above, prompt stays open, navigation does NOT proceed |
| Tab-switch confirmation, "Không lưu" chosen (FR-011) | Same precondition | Map cleared to `{}` without any repository call, then navigation proceeds | N/A — no validation is run on discard |
| Tab-switch confirmation, "Hủy" chosen | Same precondition | No repository call, map untouched, no navigation | N/A |

## Read-side contract: tree assembly

The provider that turns `repository.watchAll()`'s flat stream into the `ExpenseControlNode` tree the screen renders MUST overlay `pendingItemEditsProvider`'s entries onto their matching items for **every** field the new `PendingItemEdit` can carry (name, iconKey, description, method, value) — not formula fields only, per research.md Decision 2. This is what makes FR-005's "immediately update... the inline static value label" and the equivalent (implied) immediate reflection of a staged rename both true from the same overlay mechanism.

## Explicitly unchanged contracts

- `ExpenseControlRepository`'s method signatures (`create`, `update`, `delete`, `reorderTopLevel`, `saveFormulas`) — no shape change, per research.md Decision 1's rationale (a second parallel map/write-path was rejected).
- `ExpenseControlPlanService`'s validation contract (`validateBudget`, `computeTotals`) — this feature calls it at a new point (dialog "Lưu" for a leaf, FR-006) but does not change its signature or semantics.
