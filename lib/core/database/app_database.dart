import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/expense_control_items_table.dart';
import 'tables/financial_transactions_table.dart';
import 'package:finance/core/sync/sync_outbox_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [ExpenseControlItems, FinancialTransactions, SyncOutbox])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'finance'));

  /// For tests only — accepts an in-memory or otherwise custom executor
  /// instead of the real on-device file, e.g. `NativeDatabase.memory()`.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

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
      // Versions up to v4 create financialTransactions above using the current
      // table definition, which already includes these fields. Only a real v5
      // database needs ALTER TABLE and legacy backfill.
      if (from == 5) {
        await m.addColumn(
          financialTransactions,
          financialTransactions.displayName,
        );
        await m.addColumn(
          financialTransactions,
          financialTransactions.displayGroupName,
        );
        await m.addColumn(
          financialTransactions,
          financialTransactions.displayIconKey,
        );
        // SQLite cannot add a column with Drift's non-constant
        // currentDateAndTime default. Add the legacy column without a default,
        // then populate it from created_at below; new databases retain the
        // non-null schema declaration from FinancialTransactions.
        await customStatement(
          'ALTER TABLE financial_transactions ADD COLUMN updated_at INTEGER',
        );
        await m.addColumn(
          financialTransactions,
          financialTransactions.deletedAt,
        );
        await customStatement('''
          UPDATE financial_transactions
          SET
            display_name = COALESCE(
              (SELECT name FROM expense_control_items
                WHERE expense_control_items.id = financial_transactions.expense_control_item_id),
              'Archived Item'
            ),
            display_group_name = CASE
              WHEN direction = 'income' THEN NULL
              ELSE COALESCE(
                (SELECT parent.name
                  FROM expense_control_items AS item
                  LEFT JOIN expense_control_items AS parent ON parent.id = item.parent_id
                  WHERE item.id = financial_transactions.expense_control_item_id),
                (SELECT name FROM expense_control_items
                  WHERE expense_control_items.id = financial_transactions.expense_control_item_id),
                'Archived Item'
              )
            END,
            display_icon_key = (
              SELECT icon_key FROM expense_control_items
              WHERE expense_control_items.id = financial_transactions.expense_control_item_id
            ),
            updated_at = created_at
          WHERE display_name IS NULL
        ''');
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
