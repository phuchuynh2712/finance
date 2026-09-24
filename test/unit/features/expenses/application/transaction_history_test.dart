import 'package:flutter_test/flutter_test.dart';

import 'package:finance/features/expense_control/domain/transaction_history_record.dart';
import 'package:finance/features/expenses/application/transaction_history.dart';

void main() {
  test(
    'builds newest date groups and excludes income from monthly expenses',
    () {
      final view = buildTransactionHistoryView(
        records: [
          _record(
            'income',
            TransactionHistoryDirection.income,
            300,
            DateTime(2026, 6, 2),
          ),
          _record(
            'older',
            TransactionHistoryDirection.expense,
            100,
            DateTime(2026, 6, 1),
          ),
          _record(
            'newer',
            TransactionHistoryDirection.expense,
            200,
            DateTime(2026, 6, 2),
          ),
        ],
        filter: const TransactionHistoryFilter.all(),
      );

      expect(view.expenseTotal, 300);
      expect(view.groups.map((group) => group.date.day), [2, 1]);
      expect(view.groups.first.items.map((item) => item.id), [
        'income',
        'newer',
      ]);
    },
  );

  test('filters by snapshot group and retains deleted-group values', () {
    final view = buildTransactionHistoryView(
      records: [
        _record(
          'food',
          TransactionHistoryDirection.expense,
          100,
          DateTime(2026, 6, 2),
          group: 'Food',
        ),
        _record(
          'travel',
          TransactionHistoryDirection.expense,
          200,
          DateTime(2026, 6, 1),
          group: 'Archived travel',
        ),
        _record(
          'income',
          TransactionHistoryDirection.income,
          500,
          DateTime(2026, 6, 1),
        ),
      ],
      filter: const TransactionHistoryFilter.group('Archived travel'),
    );

    expect(view.groupFilters, ['Archived travel', 'Food']);
    expect(view.groups.single.items.single.id, 'travel');
  });

  test('filters income and prevents advancing beyond the current month', () {
    final view = buildTransactionHistoryView(
      records: [
        _record(
          'expense',
          TransactionHistoryDirection.expense,
          100,
          DateTime(2026, 6, 2),
        ),
        _record(
          'income',
          TransactionHistoryDirection.income,
          500,
          DateTime(2026, 6, 1),
        ),
      ],
      filter: const TransactionHistoryFilter.income(),
    );

    expect(view.groups.single.items.single.id, 'income');
    expect(canAdvanceMonth(DateTime(2026, 9), DateTime(2026, 9, 24)), isFalse);
    expect(canAdvanceMonth(DateTime(2026, 8), DateTime(2026, 9, 24)), isTrue);
  });
}

TransactionHistoryRecord _record(
  String id,
  TransactionHistoryDirection direction,
  int amount,
  DateTime occurredAt, {
  String? group,
}) {
  return TransactionHistoryRecord(
    id: id,
    sourceItemId: id,
    direction: direction,
    amount: amount,
    occurredAt: occurredAt,
    displayName: id,
    displayGroupName: group,
    displayIconKey: 'home',
  );
}
