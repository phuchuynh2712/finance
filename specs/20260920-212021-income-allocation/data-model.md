# Data Model: Income Entry & Automatic Allocation ("Thu nhập")

## Entity: `ExpenseControlItem` (extended)

Existing entity (`lib/features/expense_control/domain/expense_control_item.dart`), gaining one new field. No new entity is introduced.

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | unchanged |
| `userId` | `String` | unchanged |
| `parentId` | `String?` | unchanged |
| `name` | `String` | unchanged |
| `iconKey` | `String` | unchanged |
| `description` | `String?` | unchanged |
| `sortOrder` | `int` | unchanged — this feature reads it to order allocation, never writes it |
| `allocationMethod` | `ExpenseAllocationMethod?` | unchanged |
| `allocationValue` | `double?` | unchanged — for `percentage`, a 0–100 value (not a 0–1 fraction; matches `ExpenseControlPlanService.computeTotals`'s existing convention, NOT the retired `Envelope.allocationValue`'s fraction convention) |
| `balance` | `int` | unchanged in shape — this feature is the first to ever write a non-zero value to it |
| **`isSavingsReceiver`** | **`bool`** | **NEW.** Defaults to `false`. Meaningful only for a leaf item; MUST be `false` for any item that has children (enforced at the point a first child is added — see State Transitions below). At most one item per user may have this `true` at any time, enforced at the application layer only (research.md Decision 5) — not a database constraint. |

**Validation rules**:
- `isSavingsReceiver` may only be set to `true` via the create/edit dialog when the item being saved is a leaf (has no children at save time) — existing groups never expose the toggle.
- Before persisting `isSavingsReceiver: true`, the save path MUST check the currently-loaded item list for any other item already `true`; if found, reject the save with an inline error (FR-009) and leave both the attempted change and the existing mark's state exactly as they were before the attempt.

