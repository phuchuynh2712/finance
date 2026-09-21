import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/database/tables/financial_transactions_table.dart';

/// research.md Decision 7 — exercises the REAL
/// `AppDatabase.migration.onUpgrade` `if (from <= 4)` branch against an
/// actual v4-schema SQLite file (the schema shipped by the prior feature:
/// `ExpenseControlItems` has `is_savings_receiver` but `financial_transactions`
/// does not exist yet), not an in-memory DB created fresh at the latest
/// schema (which never runs `onUpgrade` at all).
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('finance_migration_test');
    dbFile = File('${tempDir.path}/finance_v4.sqlite');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  void seedV4Database() {
    final raw = sqlite3.sqlite3.open(dbFile.path);
    raw.execute('''
      CREATE TABLE expense_control_items (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL,
        parent_id TEXT NULL,
        name TEXT NOT NULL,
        icon_key TEXT NOT NULL,
        description TEXT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        allocation_method TEXT NULL,
        allocation_value REAL NULL,
        balance INTEGER NOT NULL DEFAULT 0,
        is_savings_receiver INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER NULL
      );
      CREATE TABLE sync_outbox (
        id TEXT NOT NULL PRIMARY KEY,
        entity_table TEXT NOT NULL,
        row_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        synced_at INTEGER NULL,
        retry_count INTEGER NOT NULL DEFAULT 0
      );
      PRAGMA user_version = 4;
    ''');

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    raw.execute('''
      INSERT INTO expense_control_items
        (id, user_id, parent_id, name, icon_key, sort_order, allocation_method, allocation_value, balance, is_savings_receiver, created_at, updated_at)
      VALUES ('item1', 'u1', NULL, 'Rent', 'home', 0, 'fixed', 5000000, 250000, 0, $now, $now);
    ''');
    raw.dispose();
  }

  /// A v3-schema fixture, deliberately without `is_savings_receiver` or
  /// `financial_transactions` at all — used by the multi-version-jump test
  /// below, mirroring `schema_v3_to_v4_migration_test.dart`'s own v2→v4
  /// regression case for the `if (from == N)` vs. `if (from <= N)` bug:
  /// `onUpgrade` fires ONCE per open with `from` fixed at the actual
  /// starting version, so a v3→v5 jump must still run every intermediate
  /// step in one pass.
  void seedV3DatabaseNoSavingsReceiverColumn() {
    final raw = sqlite3.sqlite3.open(dbFile.path);
    raw.execute('''
      CREATE TABLE expense_control_items (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL,
        parent_id TEXT NULL,
        name TEXT NOT NULL,
        icon_key TEXT NOT NULL,
        description TEXT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        allocation_method TEXT NULL,
        allocation_value REAL NULL,
        balance INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER NULL
      );
      CREATE TABLE sync_outbox (
        id TEXT NOT NULL PRIMARY KEY,
        entity_table TEXT NOT NULL,
        row_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        synced_at INTEGER NULL,
        retry_count INTEGER NOT NULL DEFAULT 0
      );
      PRAGMA user_version = 3;
    ''');

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    raw.execute('''
      INSERT INTO expense_control_items
        (id, user_id, parent_id, name, icon_key, sort_order, allocation_method, allocation_value, balance, created_at, updated_at)
      VALUES ('item1', 'u1', NULL, 'Rent', 'home', 0, 'fixed', 5000000, 250000, $now, $now);
    ''');
    raw.dispose();
  }

  test(
    'upgrading a real v4 database creates financial_transactions cleanly, existing expense_control_items data untouched',
    () async {
      seedV4Database();

      final db = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(db.close);

      final items = await db.select(db.expenseControlItems).get();
      expect(items, hasLength(1));
      expect(items.single.id, 'item1');
      expect(items.single.balance, 250000); // untouched by this migration
      expect(items.single.isSavingsReceiver, isFalse);

      final transactions = await db.select(db.financialTransactions).get();
      expect(transactions, isEmpty);

      // Confirm the table is actually usable, not just present as an empty
      // shell — a real insert/read round-trip through the new table.
      await db
          .into(db.financialTransactions)
          .insert(
            FinancialTransactionsCompanion.insert(
              id: 'txn1',
              userId: 'u1',
              expenseControlItemId: 'item1',
              direction: TransactionDirection.expense,
              amount: 50000,
              occurredAt: DateTime.now(),
            ),
          );
      final inserted = await db.select(db.financialTransactions).get();
      expect(inserted, hasLength(1));
      expect(inserted.single.direction, TransactionDirection.expense);
    },
  );

  test(
    'a v3→v5 jump (skipping v4 entirely) still applies every intermediate migration step in one pass — regression test for the from==N vs from<=N bug',
    () async {
      seedV3DatabaseNoSavingsReceiverColumn();

      final db = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(db.close);

      // If onUpgrade only matched `from == 4` (not `from <= 4`), this table
      // would never be created when jumping directly from v3, and this
      // query would throw.
      final items = await db.select(db.expenseControlItems).get();
      expect(items, hasLength(1));
      expect(items.single.balance, 250000); // v3-native column, untouched
      expect(items.single.isSavingsReceiver, isFalse); // v3→v4 step's column

      final transactions = await db.select(db.financialTransactions).get();
      expect(transactions, isEmpty); // v4→v5 step's table, created cleanly
    },
  );
}
