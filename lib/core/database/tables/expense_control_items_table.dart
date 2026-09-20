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
  IntColumn get balance => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
