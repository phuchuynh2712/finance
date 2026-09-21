import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/expense_control_items_table.dart';
import 'tables/financial_transactions_table.dart';
import '../sync/sync_outbox_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [ExpenseControlItems, FinancialTransactions, SyncOutbox])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'finance'));

  /// For tests only — accepts an in-memory or otherwise custom executor
  /// instead of the real on-device file, e.g. `NativeDatabase.memory()`.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // `onUpgrade` fires ONCE per open with `from` fixed at the database's
      // actual starting version — it does NOT re-invoke per intermediate
      // step. A user jumping straight from v1 to v4 (e.g. after not
      // opening the app for a long time) must still receive every step's
      // changes in one pass, so each block below is cumulative (`<=`), not
      // an exclusive `==` — every block whose version gate the starting
      // version has not yet passed must run, in order.
      if (from <= 1) {
        await m.createTable(expenseControlItems);
      }
      if (from <= 2) {
        // FR-011, FR-020: add the balance column, then retire Envelope and
        // everything built on it in dependency-safe order (data-model.md's
        // Drop order) — the view first, then tables in FK-dependency order,
        // since `PRAGMA foreign_keys = ON` (below) enforces it.
        await m.addColumn(expenseControlItems, expenseControlItems.balance);
        await customStatement('DROP TABLE IF EXISTS envelope_coverages');
        await customStatement('DROP TABLE IF EXISTS allocation_event_lines');
        await customStatement('DROP TABLE IF EXISTS allocation_events');
        await customStatement('DROP TABLE IF EXISTS expense_entries');
        await customStatement('DROP TABLE IF EXISTS envelopes');
      }
      if (from <= 3) {
        await m.addColumn(
          expenseControlItems,
          expenseControlItems.isSavingsReceiver,
        );
      }
      if (from <= 4) {
        await m.createTable(financialTransactions);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
