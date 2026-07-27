import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/auth/auth_state_provider.dart';
import '../domain/envelope.dart';
import '../domain/envelope_repository.dart';
import 'envelopes_providers.dart';

class EnvelopeFormState {
  const EnvelopeFormState({
    this.name = '',
    this.method = AllocationMethod.percentage,
    this.value,
    this.isRoundingReceiver = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.saved = false,
  });

  final String name;
  final AllocationMethod method;

  /// UI-facing value: a whole-number percentage (e.g. `30` for 30%) when
  /// [method] is percentage, or a whole-VND amount when fixed. Converted to
  /// the domain's fraction-or-VND `allocationValue` only at save time.
  final double? value;
  final bool isRoundingReceiver;
  final bool isSubmitting;
  final String? errorMessage;
  final bool saved;

  EnvelopeFormState copyWith({
    String? name,
    AllocationMethod? method,
    double? value,
    bool? isRoundingReceiver,
    bool? isSubmitting,
    String? errorMessage,
    bool? saved,
    bool clearErrorMessage = false,
  }) {
    return EnvelopeFormState(
      name: name ?? this.name,
      method: method ?? this.method,
      value: value ?? this.value,
      isRoundingReceiver: isRoundingReceiver ?? this.isRoundingReceiver,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      saved: saved ?? this.saved,
    );
  }
}

class EnvelopeFormController extends StateNotifier<EnvelopeFormState> {
  EnvelopeFormController({
    required this.repository,
    required this.userId,
    this.existingEnvelope,
  }) : super(
         existingEnvelope == null
             ? const EnvelopeFormState()
             : EnvelopeFormState(
                 name: existingEnvelope.name,
                 method: existingEnvelope.allocationMethod,
                 value:
                     existingEnvelope.allocationMethod ==
                         AllocationMethod.percentage
                     ? existingEnvelope.allocationValue * 100
                     : existingEnvelope.allocationValue,
                 isRoundingReceiver: existingEnvelope.isRoundingReceiver,
               ),
       );

  static const _uuid = Uuid();

  final EnvelopeRepository repository;
  final String userId;
  final Envelope? existingEnvelope;

  void setName(String name) =>
      state = state.copyWith(name: name, clearErrorMessage: true);
  void setMethod(AllocationMethod method) =>
      state = state.copyWith(method: method, clearErrorMessage: true);
  void setValue(double? value) =>
      state = state.copyWith(value: value, clearErrorMessage: true);
  void setIsRoundingReceiver(bool value) =>
      state = state.copyWith(isRoundingReceiver: value);

  Future<void> save() async {
    if (state.name.trim().isEmpty || state.value == null || state.value! <= 0) {
      return;
    }

    state = state.copyWith(isSubmitting: true, clearErrorMessage: true);
    try {
      final allocationValue = state.method == AllocationMethod.percentage
          ? state.value! / 100
          : state.value!;
      final envelope = Envelope(
        id: existingEnvelope?.id ?? _uuid.v4(),
        userId: userId,
        name: state.name.trim(),
        allocationMethod: state.method,
        allocationValue: allocationValue,
        balance: existingEnvelope?.balance ?? 0,
        isRoundingReceiver: state.isRoundingReceiver,
      );
      if (existingEnvelope != null) {
        await repository.update(envelope);
      } else {
        await repository.create(envelope);
      }
      state = state.copyWith(saved: true, isSubmitting: false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isSubmitting: false);
    }
  }
}

final envelopeFormControllerProvider = StateNotifierProvider.autoDispose
    .family<EnvelopeFormController, EnvelopeFormState, Envelope?>((
      ref,
      existingEnvelope,
    ) {
      return EnvelopeFormController(
        repository: ref.watch(envelopeRepositoryProvider),
        userId: ref.watch(currentUserIdProvider),
        existingEnvelope: existingEnvelope,
      );
    });
