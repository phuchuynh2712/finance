# Data Model: Budget Envelopes

All 5 tables below exist identically in Drift (local, source of truth for reads/writes) and Supabase Postgres (sync target). Every table carries `id` (UUID), `user_id` (UUID, FK to `auth.users`), `created_at`, `updated_at`, and `deleted_at` (nullable — soft-delete/tombstone per constitution's Offline-First sync pattern). These four columns are omitted from the per-table field lists below for brevity except where a table needs a note about them.

## Envelope

A user-defined budget category (spec Key Entities).

| Field | Type | Notes |
|---|---|---|
| `name` | text | Not empty |
| `allocation_method` | enum(`percentage`, `fixed`) | |
| `allocation_value` | integer (VND) or decimal(5,4) | Fixed envelopes: whole VND amount. Percentage envelopes: stored as a fraction (e.g. `0.3000` for 30%), not a display string |
| `balance` | integer (VND) | Materialized running balance (research.md §2); never negative-clamped — can go negative per FR-011/FR-016/edge cases |
| `is_rounding_receiver` | boolean, default `false` | At most one `true` per `user_id` — enforced by a partial unique index in Postgres and a repository-level check in the Drift write path (research.md §3) |

**Validation rules**:
- `allocation_value > 0` for both methods (a zero/negative allocation is not meaningful; enforced at create/edit time, not retroactively on existing rows).
- Deleting an envelope with `balance != 0` requires the caller to have shown the FR-027 warning first (enforced in the domain use case, not the DB layer).
- Deleting the envelope where `is_rounding_receiver = true` requires either designating a new receiver first or being the user's last envelope (FR-028) — enforced in the domain use case.

## Allocation Event

A single confirmed "Plan" action (spec Key Entities). Immutable once created (per spec) — no update path exists in the repository interface, only insert.

| Field | Type | Notes |
|---|---|---|
| `event_date` | timestamp | When the plan was confirmed |
| `income_amount` | integer (VND) | The total income entered for this event |

**Relationships**: has many `AllocationEventLine` (one per envelope that received an allocation in this event, including the rounding-receiver's leftover line).

## Allocation Event Line

The per-envelope breakdown of one Allocation Event (research.md §4) — persisted per FR-010 even though no history UI exists yet.

| Field | Type | Notes |
|---|---|---|
| `allocation_event_id` | UUID, FK → Allocation Event | |
| `envelope_id` | UUID, FK → Envelope | |
| `amount` | integer (VND) | This envelope's allocation from this event, including any rounding-leftover amount folded in if this line's envelope is the receiver |
| `is_rounding_remainder_line` | boolean | `true` only for the receiver envelope's line, and only when the leftover portion is non-zero — lets future reporting distinguish "this envelope's normal share" from "plus leftover" without re-deriving it |

## Expense Entry

A single spending transaction (spec Key Entities). Mutable — may be edited or deleted (FR-018a), unlike Allocation Event.

| Field | Type | Notes |
|---|---|---|
| `envelope_id` | UUID, FK → Envelope | The target envelope debited |
| `amount` | integer (VND) | Must be `> 0` |
| `entry_date` | date | |
| `note` | text, nullable | Optional note/merchant |
| `entry_method` | enum(`manual`) | Single value today; the enum itself (rather than an assumed-manual boolean) is the FR-019 extension point for a future `scanned` value with no migration needed to add it |

**State transitions**: create → (optionally) edit → (optionally) delete. Each edit/delete first reverses the prior effects (restores `envelope.balance`, reverses any linked `EnvelopeCoverage`) before applying the new state, per FR-018a.

## Envelope Coverage

Records an overspend resolution — a cross-envelope transfer (spec Key Entities).

| Field | Type | Notes |
|---|---|---|
| `expense_entry_id` | UUID, FK → Expense Entry, `ON DELETE CASCADE` | The triggering expense; cascading delete matches FR-018a's reversal semantics — deleting the expense removes its coverage record as part of the same reversal |
| `source_envelope_id` | UUID, FK → Envelope | The envelope that would have gone negative |
| `covering_envelope_id` | UUID, FK → Envelope | The envelope the user chose to cover the shortfall |
| `amount` | integer (VND) | The shortfall amount transferred |
| `covered_at` | timestamp | |

## Sync Outbox (`core/sync`, not feature-specific)

Not part of this feature's domain model, but every write path above appends a row here in the same local transaction (constitution Offline-First requirement).

| Field | Type | Notes |
|---|---|---|
| `table_name` | text | Which of the 5 tables above changed |
| `row_id` | UUID | The changed row's `id` |
| `operation` | enum(`insert`, `update`, `delete`) | |
| `payload` | JSON | The row's data at write time |
| `synced_at` | timestamp, nullable | `null` until the background worker successfully pushes it |
| `retry_count` | integer, default `0` | For exponential backoff |

## Entity relationship summary

```text
User (Supabase Auth) 1──* Envelope
Envelope 1──* AllocationEventLine
AllocationEvent 1──* AllocationEventLine
Envelope 1──* ExpenseEntry (as target)
ExpenseEntry 0..1──1 EnvelopeCoverage
Envelope 1──* EnvelopeCoverage (as source, via EnvelopeCoverage.source_envelope_id)
Envelope 1──* EnvelopeCoverage (as coverer, via EnvelopeCoverage.covering_envelope_id)
```
