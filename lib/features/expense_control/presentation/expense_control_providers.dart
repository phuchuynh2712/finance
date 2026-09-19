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

/// Screen-scoped pending whole-item edits, staged until "Lưu công thức"
/// commits them (data-model.md — widened from formula-only to cover
/// name/icon/description too, per this feature). `autoDispose` for the
/// full-app-kill case; the *primary* discard mechanism is the explicit
/// `navigationShell.currentIndex` listener in `_AppShell` (app_router.dart).
final pendingItemEditsProvider =
    StateProvider.autoDispose<Map<String, PendingItemEdit>>((ref) => {});

/// Tree (top-level items + children) reflecting persisted data with any
/// pending item edits overlaid live (FR-005/FR-011).
final expenseControlTreeProvider =
    Provider<AsyncValue<List<ExpenseControlNode>>>((ref) {
      final itemsAsync = ref.watch(expenseControlItemsStreamProvider);
      final pending = ref.watch(pendingItemEditsProvider);
      final service = ref.watch(expenseControlPlanServiceProvider);
      return itemsAsync.whenData(
        (items) => service.buildTree(items, pendingEdits: pending),
      );
    });

/// Running allocation summary reflecting persisted data with any pending
/// item edits overlaid live (FR-011).
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
