import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance/core/di/expense_dependencies.dart';
import 'package:finance/features/expenses/application/report_summary.dart';
import 'package:finance/features/expenses/application/transaction_history.dart';
import 'package:finance/features/expenses/presentation/transaction_history_providers.dart';

/// The Báo cáo tab's own selected month — distinct from
/// `selectedTransactionHistoryMonthProvider` so navigating one screen never
/// moves the other (research.md Decision 2). `.autoDispose` here persists
/// across a bottom-nav tab switch rather than resetting on one, since this
/// screen lives inside `StatefulShellRoute.indexedStack`, whose branches
/// stay mounted when hidden — the provider only tears down on a real
/// unmount (sign-out), never a mere tab switch (research.md Decision 3).
final selectedReportMonthProvider = StateProvider.autoDispose<DateTime>(
  (ref) => monthStart(DateTime.now()),
);

/// Depends only on this month's records — a slow/failed breakdown must
/// never delay this (research.md Decision 4).
final reportTotalsProvider = Provider.autoDispose
    .family<AsyncValue<ReportTotals>, DateTime>((ref, month) {
      return ref
          .watch(transactionHistoryRecordsProvider(month))
          .whenData(computeReportTotals);
    });

/// Depends on this month's records **and** the current expense-control
/// tree — the two-input dependency is why this is a separate provider from
/// [reportTotalsProvider], not a shared combined one (research.md
/// Decision 4). `AsyncValue` has no built-in two-source combinator, so the
/// loading/error/data merge is done explicitly below.
final reportBreakdownProvider = Provider.autoDispose
    .family<AsyncValue<List<ReportItemEntry>>, DateTime>((ref, month) {
      final recordsAsync = ref.watch(transactionHistoryRecordsProvider(month));
      final treeAsync = ref.watch(expenseControlTreeProvider);

      if (recordsAsync.hasError) {
        return AsyncValue.error(recordsAsync.error!, recordsAsync.stackTrace!);
      }
      if (treeAsync.hasError) {
        return AsyncValue.error(treeAsync.error!, treeAsync.stackTrace!);
      }
      if (!recordsAsync.hasValue || !treeAsync.hasValue) {
        return const AsyncValue.loading();
      }
      return AsyncValue.data(
        computeReportBreakdown(recordsAsync.value!, treeAsync.value!),
      );
    });
