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
    required this.balance,
    required this.isSavingsReceiver,
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

  /// Actual current balance (VND, whole units) for a leaf item. Meaningless
  /// for a group — never read from a group's own row, only from the live
  /// sum of its children (data-model.md). Defaults to 0; only ever written
  /// by a future income/expense-recording feature, never by this one.
  final int balance;

  /// Marks this leaf as the sole recipient of any income left over after
  /// every item's formula has been applied (data-model.md). Meaningless for
  /// a group — MUST be `false` for any item with children, enforced by
  /// [clearFormula] the moment a first child is added. At most one item per
  /// user may have this `true` at any time, enforced at the application
  /// layer only (spec.md Clarifications) — not a database constraint.
  final bool isSavingsReceiver;

  bool get isTopLevel => parentId == null;

  ExpenseControlItem copyWith({
    String? name,
    String? iconKey,
    String? description,
    int? sortOrder,
    ExpenseAllocationMethod? allocationMethod,
    double? allocationValue,
    int? balance,
    bool? isSavingsReceiver,
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
      balance: balance ?? this.balance,
      isSavingsReceiver: isSavingsReceiver ?? this.isSavingsReceiver,
    );
  }

  /// Returns a copy with the formula cleared — used when this item gains
  /// its first child and stops being a leaf (FR-004). `balance` is
  /// preserved unchanged (data-model.md). `isSavingsReceiver` is reset to
  /// `false` — a group can never hold this mark (FR-011).
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
      balance: balance,
      isSavingsReceiver: false,
    );
  }
}

/// A pending whole-item edit staged in presentation state until "Lưu công
/// thức" commits it (data-model.md, replacing the narrower formula-only
/// `ExpenseFormulaEdit`). Every field is nullable, meaning "unchanged from
/// the last-committed item" — not "changed to null." At least one field is
/// expected to be non-null whenever an entry exists in the pending map (the
/// dialog only ever stages something the user actually changed).
///
/// `description`'s "unchanged" vs. "cleared to empty" states are not
/// distinguished (plain `String?`, not a tri-state wrapper): the dialog's
/// `TextField` produces the same value either way, and the spec does not
/// call out clearing an existing description as a scenario needing separate
/// handling (data-model.md's Open Question, resolved here as: not needed).
class PendingItemEdit {
  const PendingItemEdit({
    this.name,
    this.iconKey,
    this.description,
    this.method,
    this.value,
    this.isSavingsReceiver,
  });

  final String? name;
  final String? iconKey;
  final String? description;
  final ExpenseAllocationMethod? method;
  final double? value;

  /// `null` means "leave unchanged," matching every other field here — see
  /// [ExpenseControlItem.isSavingsReceiver] for what the flag itself means.
  final bool? isSavingsReceiver;
}
