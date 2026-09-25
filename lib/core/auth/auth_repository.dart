import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/config/app_environment.dart';

/// FR-004/FR-005/FR-006: picks which password-reset redirect to use.
/// A plain, side-effect-free function (no [BuildContext], no platform
/// check inside it — the caller supplies [isWeb]) specifically so a
/// VM-based `flutter test` run can exercise both branches directly; the
/// real `kIsWeb` is only ever passed at the one real call site below.
String resolvePasswordResetRedirectUrl({
  required bool isWeb,
  required String webRedirectUrl,
  required String mobileRedirectUrl,
}) {
  return isWeb ? webRedirectUrl : mobileRedirectUrl;
}

/// The subset of auth operations and identity data the Profile screen
/// needs. Depending on this interface, rather than the concrete
/// [AuthRepository] directly, keeps the screen testable without a live
/// Supabase client.
abstract interface class AccountAuthActions {
  String? get currentDisplayName;
  String? get currentEmail;
  String? get currentAvatarUrl;
  Future<void> signOut({SignOutScope scope = SignOutScope.local});
  Future<bool> isBiometricLoginEnabled();
  Future<void> setBiometricLoginEnabled(bool enabled);
}

/// Wraps Supabase Auth for the app's sign-in/sign-up/Account flows.
/// Email+password is the only supported authentication method (spec.md
/// Clarifications) — a phone number collected at sign-up is profile data
/// only, never a login credential (FR-005).
class AuthRepository implements AccountAuthActions {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// `true` once `AuthChangeEvent.passwordRecovery` fires (FR-016) — the
  /// user opened a password-reset deep link.
  Stream<bool> get onPasswordRecoveryEvent => onAuthStateChange.map(
    (state) => state.event == AuthChangeEvent.passwordRecovery,
  );

  Session? get currentSession => _client.auth.currentSession;

