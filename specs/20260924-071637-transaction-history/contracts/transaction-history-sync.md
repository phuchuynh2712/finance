# Data and Sync Contract: Transaction Snapshot

## Local and Remote Fields

The local Drift table, the Supabase `financial_transactions` table, and each
financial-transaction outbox payload share these snapshot field names:

| Payload name | Meaning |
|---|---|
| `display_name` | Immutable transaction display label. |
| `display_group_name` | Immutable expense group context, nullable for income. |
| `display_icon_key` | Immutable item icon key, nullable when no source snapshot exists. |
| `updated_at` | Synchronization timestamp set for inserts and later row changes. |
| `deleted_at` | Nullable synchronization tombstone; null for active records. |

Existing payload fields (`id`, `user_id`, `expense_control_item_id`,
`direction`, `amount`, `occurred_at`, `created_at`) remain unchanged.

## Write Contract

1. Resolve the associated expense-control item before creating a transaction.
2. Copy its display fields and set `updated_at`/`deleted_at` metadata on the
   financial transaction.
3. Insert the transaction and an insert outbox payload within the same local
   database transaction as the balance mutation.
4. Sync uses the existing authenticated owner-only remote table and RLS policy.

## Migration Contract

1. Add nullable snapshot columns and `updated_at`/`deleted_at` locally and
   remotely so deployments do not reject existing records.
2. During local upgrade, copy labels from the still-present associated source.
3. If source data cannot be resolved, use `Archived Item`, a direction-derived
   classification, and a fallback icon at render time.
4. Backfill `updated_at` from the creation timestamp and retain a null
   `deleted_at` for active legacy rows.
5. Do not delete or recompute financial transaction amounts during migration.

## Compatibility

Older remote records may have null snapshots during rollout. The read mapper
must supply the Archived Item fallback until the local migration/backfill has
completed. New rows always include snapshot values.