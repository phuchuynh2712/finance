# Data Model: Spending Balance Hub & Envelope Retirement ("Thu chi")

## Entity: `ExpenseControlItem` (extended)

Existing entity (`lib/features/expense_control/domain/expense_control_item.dart`), gaining one new field. No new entity is introduced — see research.md Decision 1.

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | unchanged |
| `userId` | `String` | unchanged |
| `parentId` | `String?` | unchanged — `null` means top-level (group or standalone leaf) |
| `name` | `String` | unchanged |
| `iconKey` | `String` | unchanged |
| `description` | `String?` | unchanged |
| `sortOrder` | `int` | unchanged |
| `allocationMethod` | `ExpenseAllocationMethod?` | unchanged — `null` for a group |
| `allocationValue` | `double?` | unchanged — `null` for a group |
| **`balance`** | **`int`** | **NEW.** VND amount (whole units — no minor-unit/cents concept in this app). Meaningful only for a *leaf* item (has its own `allocationMethod`); a group's own `balance` column value MUST be ignored by all reads (always 0 and never written to, since `_toDomain`/`copyWith` still populate it symmetrically, but no UI ever displays a group's *own* stored balance — see `ExpenseControlNode` below). Defaults to `0`. Only ever written by a future income/expense-recording feature (out of scope here) — this feature's own code never writes a non-zero value to it. No borrowing/covering mechanism exists (research.md Decision 8) — a negative value is a valid, permanent state, not a transient one awaiting reconciliation. |

**Validation rules**: None beyond the existing ones (`allocationValue` must still be `null` for a group). `balance` has no range constraint at this layer — a negative value is a valid, meaningful state (overspending), per spec.md FR-004.

**State transitions**: None owned by this feature. `balance` starts at `0` on row creation (via the DB column default, not application code) and is otherwise immutable from this feature's perspective — no code path in this feature writes to it after creation.

## Presentation-facing shape: `ExpenseControlNode` (extended usage, no field changes)

`ExpenseControlNode` (`lib/features/expense_control/domain/expense_control_plan_service.dart:5-12`) already pairs an `item` with its `children` — unchanged in shape. What's new is a derived value computed *from* it, not stored on it:

- **Group displayed balance** = `node.children.map((c) => c.balance).sum` — computed by a new pure function (e.g. `ExpenseControlPlanService.computeItemBalance(ExpenseControlNode node)`), not a field. For a leaf node (`children` empty), the displayed balance is simply `node.item.balance`.

This mirrors `ExpenseControlTotals`'s existing pattern of being a computed, not stored, aggregate (plan_service.dart:114-136).

## Deleted Entities (User Story 5 — retiring Envelope)

The following entities and their backing Drift tables are deleted entirely. They are documented here only to make the removal's scope and dependency order explicit — none of them are part of the app's data model after this feature ships.

| Entity/Table | Why it's deleted | Depends on / referenced by |
|---|---|---|
| `Envelope` / `Envelopes` | The retired predecessor to `ExpenseControlItem`; superseded, no longer read by any screen after `OverviewScreen`'s content is replaced | Referenced by `ExpenseEntries.envelopeId`, `EnvelopeCoverages.sourceEnvelopeId`/`.coveringEnvelopeId`, `AllocationEventLines.envelopeId` |
| `ExpenseEntry` / `ExpenseEntries` | The old expense-recording model, FK'd to `Envelope`; deleted along with `ExpenseFormScreen`/`ExpenseFormController` rather than re-pointed at `ExpenseControlItem` (research.md Decision 7) | References `Envelopes`; referenced by `EnvelopeCoverages.expenseEntryId` |
| `EnvelopeCoverage` / `EnvelopeCoverages` | The "borrowing between envelopes" mechanic; dropped without replacement (research.md Decision 8) | References `Envelopes` (×2) and `ExpenseEntries` |
| `AllocationEvent` / `AllocationEvents` | An immutable record of one income-allocation confirmation via the old `PlanScreen`; deleted since `PlanScreen`/`PlanController` are deleted (no remaining writer) | Parent of `AllocationEventLines` |
| `AllocationEventLine` / `AllocationEventLines` | Per-envelope breakdown of one `AllocationEvent`, including the "rounding receiver" flag; dropped without replacement (research.md Decision 8) | References `AllocationEvents` and `Envelopes` |
| Supabase view `envelope_balances` | Reads from all four tables above plus `expense_entries`; must be dropped before any of them | References all tables above |

