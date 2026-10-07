import 'package:finance/features/expense_control/domain/transaction_history_record.dart';
import 'package:finance/features/expense_control/domain/transaction_history_repository.dart';

/// A fake history repository (a public copy of the private fakes in the
/// overview, report and history tests) serving the same list for any range.
class FakeHistoryRepository implements TransactionHistoryRepository {
  const FakeHistoryRepository([this.records = const []]);

  final List<TransactionHistoryRecord> records;

  @override
  Stream<List<TransactionHistoryRecord>> watchTransactionHistory({
    required DateTime start,
    required DateTime end,
  }) => Stream.value(records);

  @override
  Stream<List<TransactionHistoryRecord>> watchRecent({required int limit}) =>
      Stream.value(records.take(limit).toList());
}

/// [count] transactions spread over the current month, alternating expense and
/// income, spread over a few accounts of a shared group `Nhóm`.
List<TransactionHistoryRecord> sampleHistory({int count = 24}) {
  final now = DateTime.now();
  return [
    for (var i = 0; i < count; i++)
      TransactionHistoryRecord(
        id: 't$i',
        sourceItemId: 'a${i % 4 + 1}',
        direction: i.isEven
            ? TransactionHistoryDirection.expense
            : TransactionHistoryDirection.income,
        amount: 50000 * (i + 1),
        occurredAt: DateTime(now.year, now.month, 1, 8 + i % 12, i),
        displayName: 'Ví ${i % 4 + 1}',
        displayGroupName: 'Nhóm',
        displayIconKey: 'home',
      ),
  ];
}
