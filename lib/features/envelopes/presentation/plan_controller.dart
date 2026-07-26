import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/auth/auth_state_provider.dart';
import '../domain/allocation_event.dart';
import '../domain/allocation_event_line.dart';
import '../domain/allocation_repository.dart';
import '../domain/compute_allocation_preview.dart';
import '../domain/envelope.dart';
import 'envelopes_providers.dart';

class PlanState {
  const PlanState({
    this.incomeAmount,
    this.preview,
    this.isSubmitting = false,
    this.errorMessage,
    this.confirmed = false,
  });

  final int? incomeAmount;
  final AllocationPreviewResult? preview;
  final bool isSubmitting;
  final String? errorMessage;
  final bool confirmed;
}

class PlanController extends StateNotifier<PlanState> {
  PlanController({
    required List<Envelope> envelopes,
    required AllocationRepository allocationRepository,
    required String userId,
  }) : _envelopes = envelopes,
       _allocationRepository = allocationRepository,
       _userId = userId,
       super(const PlanState());

  static const _uuid = Uuid();

  final List<Envelope> _envelopes;
  final AllocationRepository _allocationRepository;
  final String _userId;

  /// Recomputes the preview for a raw income input string. An unparseable
  /// or non-positive value clears the preview (FR-029: reject before
  /// showing a preview) rather than surfacing a calculation error.
  void updateIncome(String rawInput) {
    final digitsOnly = rawInput.replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = int.tryParse(digitsOnly);
    if (parsed == null || parsed <= 0) {
      state = const PlanState();
      return;
    }
    final preview = computeAllocationPreview(
      incomeAmount: parsed,
      envelopes: _envelopes,
    );
    state = PlanState(incomeAmount: parsed, preview: preview);
  }

  Future<void> confirm() async {
    final preview = state.preview;
    final income = state.incomeAmount;
    if (preview == null || income == null || !preview.canConfirm) return;

    state = PlanState(
      incomeAmount: income,
      preview: preview,
      isSubmitting: true,
    );
    try {
      final eventId = _uuid.v4();
      final event = AllocationEvent(
        id: eventId,
        userId: _userId,
        eventDate: DateTime.now(),
        incomeAmount: income,
      );
      final lines = [
        for (final line in preview.lines)
          AllocationEventLine(
            id: _uuid.v4(),
            userId: _userId,
            allocationEventId: eventId,
            envelopeId: line.envelope.id,
            amount: line.allocatedAmount,
            isRoundingRemainderLine:
                line.envelope.id == preview.receiverEnvelopeId &&
                preview.leftoverAddedToReceiver > 0,
          ),
      ];
      await _allocationRepository.confirmEvent(event: event, lines: lines);
      state = const PlanState(confirmed: true);
    } catch (e) {
      state = PlanState(
        incomeAmount: income,
        preview: preview,
        errorMessage: e.toString(),
      );
    }
  }
}

final planControllerProvider =
    StateNotifierProvider.autoDispose<PlanController, PlanState>((ref) {
      // Deliberately `ref.read`, not `ref.watch`, for the envelope snapshot:
      // this controller must NOT be torn down and recreated mid-flow just
      // because the underlying envelope stream re-emits (e.g. its initial
      // loading→data transition) — that would silently disconnect the
      // TextField's onChanged callback from a disposed controller. The
      // Plan flow intentionally operates on a snapshot taken when it opens.
      return PlanController(
        envelopes: ref.read(envelopesStreamProvider).valueOrNull ?? [],
        allocationRepository: ref.watch(allocationRepositoryProvider),
        userId: ref.watch(currentUserIdProvider),
      );
    });
