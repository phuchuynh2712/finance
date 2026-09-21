import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/database/app_database.dart';

/// FR-008, data-model.md's Drift Schema Change — exercises the REAL
/// `AppDatabase.migration.onUpgrade` `if (from <= 3)` branch against an
/// actual v3-schema SQLite file (the schema shipped by the prior feature:
/// `ExpenseControlItems` has `balance` but not `is_savings_receiver`), not
/// an in-memory DB created fresh at the latest schema (which never runs
/// `onUpgrade` at all).
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('finance_migration_test');
    dbFile = File('${tempDir.path}/finance_v3.sqlite');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  void seedV3Database() {
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

  /// A v2-schema fixture, deliberately without `balance` or
  /// `is_savings_receiver` at all — used by the multi-version-jump test
  /// below, which exists specifically to catch a regression of the
  /// `if (from == N)` vs. `if (from <= N)` bug found while implementing
  /// this feature (T003): `onUpgrade` fires ONCE per open with `from`
  /// fixed at the actual starting version, so a v2→v4 jump must still run
  /// every intermediate step in one pass.
  void seedV2DatabaseNoEnvelopeTables() {
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
      PRAGMA user_version = 2;
    ''');

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    raw.execute('''
      INSERT INTO expense_control_items
        (id, user_id, parent_id, name, icon_key, sort_order, allocation_method, allocation_value, created_at, updated_at)
      VALUES ('item1', 'u1', NULL, 'Rent', 'home', 0, 'fixed', 5000000, $now, $now);
    ''');
    raw.dispose();
  }

  test(
    'upgrading a real v3 database adds is_savings_receiver cleanly, existing rows default to false, balance untouched',
    () async {
      seedV3Database();

      final db = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(db.close);

      final items = await db.select(db.expenseControlItems).get();

      expect(items, hasLength(1));
      expect(items.single.id, 'item1');
      expect(items.single.balance, 250000); // untouched by this migration
      expect(items.single.isSavingsReceiver, isFalse);
    },
  );

  test(
    'a v2→v4 jump (skipping v3 entirely) still applies every intermediate migration step in one pass — regression test for the from==N vs from<=N bug',
    () async {
      seedV2DatabaseNoEnvelopeTables();

      final db = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(db.close);

      // If onUpgrade only matched `from == 3` (not `from <= 3`), this
      // column would never be added when jumping directly from v2, and
      // this query would throw or return a stale/missing column.
      final items = await db.select(db.expenseControlItems).get();

      expect(items, hasLength(1));
      expect(items.single.balance, 0); // v2→v3 step's column, defaulted
      expect(items.single.isSavingsReceiver, isFalse); // v3→v4 step's column
    },
  );
}
