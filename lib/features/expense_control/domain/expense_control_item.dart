/// Domain-layer allocation mode — deliberately re-declared here rather than
/// imported from `core/database/tables/expense_control_items_table.dart`
/// (which uses the same name), since `domain/` must have zero dependency on
/// Drift/Flutter (Constitution Recommended Architecture). Mirrors the
/// existing `Envelope`/`Envelopes` table split (research.md §5b).
enum ExpenseAllocationMethod { percentage, fixed }

/// A single planned expense the user wants to keep under control — either a
/// leaf (carries [allocationMethod]/[allocationValue]) or a group (both
/// null, [parentId] is `null`, and it has one or more children referencing
/// it) — spec.md Key Entities.
class ExpenseControlItem {
  const ExpenseControlItem({
    required this.id,
    required this.userId,
    required this.parentId,
    required this.name,
    required this.iconKey,
    required this.description,
    required this.sortOrder,
    required this.allocationMethod,
    required this.allocationValue,
  });

  final String id;
  final String userId;
  final String? parentId;
  final String name;
  final String iconKey;
  final String? description;
  final int sortOrder;
  final ExpenseAllocationMethod? allocationMethod;
  final double? allocationValue;

  bool get isTopLevel => parentId == null;

  ExpenseControlItem copyWith({
    String? name,
    String? iconKey,
    String? description,
    int? sortOrder,
    ExpenseAllocationMethod? allocationMethod,
    double? allocationValue,
  }) {
    return ExpenseControlItem(
      id: id,
      userId: userId,
      parentId: parentId,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      allocationMethod: allocationMethod ?? this.allocationMethod,
      allocationValue: allocationValue ?? this.allocationValue,
    );
  }

  /// Returns a copy with the formula cleared — used when this item gains
  /// its first child and stops being a leaf (FR-004).
  ExpenseControlItem clearFormula() {
    return ExpenseControlItem(
      id: id,
      userId: userId,
      parentId: parentId,
      name: name,
      iconKey: iconKey,
      description: description,
      sortOrder: sortOrder,
      allocationMethod: null,
      allocationValue: null,
    );
  }
}

/// A pending formula edit staged in presentation state until "Lưu công thức"
/// commits it (research.md §9, data-model.md).
class ExpenseFormulaEdit {
  const ExpenseFormulaEdit({required this.method, required this.value});

  final ExpenseAllocationMethod method;
  final double value;
}
