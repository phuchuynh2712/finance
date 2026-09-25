import 'package:finance/features/expense_control/domain/expense_control_plan_service.dart';
import 'package:finance/features/expense_control/domain/transaction_history_record.dart';

/// FR-007–FR-010: this month's income/expense totals, folded once over an
/// already month-filtered [TransactionHistoryRecord] list (no further date
/// filtering happens here — that's `transactionHistoryRecordsProvider`'s
/// job, per research.md Decision 1).
class ReportTotals {
  const ReportTotals({required this.totalIncome, required this.totalExpense});

  final int totalIncome;
  final int totalExpense;
}

ReportTotals computeReportTotals(List<TransactionHistoryRecord> records) {
  var totalIncome = 0;
  var totalExpense = 0;
  for (final record in records) {
    switch (record.direction) {
      case TransactionHistoryDirection.income:
        totalIncome += record.amount;
      case TransactionHistoryDirection.expense:
        totalExpense += record.amount;
    }
  }
  return ReportTotals(totalIncome: totalIncome, totalExpense: totalExpense);
}

/// data-model.md's three per-item display states — mutually exclusive and
/// exhaustive given [ReportItemEntry]'s list-membership rule (an item with
/// neither allocation nor spend never becomes an entry at all).
enum ReportItemUsageState { notAllocated, unused, tracked }

/// FR-011–FR-014: one row of the per-item breakdown, scoped to the same
/// selected month as [ReportTotals] — `spent`/`allocated` are both sums of
/// that month's own records only, deliberately excluding any balance
/// carried over from an earlier month (research.md Decision 5).
class ReportItemEntry {
  const ReportItemEntry({
    required this.itemId,
    required this.name,
    required this.groupName,
    required this.spent,
    required this.allocated,
  });

  final String itemId;
  final String name;
  final String? groupName;
  final int spent;
  final int allocated;

  ReportItemUsageState get usageState {
    if (allocated == 0) return ReportItemUsageState.notAllocated;
    if (spent == 0) return ReportItemUsageState.unused;
    return ReportItemUsageState.tracked;
  }

  /// `null` when [allocated] is zero — a percentage would be undefined
  /// (FR-014). Uncapped otherwise; a `tracked` row's presentation caps only
  /// the *bar fill*, not this value (research.md Decision 7).
  double? get usagePercent => allocated == 0 ? null : spent / allocated * 100;
}

/// FR-011: groups [records] by `sourceItemId`, keeping only items with at
/// least one income or expense record this month; resolves each item's
/// current name/group from [tree] when it still exists there, falling back
/// to the record's own snapshotted name for a since-removed item
/// (data-model.md, spec.md Assumptions). Sorted by `spent` descending
/// (research.md Decision 13).
List<ReportItemEntry> computeReportBreakdown(
  List<TransactionHistoryRecord> records,
  List<ExpenseControlNode> tree,
) {
  final spentByItem = <String, int>{};
  final allocatedByItem = <String, int>{};
  final fallbackNameByItem = <String, String>{};

  for (final record in records) {
    final itemId = record.sourceItemId;
    fallbackNameByItem[itemId] = record.displayName;
    switch (record.direction) {
      case TransactionHistoryDirection.expense:
        spentByItem[itemId] = (spentByItem[itemId] ?? 0) + record.amount;
      case TransactionHistoryDirection.income:
        allocatedByItem[itemId] =
            (allocatedByItem[itemId] ?? 0) + record.amount;
    }
  }

  final planService = const ExpenseControlPlanService();
  final liveItemsById = {
    for (final node in tree) node.item.id: node.item,
    for (final node in tree)
      for (final child in node.children) child.id: child,
  };

  final itemIds = {...spentByItem.keys, ...allocatedByItem.keys};
  final entries = [
    for (final itemId in itemIds)
      ReportItemEntry(
        itemId: itemId,
        name: liveItemsById[itemId]?.name ?? fallbackNameByItem[itemId]!,
        groupName: liveItemsById.containsKey(itemId)
            ? planService.groupNameFor(tree, itemId)
            : null,
        spent: spentByItem[itemId] ?? 0,
        allocated: allocatedByItem[itemId] ?? 0,
      ),
  ]..sort((a, b) => b.spent.compareTo(a.spent));

  return entries;
}
