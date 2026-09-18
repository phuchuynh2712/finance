# Data Model: Expense Control

## Entity: ExpenseControlItem

Backed by a single new Drift table, `ExpenseControlItems` (`lib/core/database/tables/expense_control_items_table.dart`), following the existing `envelopes_table.dart` conventions (soft-delete tombstone, `userId` scoping, `createdAt`/`updatedAt`).

| Field | Type | Nullable | Notes |
|---|---|---|---|
| `id` | text (uuid) | no | Primary key. |
| `userId` | text | no | Scopes rows to the signed-in user; indexed (`expense_control_items_user_id_idx`), mirrors `envelopes_user_id_idx`. |
| `parentId` | text | **yes** | Self-reference to another row's `id`. `null` = top-level. A row that itself has children MUST NOT have a non-null `parentId` (1-level nesting cap, FR-002) — enforced in the domain layer, not the DB. |
| `name` | text | no | FR-017: required, non-blank. |
| `iconKey` | text | no | Key into the app's fixed icon map (research.md §2), e.g. `"home"`. FR-001. |
| `description` | text | yes | FR-022: optional free-text; stored but not rendered on this screen. |
| `sortOrder` | integer | no | Display order among siblings (top-level order is user-reorderable, FR-014; child order is append-only, research.md §4). |
| `allocationMethod` | text enum (`percentage` \| `fixed`), feature-local `ExpenseAllocationMethod` (research.md §5b, not `envelopes_table.dart`'s `AllocationMethod`) | **yes** | `null` when the row has ≥1 child (it's a group, FR-003). Non-null for every leaf. |
| `allocationValue` | real | **yes** | Paired with `allocationMethod`; `null` under the same condition. Percentage stored as `0 < value ≤ 100`; fixed stored as `value > 0` (FR-017: zero/blank rejected pre-save). |
| `createdAt` | datetime | no | Default now. |
| `updatedAt` | datetime | no | Default now, bumped on every write. |
| `deletedAt` | datetime | yes | Soft-delete tombstone (offline-first pattern). Deleting a group cascades: the group row and all direct children get `deletedAt` set in the same transaction (FR-016). |

**Primary key**: `id`. **Index**: `(userId)`, mirroring `envelopes_user_id_idx` (query pattern is always "all of this user's items").

### Invariants (enforced in the domain layer — see `research.md` §5)

1. **Leaf ⇄ group**: `parentId == null && childCount == 0` → leaf, carries a formula. `parentId == null && childCount > 0` → group, `allocationMethod`/`allocationValue` MUST be `null`. A child row (`parentId != null`) is always a leaf and always carries a formula.
2. **Percentage budget**: `sum(allocationValue where allocationMethod == percentage across all non-deleted leaves for this user) ≤ 100`, and strictly `< 100` if `count(allocationMethod == fixed) > 0` anywhere in the same user's plan (FR-007/FR-008).
3. **One-level nesting**: a row with a non-null `parentId` MUST NOT be referenced as another row's `parentId` (no grandchildren, FR-002).

## Derived / in-memory types (domain layer, not persisted)

- **`ExpenseControlNode`**: presentation-facing tree shape — `{ item: ExpenseControlItem, children: List<ExpenseControlItem> }` — built by flattening the repository's `watchAll()` stream into top-level items paired with their direct children (grouped by `parentId`, ordered by `sortOrder`).
- **`ExpenseControlTotals`**: `{ percentAllocated: double, fixedItemCount: int, percentFree: double }` — computed by the same domain service from the full flat list (FR-011), independent of tree shape. Both the tree-builder and the totals/validation functions accept an optional overlay `Map<String, ExpenseFormulaEdit>` (see contracts/expense_control_repository.md) so US3's inline formula editing can compute live totals and FR-012 validation against a *pending* (not-yet-persisted) state without writing to the DB on every keystroke.
- **`ExpenseFormulaEdit`** (presentation-only, never persisted as its own row): `{ method: ExpenseAllocationMethod, value: double }` — one item's staged formula change, held in a screen-scoped provider until the user taps "Lưu công thức" (research.md §9) or discarded if they navigate away first (spec.md Edge Cases).
- **Group subtotal** (FR-024, presentation-only, no dedicated type — it's just `ExpenseControlTotals` computed with a scoped input): a group's sub-label is `computeTotals(node.children, pendingEdits: ...)` — the *same* function and shape as the plan-wide summary (FR-011), just given only that one group's direct children instead of the whole flat list. Never stored; recomputed on every rebuild so it can never drift from its children.

## State transitions

| Event | Effect |
|---|---|
| First child added to a top-level leaf | Parent's `allocationMethod`/`allocationValue` → `null` in the same transaction as the child insert (FR-004). |
| Last remaining child of a group deleted | Group row's `allocationMethod`/`allocationValue` remain `null` (not auto-restored); it becomes eligible for the user to set a new formula via edit (FR-005). |
| Group deleted (has children) | Group row and every direct child row soft-deleted in one transaction, after user confirmation (FR-016). |
| Leaf item deleted | Row soft-deleted; if it was the last child, see row above. |
| Formula mode switched (percentage ⇄ fixed) on an existing leaf | `allocationValue` is replaced (not preserved/converted) — FR-006. |
