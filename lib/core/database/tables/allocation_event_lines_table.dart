import 'package:drift/drift.dart';

import 'allocation_events_table.dart';
import 'envelopes_table.dart';

@DataClassName('AllocationEventLineRow')
@TableIndex(name: 'allocation_event_lines_user_id_idx', columns: {#userId})
@TableIndex(
  name: 'allocation_event_lines_envelope_id_idx',
  columns: {#envelopeId},
)
class AllocationEventLines extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get allocationEventId =>
      text().references(AllocationEvents, #id)();
  TextColumn get envelopeId => text().references(Envelopes, #id)();
  IntColumn get amount => integer()();
  BoolColumn get isRoundingRemainderLine =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
