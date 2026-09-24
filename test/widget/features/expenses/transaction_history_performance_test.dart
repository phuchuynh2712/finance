import 'package:flutter_test/flutter_test.dart';

import 'package:finance/features/expense_control/domain/transaction_history_record.dart';
import 'package:finance/features/expenses/application/transaction_history.dart';

void main() {
  test('filters 100 selected-month rows within one second', () {
    final records = List.generate(
      100,
      (index) => TransactionHistoryRecord(
        id: '$index',
        sourceItemId: '$index',
        direction: index.isEven
            ? TransactionHistoryDirection.expense
            : TransactionHistoryDirection.income,
        amount: index + 1,
        occurredAt: DateTime(2026, 6, 1, 12, index % 60),
        displayName: 'Transaction $index',
        displayGroupName: index.isEven ? 'Food' : null,
        displayIconKey: 'home',
      ),
    );
    final stopwatch = Stopwatch()..start();
    final view = buildTransactionHistoryView(
      records: records,
      filter: const TransactionHistoryFilter.group('Food'),
    );
    stopwatch.stop();

    expect(view.groups.single.items, hasLength(50));
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
  });
}
