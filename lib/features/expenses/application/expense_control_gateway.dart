import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance/core/di/expense_dependencies.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_plan_service.dart';
import 'package:finance/features/expense_control/domain/expense_control_repository.dart';

/// Application-facing facade for expense flows that consume expense-control
/// data. Presentation code depends on this contract instead of provider
/// implementation details owned by another feature.
class ExpenseControlGateway {
  const ExpenseControlGateway({
    required this.repository,
    required this.planService,
  });

  final ExpenseControlRepository repository;
  final ExpenseControlPlanService planService;

  Stream<List<ExpenseControlItem>> watchItems() => repository.watchAll();

  Future<List<ExpenseControlItem>> getItems() => repository.getAll();

  List<ExpenseControlNode> buildTree(
    List<ExpenseControlItem> items, {
    Map<String, PendingItemEdit>? pendingEdits,
  }) {
    return planService.buildTree(items, pendingEdits: pendingEdits);
  }

  ExpenseControlTotals computeTotals(
    List<ExpenseControlItem> items, {
    Map<String, PendingItemEdit>? pendingEdits,
  }) {
    return planService.computeTotals(items, pendingEdits: pendingEdits);
  }

  int computeItemBalance(ExpenseControlNode node) {
    return planService.computeItemBalance(node);
  }

  List<ExpenseControlItem> flattenLeaves(List<ExpenseControlNode> tree) {
    return planService.flattenLeaves(tree);
  }

  IncomeAllocationResult computeIncomeAllocation(
    List<ExpenseControlNode> tree,
    int totalIncome,
  ) {
    return planService.computeIncomeAllocation(tree, totalIncome);
  }

  Future<void> applyIncomeAllocation(Map<String, int> deltas) {
    return repository.applyIncomeAllocation(deltas);
  }

  Future<void> recordExpense({required String itemId, required int amount}) {
    return repository.recordExpense(itemId: itemId, amount: amount);
  }
}

final expenseControlGatewayProvider = Provider<ExpenseControlGateway>((ref) {
  return ExpenseControlGateway(
    repository: ref.watch(expenseControlRepositoryProvider),
    planService: ref.watch(expenseControlPlanServiceProvider),
  );
});
