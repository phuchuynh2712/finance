import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/auth_state_provider.dart';

class AccountState {
  const AccountState({
    this.isSubmittingAvatar = false,
    this.isSubmittingPassword = false,
    this.avatarErrorMessage,
    this.passwordErrorMessage,
    this.avatarSaved = false,
    this.passwordSaved = false,
    this.isBiometricEnabled = false,
  });

  final bool isSubmittingAvatar;
  final bool isSubmittingPassword;
  final String? avatarErrorMessage;
  final String? passwordErrorMessage;
  final bool avatarSaved;
  final bool passwordSaved;
  final bool isBiometricEnabled;

  AccountState copyWith({
    bool? isSubmittingAvatar,
    bool? isSubmittingPassword,
    String? avatarErrorMessage,
    String? passwordErrorMessage,
    bool? avatarSaved,
    bool? passwordSaved,
    bool? isBiometricEnabled,
    bool clearAvatarError = false,
    bool clearPasswordError = false,
  }) {
    return AccountState(
      isSubmittingAvatar: isSubmittingAvatar ?? this.isSubmittingAvatar,
      isSubmittingPassword: isSubmittingPassword ?? this.isSubmittingPassword,
      avatarErrorMessage: clearAvatarError
          ? null
          : (avatarErrorMessage ?? this.avatarErrorMessage),
      passwordErrorMessage: clearPasswordError
          ? null
          : (passwordErrorMessage ?? this.passwordErrorMessage),
      avatarSaved: avatarSaved ?? this.avatarSaved,
      passwordSaved: passwordSaved ?? this.passwordSaved,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
    );
  }
}

class AccountController extends StateNotifier<AccountState> {
  AccountController(this._repository) : super(const AccountState()) {
    _loadBiometricState();
  }

  final AccountAuthActions _repository;

  Future<void> _loadBiometricState() async {
    final enabled = await _repository.isBiometricLoginEnabled();
    state = state.copyWith(isBiometricEnabled: enabled);
  }

  Future<void> updateAvatar(String avatarUrl) async {
    state = state.copyWith(isSubmittingAvatar: true, clearAvatarError: true);
    try {
      await _repository.updateAvatar(avatarUrl);
      state = state.copyWith(isSubmittingAvatar: false, avatarSaved: true);
    } catch (e) {
      state = state.copyWith(
        isSubmittingAvatar: false,
        avatarErrorMessage: e.toString(),
      );
    }
  }

  Future<void> changePassword(String newPassword) async {
    state = state.copyWith(
      isSubmittingPassword: true,
      clearPasswordError: true,
    );
    try {
      // FR-016b: signs out every OTHER device/session; this device is
      // unaffected (research.md §2).
      await _repository.changePassword(newPassword);
      state = state.copyWith(isSubmittingPassword: false, passwordSaved: true);
    } catch (e) {
      state = state.copyWith(
        isSubmittingPassword: false,
        passwordErrorMessage: e.toString(),
      );
    }
  }

  /// FR-014a: signing out clears the biometric preference for this
  /// account/device (handled inside [AccountAuthActions.signOut] itself),
  /// so a future sign-in is a fresh enrollment opportunity.
  Future<void> signOut() => _repository.signOut();

  /// FR-010: manual on/off toggle, independent of the FR-009 first-sign-in
  /// prompt.
  Future<void> setBiometricEnabled(bool enabled) async {
    await _repository.setBiometricLoginEnabled(enabled);
    state = state.copyWith(isBiometricEnabled: enabled);
  }
}

/// Narrower than [authRepositoryProvider] on purpose: overriding this in
/// tests only requires a fake [AccountAuthActions], not the full
/// [AuthRepository] contract (which needs a live [SupabaseClient] to
/// construct).
final accountAuthActionsProvider = Provider<AccountAuthActions>((ref) {
  return ref.watch(authRepositoryProvider);
});

final accountControllerProvider =
    StateNotifierProvider.autoDispose<AccountController, AccountState>((ref) {
      return AccountController(ref.watch(accountAuthActionsProvider));
    });
