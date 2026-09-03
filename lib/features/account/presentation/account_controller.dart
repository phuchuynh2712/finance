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
    this.isLinkingGoogle = false,
    this.linkGoogleErrorMessage,
  });

  final bool isSubmittingAvatar;
  final bool isSubmittingPassword;
  final String? avatarErrorMessage;
  final String? passwordErrorMessage;
  final bool avatarSaved;
  final bool passwordSaved;
  final bool isLinkingGoogle;
  final String? linkGoogleErrorMessage;

  AccountState copyWith({
    bool? isSubmittingAvatar,
    bool? isSubmittingPassword,
    String? avatarErrorMessage,
    String? passwordErrorMessage,
    bool? avatarSaved,
    bool? passwordSaved,
    bool? isLinkingGoogle,
    String? linkGoogleErrorMessage,
    bool clearAvatarError = false,
    bool clearPasswordError = false,
    bool clearLinkGoogleError = false,
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
      isLinkingGoogle: isLinkingGoogle ?? this.isLinkingGoogle,
      linkGoogleErrorMessage: clearLinkGoogleError
          ? null
          : (linkGoogleErrorMessage ?? this.linkGoogleErrorMessage),
    );
  }
}

class AccountController extends StateNotifier<AccountState> {
  AccountController(this._repository) : super(const AccountState());

  final AccountAuthActions _repository;

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
      await _repository.changePassword(newPassword);
      state = state.copyWith(isSubmittingPassword: false, passwordSaved: true);
    } catch (e) {
      state = state.copyWith(
        isSubmittingPassword: false,
        passwordErrorMessage: e.toString(),
      );
    }
  }

  Future<void> signOut() => _repository.signOut();

  /// Links a Google account to the currently signed-in user (FR-016),
  /// for a Google account whose email differs from this account's email.
  /// `identity_already_exists` (FR-017) surfaces as an inline error with no
  /// state change to either account.
  Future<void> linkGoogleAccount() async {
    state = state.copyWith(isLinkingGoogle: true, clearLinkGoogleError: true);
    try {
      await _repository.linkGoogleAccount();
      state = state.copyWith(isLinkingGoogle: false);
    } catch (e) {
      state = state.copyWith(
        isLinkingGoogle: false,
        linkGoogleErrorMessage: e.toString(),
      );
    }
  }

  /// The linked Google account's email, or null if none linked (FR-018).
  String? get linkedGoogleEmail => _repository.linkedGoogleEmail;
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
