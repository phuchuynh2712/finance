import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/sync/sync_notice.dart';
import 'package:finance/core/sync/sync_outbox_table.dart';

final _t0 = DateTime.utc(2026, 1, 1);

SyncNotice _notice(String id, {SyncNoticeReason? reason}) => SyncNotice(
  id: id,
  reason: reason ?? SyncNoticeReason.deleted,
  transactionId: 't',
  itemName: 'Food',
  amount: 100,
);

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> rejected(
    String id, {
    String entityTable = 'financial_transactions',
    String reason = 'transaction_reversed',
    DateTime? rejectedAt,
  }) {
    return db
        .into(db.syncOutbox)
        .insert(
          SyncOutboxCompanion.insert(
            id: id,
            entityTable: entityTable,
            rowId: 'txn-$id',
            operation: SyncOperation.update,
            payload: jsonEncode({
              'id': 'txn-$id',
              'display_name': 'Food',
              'amount': 100,
            }),
            rejectedAt: Value(rejectedAt ?? _t0),
            rejectReason: Value(reason),
          ),
        );
  }

  Future<List<SyncNotice>> collect(SyncNotices notices) async {
    final received = <SyncNotice>[];
    final subscription = notices.stream.listen(received.add);
    addTearDown(subscription.cancel);
    await notices.loaded;
    await Future<void>.delayed(Duration.zero);
    return received;
  }

  test('a notice reported before any listener attaches is delivered when one '
      'attaches', () async {
    final notices = SyncNotices(db);
    await notices.loaded;
    notices.report(_notice('n1'));

    final received = await collect(notices);

    expect(received.map((n) => n.id), ['n1']);
  });

  test(
    'a notice reported while a listener is attached is delivered at once',
    () async {
      final notices = SyncNotices(db);
      final received = await collect(notices);

      notices.report(_notice('n1', reason: SyncNoticeReason.balanceMismatch));
      await Future<void>.delayed(Duration.zero);

      expect(received.single.reason, SyncNoticeReason.balanceMismatch);
    },
  );

  test(
    'the same id is reported at most once until it is acknowledged',
    () async {
      final notices = SyncNotices(db);
      final received = await collect(notices);

      notices.report(_notice('n1'));
      notices.report(_notice('n1'));
      await Future<void>.delayed(Duration.zero);
      expect(received, hasLength(1));

      await notices.acknowledge('n1');
      notices.report(_notice('n1'));
      await Future<void>.delayed(Duration.zero);
      expect(received, hasLength(2));
    },
  );

  test(
    'a notice already delivered is not replayed to a later listener',
    () async {
      final notices = SyncNotices(db);
      await collect(notices);
      notices.report(_notice('n1'));
      await Future<void>.delayed(Duration.zero);

      final late = <SyncNotice>[];
      final subscription = notices.stream.listen(late.add);
      addTearDown(subscription.cancel);
      await Future<void>.delayed(Duration.zero);

      expect(late, isEmpty);
    },
  );

  group('refusals persisted on the outbox', () {
    test('are replayed at start with the item name and amount from the stored '
        'payload and the reason mapped from reject_reason', () async {
      await rejected('o1', reason: 'transaction_reversed');
      await rejected('o2', reason: 'invalid_reversal');
      await rejected('o3', reason: 'already_reversed');
      await rejected('o4', reason: 'reversal_immutable');

      final received = await collect(SyncNotices(db));

      final byId = {for (final n in received) n.id: n};
      expect(byId['outbox:o1']!.reason, SyncNoticeReason.reversed);
      expect(byId['outbox:o2']!.reason, SyncNoticeReason.deleted);
      expect(byId['outbox:o3']!.reason, SyncNoticeReason.alreadyReversed);
      expect(byId['outbox:o4']!.reason, SyncNoticeReason.reversed);
      expect(byId['outbox:o1']!.itemName, 'Food');
      expect(byId['outbox:o1']!.amount, 100);
      expect(byId['outbox:o1']!.transactionId, 'txn-o1');
    });

    test('a check_violation, a row of another table and a row that was not '
        'rejected produce no notice', () async {
      await rejected('o1', reason: 'check_violation');
      await rejected('o2', entityTable: 'expense_control_items');
      await db
          .into(db.syncOutbox)
          .insert(
            SyncOutboxCompanion.insert(
              id: 'o3',
              entityTable: 'financial_transactions',
              rowId: 'txn-o3',
              operation: SyncOperation.insert,
              payload: '{}',
            ),
          );

      expect(await collect(SyncNotices(db)), isEmpty);
    });

    test('acknowledge deletes the rejected outbox row and is a no-op for an '
        'in-memory notice', () async {
      await rejected('o1');
      final notices = SyncNotices(db);
      await collect(notices);

      await notices.acknowledge('outbox:o1');
      await notices.acknowledge('mismatch:food'); // in memory: nothing to do

      expect(await db.select(db.syncOutbox).get(), isEmpty);
    });

    test('survive a restart until acknowledged', () async {
      await rejected('o1');
      await collect(SyncNotices(db)); // shown, but never acknowledged

      final afterRestart = await collect(SyncNotices(db));
      expect(afterRestart.map((n) => n.id), ['outbox:o1']);

      final again = SyncNotices(db);
      await again.loaded;
      await again.acknowledge('outbox:o1');
      expect(await collect(SyncNotices(db)), isEmpty);
    });

    test('a live refusal reported with its outbox id is not duplicated by the '
        'replay', () async {
      await rejected('o1');
      final notices = SyncNotices(db);
      notices.report(_notice('outbox:o1', reason: SyncNoticeReason.reversed));

      final received = await collect(notices);

      expect(received.where((n) => n.id == 'outbox:o1'), hasLength(1));
    });
  });
}
