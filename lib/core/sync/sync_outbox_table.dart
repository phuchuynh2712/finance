import 'package:drift/drift.dart';

enum SyncOperation { insert, update, delete }

@DataClassName('SyncOutboxRow')
@TableIndex.sql(
  'CREATE INDEX sync_outbox_unsynced_idx ON sync_outbox (synced_at) '
  'WHERE synced_at IS NULL',
)
class SyncOutbox extends Table {
  TextColumn get id => text()();
  TextColumn get entityTable => text()();
  TextColumn get rowId => text()();
  TextColumn get operation => textEnum<SyncOperation>()();
  TextColumn get payload => text()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  /// Set when the server refused this change for good (a guard of the
  /// transaction ledger): the entry is never retried, and its notice stays
  /// here, surviving a restart, until the person has been shown it.
  DateTimeColumn get rejectedAt => dateTime().nullable()();

  /// Why it was refused: `invalid_reversal`, `reversal_immutable`,
  /// `transaction_reversed`, `already_reversed` or `check_violation`.
  TextColumn get rejectReason => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
