import 'transaction_history_record.dart';

abstract interface class TransactionHistoryRepository {
  Stream<List<TransactionHistoryRecord>> watchTransactionHistory({
    required DateTime start,
    required DateTime end,
  });

  /// Most recent [limit] non-deleted records for the current user across all
  /// accounts, newest first, independent of any calendar-month boundary.
  Stream<List<TransactionHistoryRecord>> watchRecent({required int limit});
}