  /// Confirms the persisted session is still genuinely valid server-side
  /// (not just present in local cache) — used after a successful biometric
  /// check (FR-011) before declaring the user unlocked, per the
  /// session-death Clarification: a biometric success must never show a
  /// false "signed in" state for a session that's actually dead. Throws if
  /// the session is dead (expired/revoked refresh token); callers should
  /// fall back to the password form on any exception.
  Future<void> verifySessionAlive() => _client.auth.refreshSession();

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Registers a new email/password account (FR-003, FR-004, FR-006).
  /// [displayName] and [phoneNumber] are optional and, when provided, are
  /// stored via Supabase's `data:` metadata parameter — the same
  /// `raw_user_meta_data` mechanism [currentAvatarUrl] reads `avatar_url`
  /// from. [phoneNumber] is plain profile text with no OTP/SMS
  /// verification (FR-005). Signs the account in immediately — no email
  /// confirmation step (FR-019; requires the Supabase Dashboard's "Enable
  /// email confirmations" setting to be off, already done per spec.md
  /// Assumptions).
  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
    String? phoneNumber,
  }) async {
    final metadata = <String, dynamic>{
      if (displayName != null && displayName.isNotEmpty)
        'display_name': displayName,
      if (phoneNumber != null && phoneNumber.isNotEmpty)
        'phone_number': phoneNumber,
    };
    await _client.auth.signUp(
      email: email,
      password: password,
      data: metadata.isEmpty ? null : metadata,
    );
  }

  /// FR-014a/FR-016a/FR-016b: [scope] controls which sessions are revoked —
  /// `local` (default, unchanged) signs out only this device, `others`
  /// signs out every other session and keeps this one, `global` signs out
  /// everywhere including this device. FR-014a: a `local` (this-device)
  /// sign-out also clears this device's biometric login preference for the
  /// account being signed out of, cleared BEFORE the session goes away
  /// (afterward [_currentUserId] can no longer resolve).
  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    if (scope == SignOutScope.local) {
      await clearBiometricLoginState();
    }
    await _client.auth.signOut(scope: scope);
  }

  /// FR-015: requests a password-reset email. [redirectTo] is fixed per
  /// platform — a single, build-time-configured `https://` URL on Web
  /// (FR-004, Clarification 1 — never derived from the browser's runtime
  /// origin) or this app's registered mobile deep link — there is exactly
  /// one correct value for a given build/platform, not caller-configurable.
  Future<void> resetPasswordForEmail(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: resolvePasswordResetRedirectUrl(
        isWeb: kIsWeb,
        webRedirectUrl: AppEnvironment.webPasswordResetRedirectUrl,
        mobileRedirectUrl: 'com.finance.finance://reset-callback',
      ),
    );
  }

  /// FR-016: completes a password reset from a recovery-session context
  /// (only valid after `AuthChangeEvent.passwordRecovery` has fired).
  /// FR-016a: immediately signs the account out of every session globally,
  /// including this device, once the new password is set.
  Future<void> confirmPasswordReset(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
    await _client.auth.signOut(scope: SignOutScope.global);
  }

  @override
  String? get currentAvatarUrl =>
      _client.auth.currentUser?.userMetadata?['avatar_url'] as String?;

  /// FR-009: the signed-in user's display name, as set at sign-up
  /// ([signUp]'s `displayName` parameter). `null` if never set.
  @override
  String? get currentDisplayName =>
      _client.auth.currentUser?.userMetadata?['display_name'] as String?;

  /// FR-009: the signed-in user's email. Always present for a signed-in
  /// user, since email/password is the only supported authentication
  /// method (see this class's own doc comment).
  @override
  String? get currentEmail => _client.auth.currentUser?.email;

  String? get _currentUserId => _client.auth.currentUser?.id;

  static const _biometricEnabledKeyPrefix = 'BIOMETRIC_ENABLED_';
  static const _biometricPromptShownKeyPrefix = 'BIOMETRIC_PROMPT_SHOWN_';
  static const _secureStorage = FlutterSecureStorage();

  /// FR-008/FR-013: per-account, per-device biometric login preference.
  /// `false` (not enabled) for any account/device pair that has never
  /// enabled it — scoped by the signed-in user's id so a different account
  /// signing in later on this device never inherits it.
  @override
  Future<bool> isBiometricLoginEnabled() async {
    final userId = _currentUserId;
    if (userId == null) return false;
    return _secureStorage.containsKey(
      key: '$_biometricEnabledKeyPrefix$userId',
    );
  }

  /// FR-010: toggles biometric login for the currently signed-in account on
  /// this device. Deletes the key rather than writing `false`, so "key
  /// absent" is the single source of truth for "disabled" (data-model.md §1).
  @override
  Future<void> setBiometricLoginEnabled(bool enabled) async {
    final userId = _currentUserId;
    if (userId == null) return;
    final key = '$_biometricEnabledKeyPrefix$userId';
    if (enabled) {
      await _secureStorage.write(key: key, value: 'true');
    } else {
      await _secureStorage.delete(key: key);
    }
  }

  /// FR-009: `true` only the first time this is called for the currently
  /// signed-in account on this device (data-model.md §1). Callers MUST
  /// call [markBiometricPromptShown] immediately after showing the prompt,
  /// regardless of the user's answer.
  Future<bool> shouldShowBiometricEnablePrompt() async {
    final userId = _currentUserId;
    if (userId == null) return false;
    final alreadyShown = await _secureStorage.containsKey(
      key: '$_biometricPromptShownKeyPrefix$userId',
    );
    return !alreadyShown;
  }

  /// Marks the one-time enable-biometric prompt as shown (data-model.md
  /// §1). Does not itself enable biometric login.
  Future<void> markBiometricPromptShown() async {
    final userId = _currentUserId;
    if (userId == null) return;
    await _secureStorage.write(
      key: '$_biometricPromptShownKeyPrefix$userId',
      value: 'true',
    );
  }

  /// FR-014a: clears both the biometric preference and the one-time-prompt
  /// marker for the CURRENTLY signed-in account, so a future sign-in on
  /// this device is treated as a fresh enrollment opportunity. Must be
  /// called before [signOut] clears the session (which is when
  /// [_currentUserId] stops resolving).
  Future<void> clearBiometricLoginState() async {
    final userId = _currentUserId;
    if (userId == null) return;
    await _secureStorage.delete(key: '$_biometricEnabledKeyPrefix$userId');
    await _secureStorage.delete(key: '$_biometricPromptShownKeyPrefix$userId');
  }
}
