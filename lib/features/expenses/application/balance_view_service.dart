import 'package:finance/core/di/expense_dependencies.dart';
import 'package:finance/features/expense_control/domain/expense_control_plan_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Prepares read-only balance rows for the spending presentation.
class BalanceViewService {
  const BalanceViewService(this._planService);

  final ExpenseControlPlanService _planService;

  List<BalanceViewItem> prepare(List<ExpenseControlNode> tree) {
    return [
      for (final node in tree)
        BalanceViewItem(
          node: node,
          balance: _planService.computeItemBalance(node),
        ),
    ];
  }
}

final balanceViewServiceProvider = Provider<BalanceViewService>((ref) {
  return BalanceViewService(ref.watch(expenseControlPlanServiceProvider));
});

class BalanceViewItem {
  const BalanceViewItem({required this.node, required this.balance});

  final ExpenseControlNode node;
  final int balance;
}
