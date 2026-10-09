import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'package:finance/core/database/balance_ledger.dart';
import 'package:finance/core/database/tables/expense_control_items_table.dart';
import 'package:finance/core/database/tables/financial_transactions_table.dart';
import 'package:finance/core/database/tables/pull_cursor_table.dart';
import 'package:finance/core/sync/sync_outbox_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [ExpenseControlItems, FinancialTransactions, SyncOutbox, PullCursor],
)
class AppDatabase extends _$AppDatabase {
  // `web:` is required on Web — drift_flutter throws ArgumentError without
  // it there (Multi-Platform Support section). Both assets are same-origin
  // under web/, per the constitution's local-database mandate; ignored on
  // native platforms.
  AppDatabase()
    : super(
        driftDatabase(
          name: 'finance',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  /// For tests only — accepts an in-memory or otherwise custom executor
  /// instead of the real on-device file, e.g. `NativeDatabase.memory()`.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 8;

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
      if (from <= 6) {
        await m.createTable(pullCursor);

        // FR-005a/research.md Decision 10: switch every existing
        // DateTimeColumn on the two syncable tables from Drift's default
        // unix-seconds integer encoding to ISO-8601 text, matching the
        // `store_date_time_values_as_text: true` build option now enabled
        // (build.yaml). This project's migrations use the simple cumulative
        // `onUpgrade` callback style, not `stepByStep`, so the generated
        // `schema.entities.whereType<TableInfo>()` snapshot Drift's own
        // migration guide recommends for step-by-step migrations is not
        // available here — verified directly against Drift's docs before
        // writing this. Using `allTables` instead would be the documented
        // data-loss pitfall (GitHub Discussion #3603): it reflects the
        // CURRENT (latest-code) schema, not the schema as it exists in an
        // upgrading user's actual v6-or-earlier database, and would break
        // the moment a future `if (from <= 7)` block adds or removes a
        // table. Iterating this fixed, explicit list of the two tables
        // actually being migrated sidesteps that risk entirely, and stays
        // safe even after future migration blocks are added above this one.
        //
        // v8 added columns to both tables: the current definition used here
        // already contains them, but a v6 table does not, so they are named
        // as `newColumns` (not copied from the old table, which lacks them).
        final newColumnsOf = <TableInfo, List<GeneratedColumn>>{
          expenseControlItems: [
            expenseControlItems.balanceBase,
            expenseControlItems.serverBalance,
          ],
          financialTransactions: [financialTransactions.reversesId],
        };
        for (final table in <TableInfo>[
          expenseControlItems,
          financialTransactions,
        ]) {
          final dateTimeColumns = table.$columns.where(
            (c) => c.type == DriftSqlType.dateTime,
          );
          if (dateTimeColumns.isNotEmpty) {
            // `TableMigration` is marked `@experimental` as of drift 2.22.1
            // (this project's pinned version) — it has been the documented,
            // stable-since-2.4 API for this exact migration pattern per
            // Drift's own official guide the entire time; the annotation was
            // only lifted at drift 2.32.0. Verified directly against Drift's
            // changelog before accepting this warning rather than avoiding
            // the API (research.md Decision 10).
            await m.alterTable(
              // ignore: experimental_member_use
              TableMigration(
                table,
                columnTransformer: {
                  for (final column in dateTimeColumns)
                    column: DateTimeExpressions.fromUnixEpoch(
                      column.dartCast<int>(),
                    ),
                },
                newColumns: newColumnsOf[table] ?? const [],
              ),
            );
          }
        }
      }
      if (from <= 7) {
        // research.md Decision 1: an item's balance becomes derived from its
        // transactions. Every column is added only when it is missing:
        // blocks above create or recreate tables from the CURRENT
        // definition, which already has them, and an old fixture may have no
        // `sync_outbox` at all.
        await _addColumnIfMissing(
          m,
          financialTransactions,
          financialTransactions.reversesId,
        );
        await _addColumnIfMissing(
          m,
          expenseControlItems,
          expenseControlItems.balanceBase,
        );
        await _addColumnIfMissing(
          m,
          expenseControlItems,
          expenseControlItems.serverBalance,
        );
        await _addColumnIfMissing(m, syncOutbox, syncOutbox.rejectedAt);
        await _addColumnIfMissing(m, syncOutbox, syncOutbox.rejectReason);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS financial_transactions_item_idx '
          'ON financial_transactions (expense_control_item_id)',
        );
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS '
          'financial_transactions_reverses_id_uidx '
          'ON financial_transactions (reverses_id) '
          'WHERE reverses_id IS NOT NULL',
        );
        // After the columns exist: balance_base = balance − Σ effects, so the
        // derived balance equals the stored one at the moment of the upgrade
        // (SC-006) and no balance changes.
        await BalanceLedger.backfillBalanceBase(this);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// `ALTER TABLE … ADD COLUMN`, skipped when [table] does not exist or
  /// already has [column] (see the v8 block of [migration]).
  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    final info = await customSelect(
      'PRAGMA table_info(${table.actualTableName})',
    ).get();
    if (info.isEmpty) return;
    if (info.any((row) => row.read<String>('name') == column.name)) return;
    await m.addColumn(table, column);
  }
}
