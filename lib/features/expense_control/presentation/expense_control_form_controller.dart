import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/auth/auth_state_provider.dart';
import '../domain/expense_control_item.dart';
import '../domain/expense_control_plan_service.dart';
import '../domain/expense_control_repository.dart';
import 'expense_control_providers.dart';

class ExpenseControlFormState {
  const ExpenseControlFormState({
    this.name = '',
    this.iconKey = 'home',
    this.description,
    this.method = ExpenseAllocationMethod.percentage,
    this.value,
    this.isSubmitting = false,
    this.errorMessage,
    this.saved = false,
    this.nameTouched = false,
    this.valueTouched = false,
  });

  final String name;
  final String iconKey;
  final String? description;
  final ExpenseAllocationMethod method;
  final double? value;
  final bool isSubmitting;
  final String? errorMessage;
  final bool saved;

  /// Whether the user has interacted with the name/value field yet — an
  /// untouched required field shouldn't show its "required" error the
  /// instant the dialog opens, only once the user has had a chance to fill
  /// it in (or tried to save without doing so).
  final bool nameTouched;
  final bool valueTouched;

  ExpenseControlFormState copyWith({
    String? name,
    String? iconKey,
    String? description,
    ExpenseAllocationMethod? method,
    double? value,
    bool? isSubmitting,
    String? errorMessage,
    bool? saved,
    bool? nameTouched,
    bool? valueTouched,
    bool clearErrorMessage = false,
  }) {
    return ExpenseControlFormState(
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      description: description ?? this.description,
      method: method ?? this.method,
      value: value ?? this.value,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      saved: saved ?? this.saved,
      nameTouched: nameTouched ?? this.nameTouched,
      valueTouched: valueTouched ?? this.valueTouched,
    );
  }
}

/// Handles the "Thêm khoản mới" create flow (name/icon/description +
/// initial formula, FR-017) and the pencil-dialog edit flow
/// (name/icon/description only — [isFormulaEditable] false; formula edits
/// to an existing item go through the inline "Lưu công thức" flow instead,
/// research.md §9).
class ExpenseControlFormController extends StateNotifier<ExpenseControlFormState> {
  ExpenseControlFormController({
    required this.repository,
    required this.planService,
    required this.userId,
    required this.getAllItems,
    this.existingItem,
    this.parentId,
    this.isFormulaEditable = true,
  }) : super(
         existingItem == null
             ? const ExpenseControlFormState()
             : ExpenseControlFormState(
                 name: existingItem.name,
                 iconKey: existingItem.iconKey,
                 description: existingItem.description,
                 method:
                     existingItem.allocationMethod ??
                     ExpenseAllocationMethod.percentage,
                 value: existingItem.allocationValue,
               ),
       );

  static const _uuid = Uuid();

  final ExpenseControlRepository repository;
  final ExpenseControlPlanService planService;
  final String userId;
  final List<ExpenseControlItem> Function() getAllItems;
  final ExpenseControlItem? existingItem;
  final String? parentId;
  final bool isFormulaEditable;

  void setName(String value) => state = state.copyWith(
    name: value,
    nameTouched: true,
    clearErrorMessage: true,
  );
  void setIconKey(String value) => state = state.copyWith(iconKey: value);
  void setDescription(String? value) =>
      state = state.copyWith(description: value);
  void setMethod(ExpenseAllocationMethod value) =>
      state = state.copyWith(method: value, clearErrorMessage: true);
  void setValue(double? value) => state = state.copyWith(
    value: value,
    valueTouched: true,
    clearErrorMessage: true,
  );

  bool get isNameValid => state.name.trim().isNotEmpty;

  bool get isValueValid =>
      !isFormulaEditable || (state.value != null && state.value! > 0);

  /// Gates the "required" error text: only after the user has actually
  /// interacted with the field, not the instant the dialog opens with
  /// empty defaults.
  bool get showNameError => state.nameTouched && !isNameValid;

  bool get showValueError => state.valueTouched && !isValueValid;

  String? get _effectiveParentId => parentId ?? existingItem?.parentId;

  /// FR-007/FR-008/FR-012, evaluated against the current form state as a
  /// candidate replacing/adding to the full plan. `null` when this form
  /// doesn't touch the formula (edit-name/icon/description dialog).
  ExpenseControlValidation? get budgetValidation {
    if (!isFormulaEditable) return null;
    final id = existingItem?.id ?? '__pending__';
    final candidate = ExpenseControlItem(
      id: id,
      userId: userId,
      parentId: _effectiveParentId,
      name: state.name,
      iconKey: state.iconKey,
      description: state.description,
      sortOrder: existingItem?.sortOrder ?? 0,
      allocationMethod: state.method,
      allocationValue: state.value,
    );
    final others = getAllItems().where((item) => item.id != id).toList();
    return planService.validateBudget([...others, candidate]);
  }

  bool get canSave =>
      isNameValid && isValueValid && (budgetValidation?.isValid ?? true);

  int _nextSortOrder() {
    final siblings = getAllItems().where(
      (item) => item.parentId == _effectiveParentId,
    );
    return siblings.length;
  }

  Future<void> save() async {
    if (!canSave) return;
    state = state.copyWith(isSubmitting: true, clearErrorMessage: true);
    try {
      final item = ExpenseControlItem(
        id: existingItem?.id ?? _uuid.v4(),
        userId: userId,
        parentId: _effectiveParentId,
        name: state.name.trim(),
        iconKey: state.iconKey,
        description: state.description,
        sortOrder: existingItem?.sortOrder ?? _nextSortOrder(),
        allocationMethod: isFormulaEditable
            ? state.method
            : existingItem?.allocationMethod,
        allocationValue: isFormulaEditable
            ? state.value
            : existingItem?.allocationValue,
      );
      if (existingItem != null) {
        await repository.update(item);
      } else {
        await repository.create(item);
      }
      state = state.copyWith(saved: true, isSubmitting: false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isSubmitting: false);
    }
  }
}

/// Params for [expenseControlFormControllerProvider] — a Dart record has
/// structural equality, so it works directly as a `.family` key.
typedef ExpenseControlFormParams = ({
  ExpenseControlItem? existingItem,
  String? parentId,
  bool isFormulaEditable,
});

final expenseControlFormControllerProvider = StateNotifierProvider.autoDispose
    .family<
      ExpenseControlFormController,
      ExpenseControlFormState,
      ExpenseControlFormParams
    >((ref, params) {
      return ExpenseControlFormController(
        repository: ref.watch(expenseControlRepositoryProvider),
        planService: ref.watch(expenseControlPlanServiceProvider),
        userId: ref.watch(currentUserIdProvider),
        getAllItems: () =>
            ref.read(expenseControlItemsStreamProvider).valueOrNull ?? [],
        existingItem: params.existingItem,
        parentId: params.parentId,
        isFormulaEditable: params.isFormulaEditable,
      );
    });