**State transitions**:
- `false → true`: user toggles it on in the create/edit dialog and saves, having passed the uniqueness check above.
- `true → false`: user toggles it off and saves (explicit, user-initiated), OR automatically the moment this item gains its first child (i.e., in the same transaction as `ExpenseControlRepositoryImpl.create()`'s existing "adding the first child clears the parent's own formula" step — data-model.md of the prior feature already documents this transaction; this feature adds one more field to the same clear). The automatic case MUST also surface a user-facing warning explaining the mark was removed (FR-011), shown directly on the child-item create dialog the user is actively using at that moment (per spec.md Clarifications) — the presentation layer must check the parent's current `isSavingsReceiver` value before/at the point of creating the child and surface the warning inline on that same dialog, not merely react to the state change after the fact.

## New computation: Income allocation (pure function, not a stored entity)

Lives in `lib/features/expense_control/domain/` (a new file, e.g. `income_allocation_service.dart` or a new method on `ExpenseControlPlanService` — implementation task decides, both are equally valid architecturally since both are pure-Dart domain code operating on `ExpenseControlNode`/`ExpenseControlItem`).

**Input**:
- `List<ExpenseControlNode> tree` — from the existing `ExpenseControlPlanService.buildTree()`, already reflecting persisted state (no `pendingEdits` overlay needed; this screen never stages edits).
- `int totalIncome` — the summed total from every income source line item, already validated `> 0` (FR-004) before this function is ever called.

**Algorithm** (research.md Decisions 1–3, restated precisely for implementation):

1. Flatten `tree` into an ordered list of every leaf (`node.isGroup == false`) in the exact order `buildTree()` already produces: top-level nodes in `sortOrder`, and — for each group encountered — that group's children in their own `sortOrder`, interleaved at the group's position (i.e., the same traversal `SpendingScreen`/Kiểm soát chi tiêu already render — top-level item 1 (if leaf), top-level item 2's children (if item 2 is a group), top-level item 3 (if leaf), etc., never "all top-level leaves then all group children" or any other reordering).
2. `var remaining = totalIncome;`
3. For each leaf in that flattened order, until `remaining == 0`:
   a. Compute `share`:
      - `allocationMethod == fixed` → `share = allocationValue!.round()`
      - `allocationMethod == percentage` → `share = (totalIncome * allocationValue! / 100).round()` — **always against the original `totalIncome` parameter, never against `remaining`** (research.md Decision 1; confirmed by spec.md Acceptance Scenario 4's exact wording).
      - `allocationMethod == null` → cannot occur; every leaf has a non-null formula by construction (a leaf is exactly an item with `allocationMethod != null`, per the existing domain model — groups are the only items with `null` formula, and groups are excluded from this flattened list by step 1).
   b. `final allocated = share <= remaining ? share : remaining;`
   c. Record `allocated` against this leaf's id in the result's delta map (only if `allocated > 0`; a leaf can legitimately receive `0` only if it's reached exactly when `remaining` is already `0`, in which case step 3's loop condition already stopped before reaching it — so every leaf that IS recorded receives `> 0`).
   d. `remaining -= allocated;`
   e. If `allocated < share` (this leaf was under-covered), stop the loop immediately — no further leaf in the list is evaluated at all (research.md Decision 2).
4. After the loop (whether it ran to completion or stopped early at step 3e): if `remaining > 0`, find the leaf (if any, scanning the same flattened list — at most one match by construction, or by research.md Decision 9's tie-break if a sync race has transiently produced more than one) with `isSavingsReceiver == true`. If found, add `remaining` to that leaf's existing entry in the delta map (creating a new entry of exactly `remaining` if that leaf received nothing in step 3), and set `remaining = 0`. If not found, leave `remaining` as-is.
5. Return a result carrying: the per-leaf-id delta map (only entries with `allocated > 0`), and the final `remaining` value (named e.g. `unallocatedAmount` — `0` in the common case, `> 0` only when no savings receiver was marked and a leftover existed).

**Rounding**: every `share` computation rounds to the nearest whole VND via Dart's `num.round()` (round-half-away-from-zero), matching the one existing precedent for this conversion in the codebase (`lib/features/expense_control/presentation/formatting.dart:22`) and the retired `Envelope`-era allocation code's own convention. No fractional VND is ever stored or displayed.

**Multi-receiver tie-break** (research.md Decision 9): if — due to the accepted rare multi-device sync race (spec.md Edge Cases) — more than one leaf transiently has `isSavingsReceiver == true` when step 4 runs, the first such leaf encountered in the same flattened `sortOrder` traversal receives the entire leftover; any other marked leaf(s) are treated as unmarked for this allocation pass. This is a deterministic, no-new-infrastructure tie-break (research.md Decision 9) — it does not attempt to detect, warn about, or resolve the underlying multi-mark state itself (that remains an accepted, out-of-scope gap per research.md Decision 5).

## Contract: `ExpenseControlRepository.applyIncomeAllocation`

New method on the existing interface (`lib/features/expense_control/domain/expense_control_repository.dart`):

```dart
/// Adds each delta to the named item's existing `balance`, atomically, in
/// one transaction with one sync_outbox row per changed item — the
/// data-layer half of an income save (FR-005–FR-014). Deltas MUST already
/// be non-negative (the allocation algorithm never produces a negative
/// delta); this method does not itself validate that. Each increment MUST
/// be applied as a single `balance = balance + delta` SQL statement, never
/// a read-then-write pair, to avoid losing a concurrent write to the same
/// row within the same local transaction window (see Implementation shape
/// below).
Future<void> applyIncomeAllocation(Map<String, int> balanceDeltas);
```

**Implementation shape** (`ExpenseControlRepositoryImpl`, mirroring `saveFormulas`'s existing transaction/outbox-loop pattern):
- One `_db.transaction()` wrapping the entire call.
- For each `(itemId, delta)` in `balanceDeltas`, the balance increment itself MUST be a single atomic SQL statement — `balance = balance + delta` evaluated server-side by SQLite in one statement — NOT a read-then-write pair (`read current balance` → `compute currentBalance + delta` in Dart → `write` it back). A read-then-write pair racing against another concurrent write to the same row inside the same local transaction window would silently lose an increment, which the Constitution's "correctness of money math is non-negotiable" principle does not tolerate. Concretely: `await _db.customStatement('UPDATE expense_control_items SET balance = balance + ?, updated_at = ? WHERE id = ?', [delta, DateTime.now().millisecondsSinceEpoch ~/ 1000, itemId]);` (or Drift's typed equivalent if one exists for an expression-based column update — either is acceptable as long as the increment is one atomic statement, not two round-trips).
- Immediately after that statement (still inside the same transaction, same loop iteration), read the item's row back to get its now-current `balance` (the value the increment just produced), and call `_appendOutbox(itemId, SyncOperation.update, _payloadOf(...))` with a **full-row upsert payload carrying that freshly-read balance** — matching the existing outbox payload shape every other write in this repository already uses (a full-row upsert, not a delta operation the remote side would need new logic to apply). This means the remote side still receives a computed absolute value, not the delta itself — consistent with how sync already works everywhere else in this codebase, and with the already-acknowledged reconciliation gap in plan.md's Complexity Tracking (a concurrent write from another device racing at the Supabase level is a pre-existing, documented class of risk this feature does not newly introduce or need to solve).
- If any statement in the loop throws, the whole transaction rolls back (Drift's `transaction()` semantics already guarantee this — no new error-handling code needed beyond what `saveFormulas` already relies on) — satisfying FR-014's atomicity requirement.

## Drift Schema Change

`lib/core/database/tables/expense_control_items_table.dart`:

```dart
class ExpenseControlItems extends Table {
  // ...existing columns unchanged...
  BoolColumn get isSavingsReceiver =>
      boolean().withDefault(const Constant(false))();
  // ...
}
```

`lib/core/database/app_database.dart`:
- `schemaVersion`: `3` → `4`
- `migration.onUpgrade`: one new `if (from == 3)` branch (matching the existing `if (from == 1)`/`if (from == 2)` single-version-step style) calling `m.addColumn(expenseControlItems, expenseControlItems.isSavingsReceiver)`.
- After this migration step, `build_runner` regenerates `app_database.g.dart` — generated file, not hand-edited.

## Supabase Remote Schema Change

New migration file under `supabase/migrations/` (following the existing naming convention, e.g. `<timestamp>_income_allocation.sql`):

```sql
ALTER TABLE expense_control_items
  ADD COLUMN is_savings_receiver boolean NOT NULL DEFAULT false;
```

No RLS policy statement needed — the new column inherits `expense_control_items`' existing row-level policy automatically (RLS is per-table, per this project's established pattern from the prior feature).

## Out of Scope for This Feature's Data Model

- No new table for income source line items — they are transient UI state only (spec.md Key Entities), never written to Drift or Supabase.
- No allocation-event/history table — this feature performs a direct balance write with no audit trail, per spec.md's explicit Assumption that no such log is introduced.
- No reconciliation view/function — flagged as a known, deferred gap in plan.md's Complexity Tracking, not designed here.
