# Research: Transaction History

## Decision 1: Persist immutable transaction display snapshots

**Decision**: Add nullable `display_name`, `display_group_name`, and
`display_icon_key` fields to financial transactions. New income and expense
rows populate them from the receiving/charged expense-control item in the
same database transaction. Income rows use the recipient item name and the
localized Income classification; expense rows use the item name and its group
context. Existing rows are backfilled once.

**Rationale**: History must remain auditable after source items are renamed or
soft-deleted. Rejoining current item labels makes old activity appear to have
changed, which contradicts the approved clarification.

**Alternatives considered**:
- Resolve labels from current items at read time: rejected because renames and
  deletions rewrite history.
- Store no labels and show IDs/generic labels: rejected because the primary
  history task becomes hard to review.

## Decision 2: Use a cumulative Drift schema migration and a matching remote migration

**Decision**: Increment the local database schema version once. In the
cumulative upgrade block, add snapshot fields and `updated_at`/`deleted_at`,
then backfill labels from the linked expense-control item, assigning the
Archived Item fallback when no usable source exists. Add the same columns
through a timestamped Supabase migration; retain its existing ownership RLS
policy and month index.

**Rationale**: Drift upgrades may skip intermediate schema versions, so the
new migration must work from all supported older versions. Local and remote
rows must share a payload shape for eventual synchronization.

**Alternatives considered**:
- Backfill on every history read: rejected because it is mutable, repeated,
  and cannot sync an immutable result.
- Drop/recreate local history: rejected because it loses financial records.

## Decision 3: Preserve local transaction and outbox atomicity

**Decision**: Snapshot capture, financial transaction insertion, its sync
timestamps, and its outbox row remain inside each existing local database
transaction. The outbox serializer includes all snapshot and sync metadata.
Migration backfill is a local schema upgrade and does not invent user edits;
normal sync handling sends new writes using the expanded payload.

**Rationale**: A financial balance update and its history row must never
diverge. The repository already enforces this invariant for both income and
expense paths.

**Alternatives considered**:
- A separate asynchronous snapshot update: rejected because it permits
  incomplete history and outbox payloads.

## Decision 4: Expose history through the existing application facade

**Decision**: Define a pure `TransactionHistoryRecord` in
`expense_control/domain` and return it from that feature's repository contract.
`ExpenseControlGateway` maps the owner-domain records into Spending view state,
where selected-month, filter, grouping, and total state are derived. The history
screen does not query Drift or import another feature's data implementation.

**Rationale**: The screen is reached from Spending, while transaction writes
remain owned by expense control. The facade avoids a direct cross-feature
presentation/data dependency and is easy to fake in tests.

**Alternatives considered**:
- Query AppDatabase in the history widget: rejected by Clean Architecture and
  makes widget tests persistence-coupled.
- Return `expenses/application` types from the owner repository: rejected
  because it reverses the domain dependency direction.
- Create a new repository/package: rejected as unnecessary abstraction for one
  existing transaction source.

## Decision 5: Query a bounded month and render lazily

**Decision**: Use an inclusive start and exclusive end timestamp for the
selected local calendar month, scoped by user and ordered newest first. Apply
the active filter before date grouping, then render date sections lazily.

**Rationale**: The existing `(user_id, occurred_at)` index fits the access
pattern. An exclusive month end avoids time-of-day boundary errors and remains
correct for transactions at the final millisecond of a month.

**Alternatives considered**:
- Load all user history then filter in the widget: rejected for unnecessary
  I/O, memory, and rebuild cost.

## Decision 6: Reuse localization, semantic colors, and formatters

**Decision**: Externalize every new label in Vietnamese and English ARB files;
format dates/months and VND amounts with `intl` and `CurrencyFormatter`; use
the existing semantic theme extension for signed amount colors and surfaces.

**Rationale**: This meets localization, consistency, and accessibility rules
without introducing alternate formatting or design-token systems.

**Alternatives considered**:
- Embed mockup labels/colors in widgets: rejected by the constitution and
  because language/theme changes would diverge.