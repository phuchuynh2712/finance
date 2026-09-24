import 'package:finance/features/expense_control/domain/expense_control_plan_service.dart';

/// Read-only projection of one top-level account, for the Overview accounts
/// list (data-model.md).
class OverviewAccountSummary {
  const OverviewAccountSummary({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.balance,
  });

  final String id;
  final String name;
  final String iconKey;
  final int balance;

  bool get isNegative => balance < 0;
}

/// The single derived object backing the Overview total-balance card and
/// negative-balance warning (data-model.md). `totalBalance` is always the
/// fold of `accounts`, by construction, so the two can never disagree.
class OverviewSummary {
  const OverviewSummary({required this.totalBalance, required this.accounts});

  final int totalBalance;
  final List<OverviewAccountSummary> accounts;

  List<OverviewAccountSummary> get negativeAccounts =>
      accounts.where((a) => a.isNegative).toList();
}

/// Builds [OverviewSummary] from the same root-node tree
/// `expenseControlTreeProvider` already exposes, reusing
/// [ExpenseControlPlanService.computeItemBalance] per root so a group's
/// balance is the live sum of its children — the same rule
/// `BalanceViewService` already applies for the per-account cards
/// (research.md Decision 2).
class OverviewSummaryService {
  const OverviewSummaryService(this._planService);

  final ExpenseControlPlanService _planService;

  OverviewSummary buildSummary(List<ExpenseControlNode> tree) {
    final accounts = [
      for (final node in tree)
        OverviewAccountSummary(
          id: node.item.id,
          name: node.item.name,
          iconKey: node.item.iconKey,
          balance: _planService.computeItemBalance(node),
        ),
    ];
    return OverviewSummary(
      totalBalance: accounts.fold(0, (sum, a) => sum + a.balance),
      accounts: accounts,
    );
  }
}
