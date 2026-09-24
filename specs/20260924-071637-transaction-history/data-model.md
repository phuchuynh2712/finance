# Data Model: Transaction History

## Financial Transaction (persisted)

Existing required fields remain: `id`, `userId`, `expenseControlItemId`,
`direction`, positive `amount`, `occurredAt`, and `createdAt`.

| Field | Type | Rules |
|---|---|---|
| `displayName` | text | Immutable label captured for new rows; backfilled for existing rows; `Archived Item` when source data is unavailable. |
| `displayGroupName` | nullable text | Immutable expense group context. Income is represented by direction and the localized Income classification, not a mutable group. |
| `displayIconKey` | nullable text | Icon key captured from the associated item; fallback icon is used if absent. |
| `updatedAt` | timestamp | Set for inserts and preserved for synchronization/conflict metadata. |
| `deletedAt` | nullable timestamp | Tombstone field required for syncable rows; null for active history records. |
| `direction` | income / expense | Defines sign, semantic amount color, Income classification, and expense-total inclusion. |

### Invariants

- `amount` is always positive; only `direction` determines whether the visible
  amount is income or expense.
- Snapshot fields are written with a new transaction and never overwritten by
  source item edits or deletes.
- Every financial-transaction insert and its outbox row happen atomically with
  the corresponding balance mutation.
- Every syncable transaction carries `updatedAt` and `deletedAt`; history reads
  exclude tombstoned rows.
- Backfill copies current associated data once. Rows with unavailable source
  data retain `Archived Item` and an applicable classification.

## Monthly History View (read model)

| Field | Meaning |
|---|---|
| `month` | Selected local calendar month, never after the current month. |
| `filter` | All, a snapshot group identifier/name, or Income. |
| `expenseTotal` | Sum of matching selected-month rows whose direction is expense; never includes income. |
| `groups` | Transaction rows grouped by local occurrence date, newest date first. |
| `status` | Loading, ready, empty, or retryable error while retaining month/filter. |

### Filter rules

- All returns both directions.
- Income returns only `income` rows.
- A group returns only matching `expense` rows.
- Available group filters derive from snapshot group values represented in the
  selected month, including values whose source group was deleted.

## Relationships

```text
ExpenseControlItem (current mutable configuration)
  └── FinancialTransaction (immutable event; references source ID and copies display snapshot)
        └── MonthlyHistoryView (selected-month, user-scoped projection)
```

## State Transitions

```text
selected month/filter change
  -> loading current bounded query
  -> ready(date groups) | empty | retryable error

new expense/income write
  -> atomic balance mutation + immutable transaction snapshot + outbox row
  -> reactive query emits updated monthly history when in selected month
```