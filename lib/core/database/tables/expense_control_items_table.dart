import 'package:drift/drift.dart';

/// Feature-local — deliberately not shared with `envelopes_table.dart`'s
/// `AllocationMethod` (research.md §5b): importing across feature table
/// files would couple two features' schemas that must be free to diverge.
enum ExpenseAllocationMethod { percentage, fixed }

@DataClassName('ExpenseControlItemRow')
@TableIndex(name: 'expense_control_items_user_id_idx', columns: {#userId})
class ExpenseControlItems extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get iconKey => text()();
  TextColumn get description => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get allocationMethod =>
      textEnum<ExpenseAllocationMethod>().nullable()();
  RealColumn get allocationValue => real().nullable()();

  /// Derived: [balanceBase] plus the effect of the item's live transactions
  /// (`BalanceLedger.recomputeBalances`). Never written by hand, never
  /// pushed: every device and the server derive it from the same rows.
  IntColumn get balance => integer().withDefault(const Constant(0))();

  /// The part of the balance that no transaction explains: what the item had
  /// before transactions were the source of the balance. Synced, but changed
  /// by nobody on a device.
  IntColumn get balanceBase => integer().withDefault(const Constant(0))();

  /// The balance the server last reported for this item (a pulled, live or
  /// push-returned row). **Local only**: never pushed and never displayed; it
  /// exists so the device can reconcile its derived [balance] against the
  /// server's (research.md Decision 10).
  IntColumn get serverBalance => integer().nullable()();
  BoolColumn get isSavingsReceiver =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
