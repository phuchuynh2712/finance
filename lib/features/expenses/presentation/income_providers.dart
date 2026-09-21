import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../expense_control/presentation/expense_control_providers.dart';

/// One transient income source row on "Thu nhập" — never persisted on its
/// own; only the summed total is used for allocation (spec.md Key
/// Entities). `id` is a screen-local identity for list-row operations
/// (add/remove/edit), unrelated to any domain entity id.
class IncomeSourceRow {
  const IncomeSourceRow({required this.id, this.name = '', this.amount});

  final String id;
  final String name;

  /// `null` while the field is empty — distinct from `0`, so an
  /// untouched/blank amount field doesn't read as "explicitly zero."
  final int? amount;

  IncomeSourceRow copyWith({
    String? name,
    int? amount,
    bool clearAmount = false,
  }) {
    return IncomeSourceRow(
      id: id,
      name: name ?? this.name,
      amount: clearAmount ? null : (amount ?? this.amount),
    );
  }
}

/// Which validation problem blocked the last save attempt (FR-004) — kept
/// as a typed reason rather than a pre-formatted string, so the
/// presentation layer picks the localized message via [AppLocalizations].
enum IncomeSaveError {
  invalidTotal,
  missingRowName,
  missingRowAmount,
  writeFailed,
}

class IncomeFormState {
  const IncomeFormState({
    this.rows = const [],
    this.isSubmitting = false,
    this.saveError,
    this.errorRowId,
    this.writeErrorDetail,
    this.saved = false,
  });

  final List<IncomeSourceRow> rows;
  final bool isSubmitting;
  final IncomeSaveError? saveError;

  /// Only set alongside [IncomeSaveError.missingRowName]/
  /// [IncomeSaveError.missingRowAmount] — which row's field the dialog
  /// should point the inline error at.
  final String? errorRowId;

  /// Only set alongside [IncomeSaveError.writeFailed] — the underlying
  /// exception's text, for a generic fallback message.
  final String? writeErrorDetail;
  final bool saved;

  int get totalAmount => rows.fold(0, (sum, row) => sum + (row.amount ?? 0));

  IncomeFormState copyWith({
    List<IncomeSourceRow>? rows,
    bool? isSubmitting,
    IncomeSaveError? saveError,
    String? errorRowId,
    String? writeErrorDetail,
    bool? saved,
    bool clearError = false,
  }) {
    return IncomeFormState(
      rows: rows ?? this.rows,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      saveError: clearError ? null : (saveError ?? this.saveError),
      errorRowId: clearError ? null : (errorRowId ?? this.errorRowId),
      writeErrorDetail: clearError
          ? null
          : (writeErrorDetail ?? this.writeErrorDetail),
      saved: saved ?? this.saved,
    );
  }
}

/// FR-001–FR-004, FR-015: staged income-source rows plus the save action
/// that runs the allocation algorithm and persists its result. Pure
/// screen-local state — no field here is ever read from or written to any
/// repository except via [save]'s single [applyIncomeAllocation] call.
class IncomeFormController extends StateNotifier<IncomeFormState> {
  IncomeFormController({required this.ref, String? initialRowId})
    : super(IncomeFormState(rows: [IncomeSourceRow(id: initialRowId ?? '0')]));

  final Ref ref;
  var _nextRowId = 1;

  void addRow() {
    state = state.copyWith(
      rows: [
        ...state.rows,
        IncomeSourceRow(id: '${_nextRowId++}'),
      ],
      clearError: true,
    );
  }

  void removeRow(String rowId) {
    state = state.copyWith(
      rows: state.rows.where((row) => row.id != rowId).toList(),
      clearError: true,
    );
  }

  void setRowName(String rowId, String name) {
    state = state.copyWith(
      rows: [
        for (final row in state.rows)
          if (row.id == rowId) row.copyWith(name: name) else row,
      ],
      clearError: true,
    );
  }

  void setRowAmount(String rowId, int? amount) {
    state = state.copyWith(
      rows: [
        for (final row in state.rows)
          if (row.id == rowId)
            amount == null
                ? row.copyWith(clearAmount: true)
                : row.copyWith(amount: amount)
          else
            row,
      ],
      clearError: true,
    );
  }

  /// FR-004: the id of the first row missing a name, if any — drives both
  /// [canSave] and the inline error the dialog points at that specific row.
  String? get _rowMissingName {
    for (final row in state.rows) {
      if (row.name.trim().isEmpty) return row.id;
    }
    return null;
  }

  bool get canSave =>
      state.totalAmount > 0 &&
      state.rows.every(
        (row) => row.name.trim().isNotEmpty && (row.amount ?? 0) > 0,
      );

  String? get _rowMissingAmount {
    for (final row in state.rows) {
      if (row.name.trim().isNotEmpty && (row.amount ?? 0) <= 0) return row.id;
    }
    return null;
  }

  Future<void> save() async {
    if (!canSave) {
      final missingName = _rowMissingName;
      final missingAmount = _rowMissingAmount;
      if (missingName != null) {
        state = state.copyWith(
          saveError: IncomeSaveError.missingRowName,
          errorRowId: missingName,
        );
      } else if (missingAmount != null) {
        state = state.copyWith(
          saveError: IncomeSaveError.missingRowAmount,
          errorRowId: missingAmount,
        );
      } else {
        state = state.copyWith(saveError: IncomeSaveError.invalidTotal);
      }
      return;
    }
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final planService = ref.read(expenseControlPlanServiceProvider);
      final items =
          ref.read(expenseControlItemsStreamProvider).valueOrNull ?? [];
      final tree = planService.buildTree(items);
      final result = planService.computeIncomeAllocation(
        tree,
        state.totalAmount,
      );
      await ref
          .read(expenseControlRepositoryProvider)
          .applyIncomeAllocation(result.deltas);
      state = state.copyWith(saved: true, isSubmitting: false);
    } catch (e) {
      state = state.copyWith(
        saveError: IncomeSaveError.writeFailed,
        writeErrorDetail: e.toString(),
        isSubmitting: false,
      );
    }
  }
}

final incomeFormControllerProvider =
    StateNotifierProvider.autoDispose<IncomeFormController, IncomeFormState>(
      (ref) => IncomeFormController(ref: ref),
    );
