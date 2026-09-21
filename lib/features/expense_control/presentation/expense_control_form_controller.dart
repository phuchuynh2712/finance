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
    this.isSavingsReceiver = false,
    this.savingsReceiverRejected = false,
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

  /// Staged value of the savings-receiver toggle (FR-008). Only meaningful
  /// — and only shown by the dialog — when this form is editing/creating a
  /// leaf ([isFormulaEditable] true or a brand-new item); a group can never
  /// hold this mark (FR-010).
  final bool isSavingsReceiver;

  /// FR-009: set when the last attempt to turn the toggle on was rejected
  /// because a different item already holds the mark — drives the inline
  /// error message even though [isSavingsReceiver] itself bounces back to
  /// `false` (the toggle never visually shows an "on" state it can't save).
  final bool savingsReceiverRejected;
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
    bool? isSavingsReceiver,
    bool? savingsReceiverRejected,
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
      isSavingsReceiver: isSavingsReceiver ?? this.isSavingsReceiver,
      savingsReceiverRejected:
          savingsReceiverRejected ?? this.savingsReceiverRejected,
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

/// Handles three distinct save destinations, per research.md Decision 3:
/// creating a brand-new item (`existingItem == null`) always commits
/// immediately via [ExpenseControlRepository.create]; editing an existing
/// **group** (`isFormulaEditable == false`) always commits immediately via
/// [ExpenseControlRepository.update], unchanged from before this feature;
/// editing an existing **leaf** (`isFormulaEditable == true`) now stages the
/// whole edit — name/icon/description AND formula together — via
/// [onStageEdit] instead of writing to the repository at all. Only "Lưu
/// công thức" (or the tab-switch confirmation's "Lưu" choice) later commits
/// a staged leaf edit.
class ExpenseControlFormController
    extends StateNotifier<ExpenseControlFormState> {
  ExpenseControlFormController({
    required this.repository,
    required this.planService,
    required this.userId,
    required this.getAllItems,
    this.existingItem,
    this.parentId,
    this.isFormulaEditable = true,
    this.onStageEdit,
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
                 isSavingsReceiver: existingItem.isSavingsReceiver,
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

  /// Called instead of [repository.update] when saving an existing
  /// **leaf**'s edit dialog (research.md Decision 3) — `null` in call sites
  /// that don't need staging (e.g. unit tests exercising only the
  /// create/group branches).
  final void Function(String itemId, PendingItemEdit edit)? onStageEdit;

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

  /// FR-009: rejects turning the toggle on while a *different* item already
  /// holds the mark — the toggle itself bounces back to off (never stages a
  /// value it can't actually save), but [showSavingsReceiverBlockedError]
  /// is set so the dialog still shows why, rather than giving no feedback
  /// at all for the tap.
  void setIsSavingsReceiver(bool value) {
    if (value && isSavingsReceiverBlocked) {
      state = state.copyWith(
        isSavingsReceiver: false,
        savingsReceiverRejected: true,
      );
      return;
    }
    state = state.copyWith(
      isSavingsReceiver: value,
      clearErrorMessage: true,
      savingsReceiverRejected: false,
    );
  }

  /// True when an item other than the one this form is editing already
  /// holds the savings-receiver mark (FR-009) — drives both
  /// [setIsSavingsReceiver]'s rejection and the dialog's inline explanation
  /// of why the toggle can't be turned on right now. A group can never hold
  /// this mark (the invariant [ExpenseControlItem.clearFormula] enforces),
  /// so no separate leaf/group check is needed here.
  bool get isSavingsReceiverBlocked => getAllItems().any(
    (item) => item.id != existingItem?.id && item.isSavingsReceiver,
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
      balance: existingItem?.balance ?? 0,
      isSavingsReceiver: existingItem?.isSavingsReceiver ?? false,
    );
    final others = getAllItems().where((item) => item.id != id).toList();
    return planService.validateBudget([...others, candidate]);
  }

  bool get canSave =>
      isNameValid &&
      isValueValid &&
      (budgetValidation?.isValid ?? true) &&
      !(state.isSavingsReceiver && isSavingsReceiverBlocked);

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
      final existing = existingItem;
      if (existing != null && isFormulaEditable) {
        // Editing an existing leaf: stage, don't write (research.md
        // Decision 3/4) — the caller's onStageEdit is expected to write
        // into pendingItemEditsProvider (or an equivalent test double).
        onStageEdit?.call(
          existing.id,
          PendingItemEdit(
            name: state.name.trim(),
            iconKey: state.iconKey,
            description: state.description,
            method: state.method,
            value: state.value,
            isSavingsReceiver: state.isSavingsReceiver,
          ),
        );
      } else {
        final item = ExpenseControlItem(
          id: existing?.id ?? _uuid.v4(),
          userId: userId,
          parentId: _effectiveParentId,
          name: state.name.trim(),
          iconKey: state.iconKey,
          description: state.description,
          sortOrder: existing?.sortOrder ?? _nextSortOrder(),
          allocationMethod: isFormulaEditable
              ? state.method
              : existing?.allocationMethod,
          allocationValue: isFormulaEditable
              ? state.value
              : existing?.allocationValue,
          balance: existing?.balance ?? 0,
          // FR-010: a group (existing item being edited with formula
          // fields hidden) can never hold this mark — only a brand-new
          // item (which may turn out to be a leaf) carries the staged
          // toggle value through.
          isSavingsReceiver: existing == null ? state.isSavingsReceiver : false,
        );
        if (existing != null) {
          await repository.update(item);
        } else {
          await repository.create(item);
        }
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
        onStageEdit: (itemId, edit) => ref
            .read(pendingItemEditsProvider.notifier)
            .update((state) => {...state, itemId: edit}),
      );
    });
