import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_plan_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance/features/expenses/application/expense_control_gateway.dart';

/// Application commands for financial writes. Presentation controllers keep
/// transient form state, while this service owns domain orchestration and I/O.
class TransactionCommandService {
  const TransactionCommandService(this._gateway);

  final ExpenseControlGateway _gateway;

  List<ExpenseControlItem> flattenLeaves(List<ExpenseControlNode> tree) {
    return _gateway.flattenLeaves(tree);
  }

  IncomeAllocationResult allocateIncome(
    List<ExpenseControlNode> tree,
    int totalIncome,
  ) {
    return _gateway.computeIncomeAllocation(tree, totalIncome);
  }

  Future<void> recordExpense({required String itemId, required int amount}) {
    return _gateway.recordExpense(itemId: itemId, amount: amount);
  }

  Future<void> applyIncomeAllocation(Map<String, int> deltas) {
    return _gateway.applyIncomeAllocation(deltas);
  }
}

final transactionCommandServiceProvider = Provider<TransactionCommandService>((
  ref,
) {
  return TransactionCommandService(ref.watch(expenseControlGatewayProvider));
});
