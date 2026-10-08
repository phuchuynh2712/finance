import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/database/tables/financial_transactions_table.dart';
import 'package:finance/core/sync/sync_outbox_table.dart';
import 'package:finance/core/sync/sync_worker.dart';

const _userId = 'test-user';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedItem({
    required String id,
    required DateTime updatedAt,
  }) async {
    await db
        .into(db.expenseControlItems)
        .insert(
          ExpenseControlItemsCompanion.insert(
            id: id,
            userId: _userId,
            name: 'Food',
            iconKey: 'utensils',
            updatedAt: Value(updatedAt),
          ),
        );
  }

  Future<String> seedOutboxRow({
    required String entityTable,
    required Map<String, dynamic> payload,
  }) async {
    final id = 'outbox-1';
    await db
        .into(db.syncOutbox)
        .insert(
          SyncOutboxCompanion.insert(
            id: id,
            entityTable: entityTable,
            rowId: payload['id'] as String,
            operation: SyncOperation.update,
            payload: jsonEncode(payload),
          ),
        );
    return id;
  }

  test('read-back writes the server-returned updated_at to the local row via '
      'the remote-row write helper (research.md Decision 1)', () async {
    final staleUpdatedAt = DateTime.utc(2020, 1, 1);
    final serverUpdatedAt = DateTime.utc(2026, 6, 1, 12);
    await seedItem(id: 'food', updatedAt: staleUpdatedAt);

    final payload = {
      'id': 'food',
      'user_id': _userId,
      'name': 'Food',
      'icon_key': 'utensils',
      'sort_order': 0,
      'balance': 0,
      'balance_base': 0,
      'is_savings_receiver': false,
      'created_at': staleUpdatedAt.toIso8601String(),
      // Client sends a stale value; the fake `push` below simulates the
      // FR-005a trigger overriding it, exactly as the real Postgres
      // trigger does (verified against the real server in T008).
      'updated_at': staleUpdatedAt.toIso8601String(),
    };
    await seedOutboxRow(entityTable: 'expense_control_items', payload: payload);

    final worker = SyncWorker(
      db,
      SupabaseClient('https://example.invalid', 'anon-key-unused'),
      push: (table, sentPayload) async {
        expect(table, 'expense_control_items');
        expect(sentPayload['updated_at'], staleUpdatedAt.toIso8601String());
        return {
          ...sentPayload,
          'updated_at': serverUpdatedAt.toIso8601String(),
        };
      },
    );

    await worker.drainOutbox();

    final stored = await (db.select(
      db.expenseControlItems,
    )..where((t) => t.id.equals('food'))).getSingle();
    expect(stored.updatedAt, serverUpdatedAt);
  });

  test('the read-back write does not append a new sync_outbox entry '
      '(research.md Decision 7 — write goes through applyRemoteRow, not '
      '_appendOutbox)', () async {
    final updatedAt = DateTime.utc(2026, 1, 1);
    await seedItem(id: 'food', updatedAt: updatedAt);
    final payload = {
      'id': 'food',
      'user_id': _userId,
      'name': 'Food',
      'icon_key': 'utensils',
      'sort_order': 0,
      'balance': 0,
      'balance_base': 0,
      'is_savings_receiver': false,
      'created_at': updatedAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    await seedOutboxRow(entityTable: 'expense_control_items', payload: payload);

    final worker = SyncWorker(
      db,
      SupabaseClient('https://example.invalid', 'anon-key-unused'),
      push: (table, sentPayload) async {
        return {
          ...sentPayload,
          'updated_at': DateTime.utc(2026, 6, 1).toIso8601String(),
        };
      },
    );

    await worker.drainOutbox();

    final outboxRows = await db.select(db.syncOutbox).get();
    // The original outbox row (now marked synced) is the only one — the
    // read-back write must not have queued a second push for itself.
    expect(outboxRows, hasLength(1));
  });

  test('a financial_transactions read-back parses the correct table shape '
      'and reaches the local row', () async {
    final updatedAt = DateTime.utc(2026, 1, 1);
    await db
        .into(db.financialTransactions)
        .insert(
          FinancialTransactionsCompanion.insert(
            id: 'txn',
            userId: _userId,
            expenseControlItemId: 'food',
            direction: TransactionDirection.expense,
            amount: 1000,
            occurredAt: updatedAt,
            updatedAt: Value(updatedAt),
          ),
        );
    final payload = {
      'id': 'txn',
      'user_id': _userId,
      'expense_control_item_id': 'food',
      'direction': 'expense',
      'amount': 1000,
      'occurred_at': updatedAt.toIso8601String(),
      'created_at': updatedAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    await seedOutboxRow(
      entityTable: 'financial_transactions',
      payload: payload,
    );

    final serverUpdatedAt = DateTime.utc(2026, 6, 1, 12);
    final worker = SyncWorker(
      db,
      SupabaseClient('https://example.invalid', 'anon-key-unused'),
      push: (table, sentPayload) async {
        expect(table, 'financial_transactions');
        return {
          ...sentPayload,
          'updated_at': serverUpdatedAt.toIso8601String(),
        };
      },
    );

    await worker.drainOutbox();

    final stored = await (db.select(
      db.financialTransactions,
    )..where((t) => t.id.equals('txn'))).getSingle();
    expect(stored.updatedAt, serverUpdatedAt);
  });
}
