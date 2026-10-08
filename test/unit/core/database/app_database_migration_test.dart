import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/database/balance_ledger.dart';
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
      final items = await (database.select(
        database.expenseControlItems,
      )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
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
          (await database.select(database.financialTransactions).get()).single;
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

  migrationV8Tests();
}

/// A real v7 database: both syncable tables with ISO-8601 text dates (the
/// encoding in place since v7), one outbox table, no v8 columns.
Database _openV7() {
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
      created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
      updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
      deleted_at TEXT
    )
  ''');
  raw.execute('''
    CREATE TABLE financial_transactions (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      expense_control_item_id TEXT NOT NULL,
      direction TEXT NOT NULL,
      amount INTEGER NOT NULL,
      occurred_at TEXT NOT NULL,
      display_name TEXT,
      display_group_name TEXT,
      display_icon_key TEXT,
      created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
      updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
      deleted_at TEXT
    )
  ''');
  raw.execute('''
    CREATE TABLE sync_outbox (
      id TEXT PRIMARY KEY,
      entity_table TEXT NOT NULL,
      row_id TEXT NOT NULL,
      operation TEXT NOT NULL,
      payload TEXT NOT NULL,
      synced_at TEXT,
      retry_count INTEGER NOT NULL DEFAULT 0
    )
  ''');
  raw.execute('''
    CREATE TABLE pull_cursor (
      user_id TEXT NOT NULL,
      table_name TEXT NOT NULL,
      last_updated_at TEXT,
      last_id TEXT,
      initial_pull_completed INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (user_id, table_name)
    )
  ''');
  // food: 1.000.000 allocated before the log, then +300.000 income and
  // -100.000 expense (a soft-deleted -999.999 expense must not count).
  // debt: a negative balance. old: a legacy balance with no transaction.
  raw.execute('''
    INSERT INTO expense_control_items
      (id, user_id, name, icon_key, balance, created_at, updated_at)
    VALUES
      ('food', 'user', 'Food', 'utensils', 1200000,
       '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
      ('debt', 'user', 'Debt', 'home', -250000,
       '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
      ('old', 'user', 'Old', 'home', 4000,
       '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z')
  ''');
  raw.execute('''
    INSERT INTO financial_transactions
      (id, user_id, expense_control_item_id, direction, amount, occurred_at,
       created_at, updated_at, deleted_at)
    VALUES
      ('t1', 'user', 'food', 'income', 300000, '2026-01-02T00:00:00.000Z',
       '2026-01-02T00:00:00.000Z', '2026-01-02T00:00:00.000Z', NULL),
      ('t2', 'user', 'food', 'expense', 100000, '2026-01-03T00:00:00.000Z',
       '2026-01-03T00:00:00.000Z', '2026-01-03T00:00:00.000Z', NULL),
      ('t3', 'user', 'food', 'expense', 999999, '2026-01-04T00:00:00.000Z',
       '2026-01-04T00:00:00.000Z', '2026-01-04T00:00:00.000Z',
       '2026-01-05T00:00:00.000Z'),
      ('t4', 'user', 'debt', 'expense', 50000, '2026-01-02T00:00:00.000Z',
       '2026-01-02T00:00:00.000Z', '2026-01-02T00:00:00.000Z', NULL)
  ''');
  raw.execute('''
    INSERT INTO sync_outbox (id, entity_table, row_id, operation, payload)
    VALUES ('o1', 'financial_transactions', 't1', 'insert', '{}')
  ''');
  raw.execute('PRAGMA user_version = 7');
  return raw;
}

Future<Set<String>> _columns(AppDatabase database, String table) async {
  final rows = await database.customSelect('PRAGMA table_info($table)').get();
  return {for (final r in rows) r.read<String>('name')};
}

void migrationV8Tests() {
  test('upgrades version 7 to 8: new columns, backfilled balance_base, '
      'unchanged derived balances (SC-006)', () async {
    final database = AppDatabase.forTesting(NativeDatabase.opened(_openV7()));
    addTearDown(database.close);

    expect(
      await _columns(database, 'financial_transactions'),
      contains('reverses_id'),
    );
    expect(
      await _columns(database, 'expense_control_items'),
      containsAll(['balance_base', 'server_balance']),
    );
    expect(
      await _columns(database, 'sync_outbox'),
      containsAll(['rejected_at', 'reject_reason']),
    );

    final items = {
      for (final i in await database.select(database.expenseControlItems).get())
        i.id: i,
    };
    // balance_base = balance − Σ effects of live rows.
    expect(items['food']!.balanceBase, 1200000 - 300000 + 100000);
    expect(items['debt']!.balanceBase, -250000 + 50000);
    expect(items['old']!.balanceBase, 4000);
    expect(items.values.every((i) => i.serverBalance == null), isTrue);
    // The stored balances were not touched, and recomputing from the base
    // gives exactly the same figures.
    expect(items['food']!.balance, 1200000);
    await BalanceLedger.recomputeBalances(database, ['food', 'debt', 'old']);
    final after = {
      for (final i in await database.select(database.expenseControlItems).get())
        i.id: i.balance,
    };
    expect(after, {'food': 1200000, 'debt': -250000, 'old': 4000});

    // The unique index refuses a second reversal of the same transaction.
    final indexes = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND tbl_name = 'financial_transactions'",
        )
        .get();
    expect(
      indexes.map((r) => r.read<String>('name')),
      containsAll([
        'financial_transactions_item_idx',
        'financial_transactions_reverses_id_uidx',
      ]),
    );
    Future<void> reversal(String id) => database
        .into(database.financialTransactions)
        .insert(
          FinancialTransactionsCompanion.insert(
            id: id,
            userId: 'user',
            expenseControlItemId: 'food',
            direction: TransactionDirection.expense,
            amount: 100000,
            occurredAt: DateTime.utc(2026, 2, 1),
            reversesId: const Value('t2'),
          ),
        );
    await reversal('r1');
    await expectLater(reversal('r2'), throwsA(isA<Exception>()));

    // The outbox keeps its rows and can carry a refusal.
    final outbox = (await database.select(database.syncOutbox).get()).single;
    expect(outbox.rejectedAt, isNull);
    expect(outbox.rejectReason, isNull);
  });

  test('upgrades version 6 to 8 (cumulative blocks, tables recreated by the '
      'v7 conversion get the new columns)', () async {
    final raw = sqlite3.openInMemory();
    raw.execute('''
      CREATE TABLE expense_control_items (
        id TEXT PRIMARY KEY, user_id TEXT NOT NULL, parent_id TEXT,
        name TEXT NOT NULL, icon_key TEXT NOT NULL, description TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0, allocation_method TEXT,
        allocation_value REAL, balance INTEGER NOT NULL DEFAULT 0,
        is_savings_receiver INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
        deleted_at INTEGER
      )
    ''');
    raw.execute('''
      CREATE TABLE financial_transactions (
        id TEXT PRIMARY KEY, user_id TEXT NOT NULL,
        expense_control_item_id TEXT NOT NULL, direction TEXT NOT NULL,
        amount INTEGER NOT NULL, occurred_at INTEGER NOT NULL,
        display_name TEXT, display_group_name TEXT, display_icon_key TEXT,
        created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
        deleted_at INTEGER
      )
    ''');
    raw.execute('''
      CREATE TABLE sync_outbox (
        id TEXT PRIMARY KEY, entity_table TEXT NOT NULL,
        row_id TEXT NOT NULL, operation TEXT NOT NULL,
        payload TEXT NOT NULL, synced_at INTEGER,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
    raw.execute('''
      INSERT INTO expense_control_items
        (id, user_id, name, icon_key, balance, created_at, updated_at)
      VALUES ('food', 'user', 'Food', 'utensils', 700, 1717200000, 1717200000)
    ''');
    raw.execute('''
      INSERT INTO financial_transactions
        (id, user_id, expense_control_item_id, direction, amount,
         occurred_at, created_at, updated_at)
      VALUES ('t1', 'user', 'food', 'income', 200, 1717200000, 1717200000,
              1717200000)
    ''');
    raw.execute('PRAGMA user_version = 6');

    final database = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(database.close);

    final food =
        (await database.select(database.expenseControlItems).get()).single;
    expect(food.balance, 700);
    expect(food.balanceBase, 500);
    expect(food.serverBalance, isNull);
    expect(
      await _columns(database, 'financial_transactions'),
      contains('reverses_id'),
    );
    expect(await _columns(database, 'sync_outbox'), contains('rejected_at'));
  });

  test('upgrades version 5 to 8 even though that fixture has no '
      'sync_outbox table', () async {
    final raw = sqlite3.openInMemory();
    raw.execute('''
      CREATE TABLE expense_control_items (
        id TEXT PRIMARY KEY, user_id TEXT NOT NULL, parent_id TEXT,
        name TEXT NOT NULL, icon_key TEXT NOT NULL, description TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0, allocation_method TEXT,
        allocation_value REAL, balance INTEGER NOT NULL DEFAULT 0,
        is_savings_receiver INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
        deleted_at INTEGER
      )
    ''');
    raw.execute('''
      CREATE TABLE financial_transactions (
        id TEXT PRIMARY KEY, user_id TEXT NOT NULL,
        expense_control_item_id TEXT NOT NULL, direction TEXT NOT NULL,
        amount INTEGER NOT NULL, occurred_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    raw.execute('''
      INSERT INTO expense_control_items
        (id, user_id, name, icon_key, balance, created_at, updated_at)
      VALUES ('food', 'user', 'Food', 'utensils', 100, 1717200000, 1717200000)
    ''');
    raw.execute('''
      INSERT INTO financial_transactions
        (id, user_id, expense_control_item_id, direction, amount,
         occurred_at, created_at)
      VALUES ('t1', 'user', 'food', 'expense', 40, 1717200000, 1717200000)
    ''');
    raw.execute('PRAGMA user_version = 5');

    final database = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(database.close);

    final food =
        (await database.select(database.expenseControlItems).get()).single;
    expect(food.balance, 100);
    expect(food.balanceBase, 140);
  });
}
