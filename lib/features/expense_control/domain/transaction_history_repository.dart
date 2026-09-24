import 'transaction_history_record.dart';

abstract interface class TransactionHistoryRepository {
  Stream<List<TransactionHistoryRecord>> watchTransactionHistory({
    required DateTime start,
    required DateTime end,
  });
}
