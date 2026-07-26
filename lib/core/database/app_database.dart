import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/allocation_event_lines_table.dart';
import 'tables/allocation_events_table.dart';
import 'tables/envelope_coverages_table.dart';
import 'tables/envelopes_table.dart';
import 'tables/expense_entries_table.dart';
import '../sync/sync_outbox_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Envelopes,
    AllocationEvents,
    AllocationEventLines,
    ExpenseEntries,
    EnvelopeCoverages,
    SyncOutbox,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'finance'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
