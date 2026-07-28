import 'package:drift/drift.dart';

import 'envelopes_table.dart';

enum ExpenseEntryMethod { manual, scanned }

@DataClassName('ExpenseEntryRow')
@TableIndex(name: 'expense_entries_user_id_idx', columns: {#userId})
@TableIndex(name: 'expense_entries_envelope_id_idx', columns: {#envelopeId})
class ExpenseEntries extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get envelopeId => text().references(Envelopes, #id)();
  IntColumn get amount => integer()();
  DateTimeColumn get entryDate => dateTime()();
  TextColumn get note => text().nullable()();
  TextColumn get entryMethod =>
      textEnum<ExpenseEntryMethod>().withDefault(const Constant('manual'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
