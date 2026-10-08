import 'package:drift/drift.dart';

/// Feature-local, mirroring `expense_control_items_table.dart`'s own
/// enum-locality rationale — not shared across other table files.
enum TransactionDirection { income, expense }

/// Shared history for both income allocations and expense recordings
/// (research.md Decision 1) — the single source a future Report feature
/// reads from. `amount` is always positive; `direction` alone carries the
/// sign meaning (research.md Decision 3).
@DataClassName('FinancialTransactionRow')
@TableIndex(
  name: 'financial_transactions_user_id_occurred_at_idx',
  columns: {#userId, #occurredAt},
)
// The recompute of an item's balance sums its live transactions: indexed by
// item so it stays one indexed read however long the history is.
@TableIndex(
  name: 'financial_transactions_item_idx',
  columns: {#expenseControlItemId},
)
// A transaction can be reversed at most once, on any device (FR-007, FR-014).
@TableIndex.sql(
  'CREATE UNIQUE INDEX financial_transactions_reverses_id_uidx '
  'ON financial_transactions (reverses_id) WHERE reverses_id IS NOT NULL',
)
class FinancialTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get expenseControlItemId => text()();
  TextColumn get direction => textEnum<TransactionDirection>()();
  IntColumn get amount => integer()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get displayName => text().nullable()();
  TextColumn get displayGroupName => text().nullable()();
  TextColumn get displayIconKey => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Set only on a reversing entry: the id of the transaction it cancels
  /// (research.md Decision 2). A reversal has the same direction, amount and
  /// item as the original, and its effect on the balance is the opposite.
  TextColumn get reversesId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
