import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance/core/di/expense_dependencies.dart';
import 'package:finance/features/expense_control/domain/transaction_history_record.dart';
import 'package:finance/features/expenses/application/transaction_history.dart';

final selectedTransactionHistoryMonthProvider =
    StateProvider.autoDispose<DateTime>((ref) => monthStart(DateTime.now()));

final selectedTransactionHistoryFilterProvider =
    StateProvider.autoDispose<TransactionHistoryFilter>(
      (ref) => const TransactionHistoryFilter.all(),
    );

final transactionHistoryRecordsProvider = StreamProvider.autoDispose
    .family<List<TransactionHistoryRecord>, DateTime>((ref, month) {
      return ref
          .watch(transactionHistoryRepositoryProvider)
          .watchTransactionHistory(
            start: monthStart(month),
            end: nextMonth(month),
          );
    });
