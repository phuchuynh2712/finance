import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../expense_control/presentation/expense_control_providers.dart';

/// Which validation problem blocked the last save attempt (FR-008).
enum ExpenseSaveError { invalidAmount, missingItem, writeFailed }

class ExpenseFormState {
  const ExpenseFormState({
    this.amount,
    this.itemId,
    this.isSubmitting = false,
    this.saveError,
    this.writeErrorDetail,
    this.saved = false,
  });

  /// `null` while the field is empty/untouched — distinct from `0`.
  final int? amount;
  final String? itemId;
  final bool isSubmitting;
  final ExpenseSaveError? saveError;

  /// Only set alongside [ExpenseSaveError.writeFailed] — the underlying
  /// caught exception, kept as the original `Object` (not `.toString()`'d)
  /// so the widget-side `ref.listen` can classify it via the shared
  /// `mapErrorToMessage` mapper at display time (contracts/error_mapper.md
  /// Pattern B).
  final Object? writeErrorDetail;
  final bool saved;

  ExpenseFormState copyWith({
    int? amount,
    bool clearAmount = false,
    String? itemId,
    bool? isSubmitting,
    ExpenseSaveError? saveError,
    Object? writeErrorDetail,
    bool? saved,
    bool clearError = false,
  }) {
    return ExpenseFormState(
      amount: clearAmount ? null : (amount ?? this.amount),
      itemId: itemId ?? this.itemId,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      saveError: clearError ? null : (saveError ?? this.saveError),
      writeErrorDetail: clearError
          ? null
          : (writeErrorDetail ?? this.writeErrorDetail),
      saved: saved ?? this.saved,
    );
  }
}

/// FR-008–FR-011: the "Chi tiêu" screen's Nhập tay tab state — an
/// accumulated keypad amount, a picked leaf item, and the save action that
/// atomically records the expense (FR-009). Pure screen-local state except
/// for the single [recordExpense] call in [save].
class ExpenseFormController extends StateNotifier<ExpenseFormState> {
  ExpenseFormController({required this.ref}) : super(const ExpenseFormState());

  final Ref ref;

  void appendDigit(String digit) {
    final current = state.amount?.toString() ?? '';
    // A leading-zero-only amount stays "0" rather than growing into "01",
    // "001", etc. — the first non-zero digit replaces it instead.
    final next = current == '0' ? digit : '$current$digit';
    final parsed = int.tryParse(next);
    if (parsed == null) return;
    state = state.copyWith(amount: parsed, clearError: true);
  }

  void backspace() {
    final current = state.amount?.toString() ?? '';
    if (current.isEmpty) return;
    final next = current.substring(0, current.length - 1);
    if (next.isEmpty) {
      state = state.copyWith(clearAmount: true, clearError: true);
    } else {
      state = state.copyWith(amount: int.parse(next), clearError: true);
    }
  }

  void pickItem(String itemId) {
    state = state.copyWith(itemId: itemId, clearError: true);
  }

  bool get canSave => (state.amount ?? 0) > 0 && state.itemId != null;

  Future<void> save() async {
    if (state.isSubmitting) return;
    if (!canSave) {
      state = state.copyWith(
        saveError: state.itemId == null
            ? ExpenseSaveError.missingItem
            : ExpenseSaveError.invalidAmount,
      );
      return;
    }
    // Set before the first `await` so a rapid second tap sees
    // `isSubmitting: true` and is ignored by the guard above (Edge Cases:
    // double-tap prevention), mirroring IncomeFormController.save().
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await ref
          .read(expenseControlRepositoryProvider)
          .recordExpense(itemId: state.itemId!, amount: state.amount!);
      state = state.copyWith(saved: true, isSubmitting: false);
    } catch (e) {
      state = state.copyWith(
        saveError: ExpenseSaveError.writeFailed,
        writeErrorDetail: e,
        isSubmitting: false,
      );
    }
  }
}

final expenseFormControllerProvider =
    StateNotifierProvider.autoDispose<ExpenseFormController, ExpenseFormState>(
      (ref) => ExpenseFormController(ref: ref),
    );

/// The "Quét hoá đơn" tab's hard-coded mock recognition result
/// (chi-tieu-spec.md's static "Đã nhận diện" card) — no real OCR/camera
/// logic exists (spec.md Out of Scope). `merchantName` is display-only and
/// is NEVER passed to [ExpenseFormController]/`recordExpense` (spec.md
/// Clarifications: scan only supplies amount + picked item, symmetric with
/// manual entry).
const mockScanAmount = 450000;
const mockScanMerchantName = 'Coopmart';

class ScanFormState {
  const ScanFormState({
    this.captured = false,
    this.itemId,
    this.isSubmitting = false,
    this.saveError,
    this.writeErrorDetail,
    this.saved = false,
  });

  /// Whether "Chụp hoá đơn" has been tapped, revealing the mock result card.
  final bool captured;
  final String? itemId;
  final bool isSubmitting;
  final ExpenseSaveError? saveError;

  /// Only set alongside [ExpenseSaveError.writeFailed] — the underlying
  /// caught exception, kept as the original `Object` (not `.toString()`'d)
  /// so the widget-side `ref.listen` can classify it via the shared
  /// `mapErrorToMessage` mapper at display time (contracts/error_mapper.md
  /// Pattern B).
  final Object? writeErrorDetail;
  final bool saved;

  ScanFormState copyWith({
    bool? captured,
    String? itemId,
    bool? isSubmitting,
    ExpenseSaveError? saveError,
    Object? writeErrorDetail,
    bool? saved,
    bool clearError = false,
  }) {
    return ScanFormState(
      captured: captured ?? this.captured,
      itemId: itemId ?? this.itemId,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      saveError: clearError ? null : (saveError ?? this.saveError),
      writeErrorDetail: clearError
          ? null
          : (writeErrorDetail ?? this.writeErrorDetail),
      saved: saved ?? this.saved,
    );
  }
}

/// US3: the "Quét hoá đơn" tab's state — a static mock "capture" step
/// followed by the same atomic [recordExpense] save as the manual-entry
/// tab, using [mockScanAmount] instead of a keypad-entered amount.
class ScanFormController extends StateNotifier<ScanFormState> {
  ScanFormController({required this.ref}) : super(const ScanFormState());

  final Ref ref;

  void capture() {
    state = state.copyWith(captured: true, clearError: true);
  }

  void pickItem(String itemId) {
    state = state.copyWith(itemId: itemId, clearError: true);
  }

  bool get canSave => state.captured && state.itemId != null;

  Future<void> save() async {
    if (state.isSubmitting) return;
    if (!canSave) {
      state = state.copyWith(saveError: ExpenseSaveError.missingItem);
      return;
    }
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await ref
          .read(expenseControlRepositoryProvider)
          .recordExpense(itemId: state.itemId!, amount: mockScanAmount);
      state = state.copyWith(saved: true, isSubmitting: false);
    } catch (e) {
      state = state.copyWith(
        saveError: ExpenseSaveError.writeFailed,
        writeErrorDetail: e,
        isSubmitting: false,
      );
    }
  }
}

final scanFormControllerProvider =
    StateNotifierProvider.autoDispose<ScanFormController, ScanFormState>(
      (ref) => ScanFormController(ref: ref),
    );
