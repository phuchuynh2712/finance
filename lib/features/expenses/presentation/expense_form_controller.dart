import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/auth/auth_state_provider.dart';
import '../../envelopes/presentation/envelopes_providers.dart';
import '../domain/compute_overspend.dart';
import '../domain/expense_entry.dart';
import '../domain/expense_repository.dart';
import 'expenses_providers.dart';

class PendingOverspend {
  const PendingOverspend({required this.shortfall});
  final int shortfall;
}

class ExpenseFormState {
  const ExpenseFormState({
    this.envelopeId,
    this.amount,
    this.note,
    this.isSubmitting = false,
    this.errorMessage,
    this.saved = false,
    this.pendingOverspend,
  });

  final String? envelopeId;
  final int? amount;
  final String? note;
  final bool isSubmitting;
  final String? errorMessage;
  final bool saved;

  /// Non-null when the user must resolve an overspend by choosing a
  /// covering envelope before the entry saves (FR-016).
  final PendingOverspend? pendingOverspend;

  ExpenseFormState copyWith({
    String? envelopeId,
    int? amount,
    String? note,
    bool? isSubmitting,
    String? errorMessage,
    bool? saved,
    PendingOverspend? pendingOverspend,
    bool clearPendingOverspend = false,
    bool clearErrorMessage = false,
  }) {
    return ExpenseFormState(
      envelopeId: envelopeId ?? this.envelopeId,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      saved: saved ?? this.saved,
      pendingOverspend: clearPendingOverspend
          ? null
          : (pendingOverspend ?? this.pendingOverspend),
    );
  }
}

/// Manages both creating a new expense and editing a saved one — when
/// [existingExpense] is provided, [save] reverses-then-reapplies via
/// [ExpenseRepository.update] instead of [ExpenseRepository.create]
/// (FR-018a), and the overspend check is run against the envelope's
/// balance restored to what it would be with the old entry undone.
class ExpenseFormController extends StateNotifier<ExpenseFormState> {
  ExpenseFormController({
    required this.envelopeBalances,
    required this.repository,
    required this.userId,
    this.existingExpense,
  }) : super(
         ExpenseFormState(
           envelopeId: existingExpense?.envelopeId,
           amount: existingExpense?.amount,
           note: existingExpense?.note,
         ),
       );

  static const _uuid = Uuid();

  /// envelopeId -> current balance, snapshotted once at flow-start (see
  /// research on the analogous Plan flow bug: watching a live stream here
  /// would risk this controller being torn down mid-flow).
  final Map<String, int> envelopeBalances;
  final ExpenseRepository repository;
  final String userId;
  final ExpenseEntry? existingExpense;

  void setEnvelope(String envelopeId) {
    state = state.copyWith(envelopeId: envelopeId, clearPendingOverspend: true);
  }

  void setAmount(int? amount) {
    state = state.copyWith(amount: amount, clearPendingOverspend: true);
  }

  void setNote(String? note) => state = state.copyWith(note: note);

  void cancelCoveringPrompt() {
    state = state.copyWith(clearPendingOverspend: true);
  }

  Future<void> save() async {
    final envelopeId = state.envelopeId;
    final amount = state.amount;
    if (envelopeId == null || amount == null || amount <= 0) return;

    final targetBalance = envelopeBalances[envelopeId] ?? 0;
    final isEditingSameEnvelope =
        existingExpense != null && existingExpense!.envelopeId == envelopeId;
    final restoredBalance = isEditingSameEnvelope
        ? targetBalance + existingExpense!.amount
        : targetBalance;
    final otherEnvelopesCount = envelopeBalances.keys
        .where((id) => id != envelopeId)
        .length;

    final overspend = computeOverspend(
      expenseAmount: amount,
      targetEnvelopeBalance: restoredBalance,
      otherEnvelopesCount: otherEnvelopesCount,
    );

    if (overspend.needsCoveringEnvelope) {
      state = state.copyWith(
        pendingOverspend: PendingOverspend(shortfall: overspend.shortfall),
      );
      return;
    }

    await _persist(coveringEnvelopeId: null);
  }

  Future<void> confirmWithCoveringEnvelope(String coveringEnvelopeId) async {
    await _persist(coveringEnvelopeId: coveringEnvelopeId);
  }

  Future<void> _persist({String? coveringEnvelopeId}) async {
    state = state.copyWith(isSubmitting: true, clearErrorMessage: true);
    try {
      final expense = ExpenseEntry(
        id: existingExpense?.id ?? _uuid.v4(),
        userId: userId,
        envelopeId: state.envelopeId!,
        amount: state.amount!,
        entryDate: existingExpense?.entryDate ?? DateTime.now(),
        note: state.note,
      );
      if (existingExpense != null) {
        await repository.update(
          expense: expense,
          coveringEnvelopeId: coveringEnvelopeId,
        );
      } else {
        await repository.create(
          expense: expense,
          coveringEnvelopeId: coveringEnvelopeId,
        );
      }
      state = state.copyWith(
        saved: true,
        isSubmitting: false,
        clearPendingOverspend: true,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isSubmitting: false);
    }
  }
}

final expenseFormControllerProvider = StateNotifierProvider.autoDispose
    .family<ExpenseFormController, ExpenseFormState, ExpenseEntry?>((
      ref,
      existingExpense,
    ) {
      final envelopes = ref.read(envelopesStreamProvider).valueOrNull ?? [];
      return ExpenseFormController(
        envelopeBalances: {for (final e in envelopes) e.id: e.balance},
        repository: ref.watch(expenseRepositoryProvider),
        userId: ref.watch(currentUserIdProvider),
        existingExpense: existingExpense,
      );
    });
