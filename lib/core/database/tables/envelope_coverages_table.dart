import 'package:drift/drift.dart';

import 'envelopes_table.dart';
import 'expense_entries_table.dart';

@DataClassName('EnvelopeCoverageRow')
@TableIndex(name: 'envelope_coverages_user_id_idx', columns: {#userId})
@TableIndex(
  name: 'envelope_coverages_source_envelope_id_idx',
  columns: {#sourceEnvelopeId},
)
@TableIndex(
  name: 'envelope_coverages_covering_envelope_id_idx',
  columns: {#coveringEnvelopeId},
)
class EnvelopeCoverages extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get expenseEntryId =>
      text().references(ExpenseEntries, #id, onDelete: KeyAction.cascade)();
  @ReferenceName('coveragesAsSource')
  TextColumn get sourceEnvelopeId => text().references(Envelopes, #id)();
  @ReferenceName('coveragesAsCoverer')
  TextColumn get coveringEnvelopeId => text().references(Envelopes, #id)();
  IntColumn get amount => integer()();
  DateTimeColumn get coveredAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
