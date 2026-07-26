import 'package:drift/drift.dart';

@DataClassName('AllocationEventRow')
@TableIndex(name: 'allocation_events_user_id_idx', columns: {#userId})
class AllocationEvents extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  DateTimeColumn get eventDate => dateTime().withDefault(currentDateAndTime)();
  IntColumn get incomeAmount => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
