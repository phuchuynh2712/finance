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
}
