import 'package:flutter_test/flutter_test.dart';

import 'package:finance/features/expense_control/domain/transaction_history_record.dart';
import 'package:finance/features/expenses/application/overview_recent_transactions.dart';

TransactionHistoryRecord _record({
  required String id,
  required DateTime occurredAt,
  TransactionHistoryDirection direction = TransactionHistoryDirection.expense,
  String displayName = 'Item',
  String? displayGroupName = 'Group',
  int amount = 1000,
}) {
  return TransactionHistoryRecord(
    id: id,
    sourceItemId: 'src',
    direction: direction,
    amount: amount,
    occurredAt: occurredAt,
    displayName: displayName,
    displayGroupName: displayGroupName,
    displayIconKey: 'home',
  );
}

void main() {
  final now = DateTime(2026, 6, 15, 10);

  group('relative-day bucketing', () {
    test('same calendar date as now is today', () {
      final record = _record(id: 'a', occurredAt: DateTime(2026, 6, 15, 2));

      final items = buildOverviewRecentItems([record], now: now);

      expect(items.single.relativeDay, const OverviewRelativeDay.today());
    });

    test('one calendar day before now is yesterday', () {
      final record = _record(id: 'a', occurredAt: DateTime(2026, 6, 14, 23));

      final items = buildOverviewRecentItems([record], now: now);

      expect(items.single.relativeDay, const OverviewRelativeDay.yesterday());
    });

    test('two or more calendar days before now is daysAgo(n)', () {
      final record = _record(id: 'a', occurredAt: DateTime(2026, 6, 12));

      final items = buildOverviewRecentItems([record], now: now);

      expect(items.single.relativeDay, const OverviewRelativeDay.daysAgo(3));
    });

    test(
      'bucketing uses calendar dates, not 24h windows — 11pm yesterday vs 1am today',
      () {
        final justAfterMidnight = _record(
          id: 'a',
          occurredAt: DateTime(2026, 6, 15, 0, 30),
        );

        final items = buildOverviewRecentItems([
          justAfterMidnight,
        ], now: DateTime(2026, 6, 15, 23, 59));

        expect(items.single.relativeDay, const OverviewRelativeDay.today());
      },
    );
  });

  test('passes through id, displayName, groupLabel, direction, and amount', () {
    final record = _record(
      id: 't1',
      occurredAt: now,
      direction: TransactionHistoryDirection.income,
      displayName: 'Lương tháng 6',
      displayGroupName: 'Thu nhập',
      amount: 25000000,
    );

    final items = buildOverviewRecentItems([record], now: now);

    final item = items.single;
    expect(item.id, 't1');
    expect(item.displayName, 'Lương tháng 6');
    expect(item.groupLabel, 'Thu nhập');
    expect(item.direction, TransactionHistoryDirection.income);
    expect(item.amount, 25000000);
  });

  test('preserves the input order rather than re-sorting', () {
    final records = [
      _record(id: 'first', occurredAt: DateTime(2026, 6, 15)),
      _record(id: 'second', occurredAt: DateTime(2026, 6, 1)),
    ];

    final items = buildOverviewRecentItems(records, now: now);

    expect(items.map((i) => i.id), ['first', 'second']);
  });

  test('an empty input list yields an empty output list', () {
    expect(buildOverviewRecentItems(const [], now: now), isEmpty);
  });
}
