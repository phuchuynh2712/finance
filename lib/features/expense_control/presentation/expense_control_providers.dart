import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_state_provider.dart';
import '../../../core/database/app_database_provider.dart';
import '../data/expense_control_repository_impl.dart';
import '../domain/expense_control_item.dart';
import '../domain/expense_control_plan_service.dart';
import '../domain/expense_control_repository.dart';

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

/// Reactive flat list of the current user's expense control items.
final expenseControlItemsStreamProvider =
    StreamProvider<List<ExpenseControlItem>>((ref) {
      return ref.watch(expenseControlRepositoryProvider).watchAll();
    });

/// Screen-scoped pending formula edits, staged until "Lưu công thức" commits
/// them (research.md §9). `autoDispose` for the full-app-kill case; the
/// *primary* discard mechanism is the explicit `navigationShell.currentIndex`
/// listener in `_AppShell` (app_router.dart).
final pendingFormulaEditsProvider =
    StateProvider.autoDispose<Map<String, ExpenseFormulaEdit>>((ref) => {});

/// Tree (top-level items + children) reflecting persisted data with any
/// pending formula edits overlaid live (FR-011).
final expenseControlTreeProvider = Provider<AsyncValue<List<ExpenseControlNode>>>((
  ref,
) {
  final itemsAsync = ref.watch(expenseControlItemsStreamProvider);
  final pending = ref.watch(pendingFormulaEditsProvider);
  final service = ref.watch(expenseControlPlanServiceProvider);
  return itemsAsync.whenData(
    (items) => service.buildTree(items, pendingEdits: pending),
  );
});

/// Running allocation summary reflecting persisted data with any pending
/// formula edits overlaid live (FR-011).
final expenseControlTotalsProvider = Provider<AsyncValue<ExpenseControlTotals>>((
  ref,
) {
  final itemsAsync = ref.watch(expenseControlItemsStreamProvider);
  final pending = ref.watch(pendingFormulaEditsProvider);
  final service = ref.watch(expenseControlPlanServiceProvider);
  return itemsAsync.whenData(
    (items) => service.computeTotals(items, pendingEdits: pending),
  );
});
