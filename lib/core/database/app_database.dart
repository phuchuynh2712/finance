import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/allocation_event_lines_table.dart';
import 'tables/allocation_events_table.dart';
import 'tables/envelope_coverages_table.dart';
import 'tables/envelopes_table.dart';
import 'tables/expense_control_items_table.dart';
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
    ExpenseControlItems,
    SyncOutbox,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'finance'));

  /// For tests only — accepts an in-memory or otherwise custom executor
  /// instead of the real on-device file, e.g. `NativeDatabase.memory()`.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from == 1) {
        await m.createTable(expenseControlItems);
        // Expense Control replaces the "Khoản" (Envelope) screen; its data
        // is test-only and explicitly discarded, not migrated (FR-019,
        // research.md §3) — soft-delete every existing envelope row so the
        // renamed "Thu chi"/"Hồ sơ" screens show their empty states.
        await (update(
          envelopes,
        )..where((row) => row.deletedAt.isNull())).write(
          EnvelopesCompanion(deletedAt: Value(DateTime.now())),
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
