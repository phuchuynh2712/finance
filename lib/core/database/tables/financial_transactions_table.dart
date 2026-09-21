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
class FinancialTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get expenseControlItemId => text()();
  TextColumn get direction => textEnum<TransactionDirection>()();
  IntColumn get amount => integer()();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