**Drop order** (both locally via Drift and remotely via Supabase — FK/view dependencies must be removed before what they depend on):

1. `envelope_balances` (view)
2. `EnvelopeCoverages` / `envelope_coverages`
3. `AllocationEventLines` / `allocation_event_lines`
4. `AllocationEvents` / `allocation_events`
5. `ExpenseEntries` / `expense_entries`
6. `Envelopes` / `envelopes`

## Drift Schema Change

`lib/core/database/tables/expense_control_items_table.dart`:

```dart
class ExpenseControlItems extends Table {
  // ...existing columns unchanged...
  IntColumn get balance => integer().withDefault(const Constant(0))();
  // ...
}
```

The five table files backing the deleted entities above (`envelopes_table.dart`, `expense_entries_table.dart`, `envelope_coverages_table.dart`, `allocation_events_table.dart`, `allocation_event_lines_table.dart`) are deleted, and their table classes are removed from `AppDatabase`'s `@DriftDatabase(tables: [...])` list in `app_database.dart`.

`lib/core/database/app_database.dart`:

- `schemaVersion`: `2` → `3`
- `migration.onUpgrade`: ONE `if (from == 2)` branch (matching the existing `if (from == 1)` single-version-step style) that, in order: (a) calls `m.addColumn(expenseControlItems, expenseControlItems.balance)`; (b) issues raw `DROP TABLE` statements (via `m.database.customStatement(...)`, since Drift's generated schema no longer has table objects for deleted tables once they're removed from the `@DriftDatabase` annotation and code is regenerated) in the drop order above, skipping the `envelope_balances` view step (that's a Supabase-only concept, not a local SQLite view).
- After this migration step runs, `build_runner` regenerates `app_database.g.dart` to reflect the five removed tables and the one new column — this is a generated file and MUST NOT be hand-edited.

## Supabase Remote Schema Change

A new migration file under `supabase/migrations/` (following the naming convention of the existing `20260904150000_expense_control_items.sql`, e.g. `<timestamp>_retire_envelope.sql`):

```sql
ALTER TABLE expense_control_items
  ADD COLUMN balance integer NOT NULL DEFAULT 0;

DROP VIEW IF EXISTS envelope_balances;
DROP TABLE IF EXISTS envelope_coverages;
DROP TABLE IF EXISTS allocation_event_lines;
DROP TABLE IF EXISTS allocation_events;
DROP TABLE IF EXISTS expense_entries;
DROP TABLE IF EXISTS envelopes;
```

No RLS policy statement is needed for the drops — Postgres removes a table's RLS policies automatically when the table itself is dropped. The additive `balance` column inherits `expense_control_items`' existing row-level policy automatically (Constitution Security section — RLS is per-table, not per-column).

## Relationships

Unchanged from Kiểm soát chi tiêu: `ExpenseControlItem.parentId` self-references `ExpenseControlItem.id`, one level of nesting only (enforced by the existing `isNestingAllowed`, plan_service.dart:163-171). This feature adds no new relationships to `ExpenseControlItem` — the only relationship changes in this feature are the deletions above.

## Out of Scope for This Feature's Data Model

- A future income/expense-recording feature designs how a new expense-recording entity (whatever replaces `ExpenseEntry`) references `ExpenseControlItem` — this feature deletes the old entity outright rather than pre-designing its replacement's shape (research.md Decision 7).
- Any equivalent to "covering"/"rounding receiver" mechanics is explicitly not designed here — dropped, not deferred-with-a-plan (research.md Decision 8). A future feature starts from a blank slate on this if it turns out to be needed.
