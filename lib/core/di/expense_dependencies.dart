import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/database/app_database_provider.dart';
import 'package:finance/features/expense_control/data/expense_control_repository_impl.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_plan_service.dart';
import 'package:finance/features/expense_control/domain/expense_control_repository.dart';

final expenseControlRepositoryProvider = Provider<ExpenseControlRepository>((
  ref,
) {
  return ExpenseControlRepositoryImpl(
    ref.watch(appDatabaseProvider),
    userId: ref.watch(currentUserIdProvider),
  );
});

final expenseControlPlanServiceProvider = Provider<ExpenseControlPlanService>(
  (ref) => const ExpenseControlPlanService(),
);

final expenseControlItemsStreamProvider =
    StreamProvider<List<ExpenseControlItem>>((ref) {
      return ref.watch(expenseControlRepositoryProvider).watchAll();
    });

final pendingItemEditsProvider =
    StateProvider.autoDispose<Map<String, PendingItemEdit>>((ref) => {});

final expenseControlTreeProvider =
    Provider<AsyncValue<List<ExpenseControlNode>>>((ref) {
      final itemsAsync = ref.watch(expenseControlItemsStreamProvider);
      final pending = ref.watch(pendingItemEditsProvider);
      final service = ref.watch(expenseControlPlanServiceProvider);
      return itemsAsync.whenData(
        (items) => service.buildTree(items, pendingEdits: pending),
      );
    });

final expenseControlTotalsProvider = Provider<AsyncValue<ExpenseControlTotals>>(
  (ref) {
    final itemsAsync = ref.watch(expenseControlItemsStreamProvider);
    final pending = ref.watch(pendingItemEditsProvider);
    final service = ref.watch(expenseControlPlanServiceProvider);
    return itemsAsync.whenData(
      (items) => service.computeTotals(items, pendingEdits: pending),
    );
  },
);
