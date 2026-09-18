import 'expense_control_item.dart';

/// Presentation-facing tree shape: a top-level item paired with its direct
/// children (data-model.md).
class ExpenseControlNode {
  const ExpenseControlNode({required this.item, required this.children});

  final ExpenseControlItem item;
  final List<ExpenseControlItem> children;

  bool get isGroup => children.isNotEmpty;
}

/// FR-011: the plan's running allocation summary.
class ExpenseControlTotals {
  const ExpenseControlTotals({
    required this.percentAllocated,
    required this.fixedItemCount,
    required this.percentFree,
  });

  final double percentAllocated;
  final int fixedItemCount;
  final double percentFree;
}

/// Result of validating a candidate plan against FR-007/FR-008 (FR-012:
/// block-before-persist).
class ExpenseControlValidation {
  const ExpenseControlValidation({required this.isValid, this.violatingTotal});

  final bool isValid;

  /// The percentage total that would be violated, when [isValid] is false.
  final double? violatingTotal;
}

/// Pure Dart — no Flutter/Drift imports (Constitution Recommended
/// Architecture). Owns tree-building, totals, percentage-budget validation
/// (FR-007/FR-008/FR-012), and the one-level nesting cap (FR-002).
///
/// Every method accepts an optional [pendingEdits] overlay so US3's inline
/// formula editing can compute against not-yet-persisted state without
/// writing to the DB on every keystroke (research.md §9).
class ExpenseControlPlanService {
  const ExpenseControlPlanService();

  List<ExpenseControlItem> _applyOverlay(
    List<ExpenseControlItem> items,
    Map<String, PendingItemEdit>? pendingEdits,
  ) {
    if (pendingEdits == null || pendingEdits.isEmpty) return items;
    return items.map((item) {
      final edit = pendingEdits[item.id];
      if (edit == null) return item;
      // FR-005: every staged field, not just the formula, must be visible
      // wherever the tree is read — copyWith's `??` already leaves a null
      // field's committed value untouched, so this naturally covers "some
      // fields changed, others didn't" per PendingItemEdit's own contract.
      return item.copyWith(
        name: edit.name,
        iconKey: edit.iconKey,
        description: edit.description,
        allocationMethod: edit.method,
        allocationValue: edit.value,
      );
    }).toList();
  }

  /// Leaves = top-level items with zero children, plus every child item
  /// (children are always leaves, one-level nesting cap — FR-002/FR-003).
  List<ExpenseControlItem> _leaves(List<ExpenseControlItem> items) {
    final parentIds = <String>{
      for (final item in items)
        if (item.parentId != null) item.parentId!,
    };
    return items
        .where((item) => item.parentId != null || !parentIds.contains(item.id))
        .toList();
  }

  /// Builds the top-level + children tree from a flat list (FR-002/FR-003).
  List<ExpenseControlNode> buildTree(
    List<ExpenseControlItem> items, {
    Map<String, PendingItemEdit>? pendingEdits,
  }) {
    final merged = _applyOverlay(items, pendingEdits);
    final topLevel = merged.where((item) => item.parentId == null).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final childrenByParent = <String, List<ExpenseControlItem>>{};
    for (final item in merged) {
      final parentId = item.parentId;
      if (parentId != null) {
        (childrenByParent[parentId] ??= []).add(item);
      }
    }
    for (final children in childrenByParent.values) {
      children.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    return [
      for (final item in topLevel)
        ExpenseControlNode(
          item: item,
          children: childrenByParent[item.id] ?? const [],
        ),
    ];
  }

  /// FR-011: percent allocated, fixed-item count, percent free — computed
  /// across every leaf, regardless of nesting; a group's own (null)
  /// formula never contributes (FR-003/FR-004).
  ExpenseControlTotals computeTotals(
    List<ExpenseControlItem> items, {
    Map<String, PendingItemEdit>? pendingEdits,
  }) {
    final leaves = _leaves(_applyOverlay(items, pendingEdits));
    var percentSum = 0.0;
    var fixedCount = 0;
    for (final leaf in leaves) {
      switch (leaf.allocationMethod) {
        case ExpenseAllocationMethod.percentage:
          percentSum += leaf.allocationValue ?? 0;
        case ExpenseAllocationMethod.fixed:
          fixedCount++;
        case null:
          break;
      }
    }
    return ExpenseControlTotals(
      percentAllocated: percentSum,
      fixedItemCount: fixedCount,
      percentFree: 100 - percentSum,
    );
  }

  /// FR-007 (sum ≤ 100%) and FR-008 (strictly < 100% when any fixed item
  /// exists anywhere in the plan) — evaluated against [items] with
  /// [pendingEdits] merged in, so this can validate a create/edit/batch
  /// candidate before it's persisted (FR-012).
  ExpenseControlValidation validateBudget(
    List<ExpenseControlItem> items, {
    Map<String, PendingItemEdit>? pendingEdits,
  }) {
    final merged = _applyOverlay(items, pendingEdits);
    final leaves = _leaves(merged);
    final totals = computeTotals(items, pendingEdits: pendingEdits);
    final hasFixed = leaves.any(
      (leaf) => leaf.allocationMethod == ExpenseAllocationMethod.fixed,
    );
    final isValid = hasFixed
        ? totals.percentAllocated < 100
        : totals.percentAllocated <= 100;
    return ExpenseControlValidation(
      isValid: isValid,
      violatingTotal: isValid ? null : totals.percentAllocated,
    );
  }

  /// FR-002: a row that is itself a child (non-null `parentId`) MUST NOT be
  /// used as another row's `parentId` — nesting is capped at one level.
  bool isNestingAllowed(
    List<ExpenseControlItem> items,
    String candidateParentId,
  ) {
    for (final item in items) {
      if (item.id == candidateParentId) return item.parentId == null;
    }
    return true;
  }
}
