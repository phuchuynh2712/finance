import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance/core/auth/auth_repository.dart';
import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/di/expense_dependencies.dart';
import 'package:finance/features/expense_control/domain/transaction_history_record.dart';
import 'package:finance/features/expenses/application/overview_summary_service.dart';

/// Fixed ceiling for Overview's recent-activity list (spec.md Assumptions).
const overviewRecentTransactionsLimit = 5;

/// Narrows the core-level `authRepositoryProvider` (concrete `AuthRepository`,
/// which needs a real `SupabaseClient` to construct) to the interface
/// `AccountAuthActions` so it can be faked in tests — the same narrowing
/// pattern `account/presentation/account_controller.dart`'s own
/// `accountAuthActionsProvider` uses, declared here instead so `expenses/`
/// never imports another feature's presentation layer
/// (architecture_boundary_test.dart; research.md Decision 6).
final overviewAuthActionsProvider = Provider<AccountAuthActions>((ref) {
  return ref.watch(authRepositoryProvider);
});

final overviewSummaryServiceProvider = Provider<OverviewSummaryService>((ref) {
  return OverviewSummaryService(ref.watch(expenseControlPlanServiceProvider));
});

/// Backs both the total-balance card and the accounts list — one shared
/// source, so the two can never disagree (data-model.md's invariant).
final overviewSummaryProvider = Provider<AsyncValue<OverviewSummary>>((ref) {
  final treeAsync = ref.watch(expenseControlTreeProvider);
  final service = ref.watch(overviewSummaryServiceProvider);
  return treeAsync.whenData(service.buildSummary);
});

/// Separate, independent source from [overviewSummaryProvider] — a failure
/// or delay here must not block the balance/accounts render, and vice versa
/// (FR-010).
final overviewRecentTransactionsProvider =
    StreamProvider<List<TransactionHistoryRecord>>((ref) {
      return ref
          .watch(transactionHistoryRepositoryProvider)
          .watchRecent(limit: overviewRecentTransactionsLimit);
    });
