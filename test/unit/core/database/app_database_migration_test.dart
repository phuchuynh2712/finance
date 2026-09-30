import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/database/tables/financial_transactions_table.dart';

void main() {
  test(
    'upgrades version 5 transactions with immutable snapshots and sync metadata',
    () async {
      final raw = sqlite3.openInMemory();
      raw.execute('''
      CREATE TABLE expense_control_items (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        parent_id TEXT,
        name TEXT NOT NULL,
        icon_key TEXT NOT NULL,
        description TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        allocation_method TEXT,
        allocation_value REAL,
        balance INTEGER NOT NULL DEFAULT 0,
        is_savings_receiver INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER
      )
    ''');
      raw.execute('''
      CREATE TABLE financial_transactions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        expense_control_item_id TEXT NOT NULL,
        direction TEXT NOT NULL,
        amount INTEGER NOT NULL,
        occurred_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
      raw.execute('''
      INSERT INTO expense_control_items
      (id, user_id, name, icon_key, created_at, updated_at)
      VALUES ('food', 'user', 'Food', 'utensils', 1717200000, 1717200000)
    ''');
      raw.execute('''
      INSERT INTO financial_transactions
      (id, user_id, expense_control_item_id, direction, amount, occurred_at, created_at)
      VALUES ('legacy', 'user', 'food', 'expense', 25000, 1717200000, 1717200000)
    ''');
      raw.execute('PRAGMA user_version = 5');

      final database = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(database.close);

      final row =
          (await database.select(database.financialTransactions).get()).single;
      expect(row.direction, TransactionDirection.expense);
      expect(row.displayName, 'Food');
      expect(row.displayGroupName, 'Food');
      expect(row.displayIconKey, 'utensils');
      expect(row.deletedAt, isNull);
      expect(row.updatedAt, row.createdAt);
    },
  );

  test(
    'upgrades version 6 to 7: creates PullCursor and converts DateTime '
    'columns from integer-seconds to ISO-8601 text without data loss',
    () async {
      final raw = sqlite3.openInMemory();
      // A real v6 database has both syncable tables with `created_at`,
      // `updated_at`, `deleted_at` still stored as INTEGER (unix seconds) —
      // the encoding in place before this feature's build.yaml change.
      raw.execute('''
      CREATE TABLE expense_control_items (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        parent_id TEXT,
        name TEXT NOT NULL,
        icon_key TEXT NOT NULL,
        description TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        allocation_method TEXT,
        allocation_value REAL,
        balance INTEGER NOT NULL DEFAULT 0,
        is_savings_receiver INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER
      )
    ''');
      raw.execute('''
      CREATE TABLE financial_transactions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        expense_control_item_id TEXT NOT NULL,
        direction TEXT NOT NULL,
        amount INTEGER NOT NULL,
        occurred_at INTEGER NOT NULL,
        display_name TEXT,
        display_group_name TEXT,
        display_icon_key TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER
      )
    ''');
      raw.execute('''
      CREATE TABLE sync_outbox (
        id TEXT PRIMARY KEY,
        entity_table TEXT NOT NULL,
        row_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        synced_at INTEGER,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
      // One row with a null deleted_at, one with it set — the migration
      // must round-trip both. 1717200000 = 2024-06-01T00:00:00Z, chosen so
      // it has no seconds-only-precision ambiguity to obscure the assertion.
      raw.execute('''
      INSERT INTO expense_control_items
      (id, user_id, name, icon_key, created_at, updated_at, deleted_at)
      VALUES
        ('food', 'user', 'Food', 'utensils', 1717200000, 1717200000, NULL),
        ('rent', 'user', 'Rent', 'home', 1717200000, 1717286400, 1717372800)
    ''');
      raw.execute('''
      INSERT INTO financial_transactions
      (id, user_id, expense_control_item_id, direction, amount, occurred_at,
       display_name, display_group_name, display_icon_key, created_at,
       updated_at, deleted_at)
      VALUES ('legacy', 'user', 'food', 'expense', 25000, 1717200000,
        'Food', 'Food', 'utensils', 1717200000, 1717200000, NULL)
    ''');
      raw.execute('PRAGMA user_version = 6');

      final database = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(database.close);

      // (a) PullCursor exists and is empty.
      final cursors = await database.select(database.pullCursor).get();
      expect(cursors, isEmpty);

      // (b) Every migrated row's DateTime values round-trip correctly and
      // are readable via the regenerated (text-expecting) typed API.
      final items =
          await (database.select(database.expenseControlItems)
                ..orderBy([(t) => OrderingTerm.asc(t.id)]))
              .get();
      expect(items, hasLength(2));
      final food = items.firstWhere((r) => r.id == 'food');
      final rent = items.firstWhere((r) => r.id == 'rent');
      expect(
        food.createdAt,
        DateTime.fromMillisecondsSinceEpoch(1717200000 * 1000, isUtc: true),
      );
      expect(
        food.updatedAt,
        DateTime.fromMillisecondsSinceEpoch(1717200000 * 1000, isUtc: true),
      );
      expect(food.deletedAt, isNull);
      expect(
        rent.updatedAt,
        DateTime.fromMillisecondsSinceEpoch(1717286400 * 1000, isUtc: true),
      );
      expect(
        rent.deletedAt,
        DateTime.fromMillisecondsSinceEpoch(1717372800 * 1000, isUtc: true),
      );

      final transactionRow =
          (await database.select(database.financialTransactions).get())
              .single;
      expect(
        transactionRow.updatedAt,
        DateTime.fromMillisecondsSinceEpoch(1717200000 * 1000, isUtc: true),
      );
      expect(transactionRow.deletedAt, isNull);

      // (c) No row is lost or duplicated (guards against the Discussion
      // #3603 failure mode this migration's own `allTables` avoidance is
      // meant to prevent).
      expect(items, hasLength(2));
      expect(
        await database.select(database.financialTransactions).get(),
        hasLength(1),
      );
    },
  );
}
