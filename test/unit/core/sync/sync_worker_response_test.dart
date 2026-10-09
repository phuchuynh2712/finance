import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/database/tables/financial_transactions_table.dart';
import 'package:finance/core/sync/sync_notice.dart';
import 'package:finance/core/sync/sync_outbox_table.dart';
import 'package:finance/core/sync/sync_worker.dart';

const _userId = 'test-user';
final _fast = DateTime.utc(2099, 1, 1); // a device clock running far ahead
final _server = DateTime.utc(2026, 6, 1, 12);
final _t0 = DateTime.utc(2026, 1, 1);

SupabaseClient _unusedClient() =>
    SupabaseClient('https://example.invalid', 'anon-key-unused');

Map<String, dynamic> _txPayload({
  int amount = 100,
  DateTime? updatedAt,
  DateTime? deletedAt,
}) => {
  'id': 'txn',
  'user_id': _userId,
  'expense_control_item_id': 'food',
  'direction': 'expense',
  'amount': amount,
  'occurred_at': _t0.toIso8601String(),
  'created_at': _t0.toIso8601String(),
  'updated_at': (updatedAt ?? _t0).toIso8601String(),
  'deleted_at': deletedAt?.toIso8601String(),
  'reverses_id': null,
};

Map<String, dynamic> _itemPayload({
  String name = 'Food',
  DateTime? updatedAt,
}) => {
  'id': 'food',
  'user_id': _userId,
  'name': name,
  'icon_key': 'utensils',
  'sort_order': 0,
  'balance': 0,
  'balance_base': 0,
  'is_savings_receiver': false,
  'created_at': _t0.toIso8601String(),
  'updated_at': (updatedAt ?? _t0).toIso8601String(),
};

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedTx({int amount = 100, required DateTime updatedAt}) => db
      .into(db.financialTransactions)
      .insert(
        FinancialTransactionsCompanion.insert(
          id: 'txn',
          userId: _userId,
          expenseControlItemId: 'food',
          direction: TransactionDirection.expense,
          amount: amount,
          occurredAt: _t0,
          updatedAt: Value(updatedAt),
        ),
      );

  Future<void> seedItem({required DateTime updatedAt, String name = 'Food'}) =>
      db
          .into(db.expenseControlItems)
          .insert(
            ExpenseControlItemsCompanion.insert(
              id: 'food',
              userId: _userId,
              name: name,
              iconKey: 'utensils',
              updatedAt: Value(updatedAt),
            ),
          );

  Future<void> outbox(
    String id,
    String table,
    Map<String, dynamic> payload, {
    SyncOperation op = SyncOperation.update,
  }) => db
      .into(db.syncOutbox)
      .insert(
        SyncOutboxCompanion.insert(
          id: id,
          entityTable: table,
          rowId: payload['id'] as String,
          operation: op,
          payload: jsonEncode(payload),
        ),
      );

  Future<FinancialTransactionRow> readTx() => (db.select(
    db.financialTransactions,
  )..where((t) => t.id.equals('txn'))).getSingle();

  Future<FinancialTransactionRow?> readTxOrNull() => (db.select(
    db.financialTransactions,
  )..where((t) => t.id.equals('txn'))).getSingleOrNull();

  group('a push response is applied unconditionally', () {
    test('a transaction row replaces a local row whose updated_at is in the '
        'future (a device clock running fast), and takes the server\'s '
        'timestamp', () async {
      await seedTx(updatedAt: _fast);
      await outbox(
        'o1',
        'financial_transactions',
        _txPayload(updatedAt: _fast),
      );
      final worker = SyncWorker(
        db,
        _unusedClient(),
        push: (table, payload) async => {
          ...payload,
          // The server's guard returns the row deleted ("delete wins").
          'deleted_at': _server.toIso8601String(),
          'updated_at': _server.toIso8601String(),
        },
      );

      await worker.drainOutbox();

      final stored = await readTx();
      expect(stored.deletedAt, _server);
      expect(stored.updatedAt, _server);
    });

    test('an item row replaces a local row with a future updated_at', () async {
      await seedItem(updatedAt: _fast, name: 'Local');
      await outbox('o1', 'expense_control_items', _itemPayload(name: 'Local'));
      final worker = SyncWorker(
        db,
        _unusedClient(),
        push: (table, payload) async => {
          ...payload,
          'name': 'Server',
          'updated_at': _server.toIso8601String(),
        },
      );

      await worker.drainOutbox();

      final stored = await (db.select(
        db.expenseControlItems,
      )..where((t) => t.id.equals('food'))).getSingle();
      expect(stored.name, 'Server');
      expect(stored.updatedAt, _server);
    });

    test('when a later entry for the same row is still waiting, the local row '
        'is left as it is', () async {
      await seedTx(amount: 999, updatedAt: _fast);
      await outbox('o1', 'financial_transactions', _txPayload(amount: 100));
      await outbox('o2', 'financial_transactions', _txPayload(amount: 999));
      final worker = SyncWorker(
        db,
        _unusedClient(),
        push: (table, payload) async {
          if (payload['amount'] == 999) throw Exception('offline');
          return {...payload, 'updated_at': _server.toIso8601String()};
        },
      );

      await worker.drainOutbox();

      // The first entry synced, but its (older) response did not overwrite
      // the newer local edit that o2 will push.
      final stored = await readTx();
      expect(stored.amount, 999);
      expect(stored.updatedAt, _fast);
      final rows = await db.select(db.syncOutbox).get();
      expect(rows.firstWhere((r) => r.id == 'o1').syncedAt, isNotNull);
      expect(rows.firstWhere((r) => r.id == 'o2').syncedAt, isNull);
      expect(rows.firstWhere((r) => r.id == 'o2').retryCount, 1);
    });
  });

  group('permanent push refusals', () {
    test(
      'a refused insert is rejected, removed locally and not retried',
      () async {
        await seedItem(updatedAt: _t0);
        await seedTx(amount: 100, updatedAt: _fast);
        await outbox(
          'o1',
          'financial_transactions',
          _txPayload(amount: 100, updatedAt: _fast),
          op: SyncOperation.insert,
        );
        final notices = SyncNotices(db);
        await notices.loaded;
        final noticeFuture = notices.stream.first;
        var pushes = 0;
        final worker = SyncWorker(
          db,
          _unusedClient(),
          push: (table, payload) async {
            pushes++;
            throw const PostgrestException(
              message: 'invalid reversal',
              code: 'TX001',
            );
          },
          notices: notices,
          now: () => _server,
        );

        await worker.drainOutbox();

        expect(await readTxOrNull(), isNull);
        final rejected = (await db.select(db.syncOutbox).get()).single;
        expect(rejected.rejectedAt, _server);
        expect(rejected.rejectReason, 'invalid_reversal');
        expect(rejected.retryCount, 0);
        expect((await noticeFuture).reason, SyncNoticeReason.deleted);
        await worker.requestDrain();
        expect(pushes, 1);
        await notices.dispose();
      },
    );

    test(
      'a refused update restores the current server row despite local time',
      () async {
        await seedTx(amount: 200, updatedAt: _fast);
        await outbox(
          'o1',
          'financial_transactions',
          _txPayload(amount: 200, updatedAt: _fast),
        );
        final notices = SyncNotices(db);
        await notices.loaded;
        final noticeFuture = notices.stream.first;
        final worker = SyncWorker(
          db,
          _unusedClient(),
          push: (table, payload) async => throw const PostgrestException(
            message: 'transaction already reversed',
            code: 'TX003',
          ),
          fetchRow: (table, id) async =>
              _txPayload(amount: 100, updatedAt: _server),
          notices: notices,
          now: () => _server,
        );

        await worker.drainOutbox();

        final stored = await readTx();
        expect(stored.amount, 100);
        expect(stored.updatedAt, _server);
        expect(
          (await db.select(db.syncOutbox).get()).single.rejectReason,
          'transaction_reversed',
        );
        expect((await noticeFuture).reason, SyncNoticeReason.reversed);
        await notices.dispose();
      },
    );

    test('a push-time server override is applied and reported once', () async {
      await seedTx(amount: 100, updatedAt: _fast);
      await outbox(
        'o1',
        'financial_transactions',
        _txPayload(amount: 100, updatedAt: _fast),
      );
      final notices = SyncNotices(db);
      await notices.loaded;
      final noticeFuture = notices.stream.first;
      final worker = SyncWorker(
        db,
        _unusedClient(),
        push: (table, payload) async => {
          ...payload,
          'amount': 150,
          'updated_at': _server.toIso8601String(),
        },
        notices: notices,
        now: () => _server,
      );

      await worker.drainOutbox();

      expect((await readTx()).amount, 150);
      expect((await noticeFuture).reason, SyncNoticeReason.editedElsewhere);
      expect((await db.select(db.syncOutbox).get()).single.syncedAt, _server);
      await notices.dispose();
    });
  });

  test(
    'requestDrain coalesces requests made during the active drain',
    () async {
      await seedItem(updatedAt: _t0);
      await outbox('o1', 'expense_control_items', _itemPayload());
      final pushGate = Completer<void>();
      final enteredPush = Completer<void>();
      var pushes = 0;
      final worker = SyncWorker(
        db,
        _unusedClient(),
        push: (table, payload) async {
          pushes++;
          if (pushes == 1) {
            enteredPush.complete();
            await pushGate.future;
            await outbox(
              'o2',
              'expense_control_items',
              _itemPayload(name: 'Updated'),
            );
          }
          return {...payload, 'updated_at': _server.toIso8601String()};
        },
        now: () => _server,
      );

      final drain = worker.drainOutbox();
      await enteredPush.future;
      final requested = [
        worker.requestDrain(),
        worker.requestDrain(),
        worker.requestDrain(),
      ];
      pushGate.complete();
      await Future.wait([drain, ...requested]);

      expect(pushes, 2);
      expect(
        (await db.select(db.syncOutbox).get()).every(
          (row) => row.syncedAt != null,
        ),
        isTrue,
      );
    },
  );

  group('onIdle', () {
    test('is called at the end of a drain of an empty outbox', () async {
      var calls = 0;
      final worker = SyncWorker(
        db,
        _unusedClient(),
        push: (table, payload) async => payload,
        onIdle: () => calls++,
      );

      await worker.drainOutbox();

      expect(calls, 1);
    });

    test('is called after a drain that synced everything', () async {
      await seedItem(updatedAt: _t0);
      await outbox('o1', 'expense_control_items', _itemPayload());
      var calls = 0;
      final worker = SyncWorker(
        db,
        _unusedClient(),
        push: (table, payload) async => {
          ...payload,
          'updated_at': _server.toIso8601String(),
        },
        onIdle: () => calls++,
      );

      await worker.drainOutbox();

      expect(calls, 1);
    });

    test('is not called while an entry is still waiting', () async {
      await seedItem(updatedAt: _t0);
      await outbox('o1', 'expense_control_items', _itemPayload());
      var calls = 0;
      final worker = SyncWorker(
        db,
        _unusedClient(),
        push: (table, payload) async => throw Exception('offline'),
        onIdle: () => calls++,
      );

      await worker.drainOutbox();

      expect(calls, 0);
    });

    test('an exception thrown by onIdle does not break the drain', () async {
      final worker = SyncWorker(
        db,
        _unusedClient(),
        push: (table, payload) async => payload,
        onIdle: () => throw StateError('monitor failed'),
      );

      await expectLater(worker.drainOutbox(), completes);
    });
  });
}
