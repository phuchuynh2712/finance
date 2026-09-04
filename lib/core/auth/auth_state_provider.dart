import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/supabase_client_provider.dart';
import 'auth_repository.dart';
import 'biometric_login_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

final biometricLoginRepositoryProvider = Provider<BiometricLoginRepository>((
  ref,
) {
  return BiometricLoginRepository(LocalAuthentication());
});

/// Streams Supabase auth state changes for the router's redirect guard
/// (FR-025) and any feature controller that needs to react to sign-in/out.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
});

/// Convenience derived provider: is a user currently signed in?
///
/// Defaults to `false` while the initial auth state is still loading, so the
/// router guard fails safe (redirects to sign-in) rather than briefly
/// allowing access before the first auth event arrives.
final isSignedInProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.valueOrNull?.session != null;
});

/// The signed-in user's ID, for scoping repository queries to the current
/// user (RLS mirrors this scoping on the Supabase side). Feature code that
/// reads this MUST only run once a user is confirmed signed in (i.e. behind
/// the router's auth guard), so the exception here indicates a real bug
/// rather than a state to handle gracefully.
final currentUserIdProvider = Provider<String>((ref) {
  final userId = ref
      .watch(authStateChangesProvider)
      .valueOrNull
      ?.session
      ?.user
      .id;
  if (userId == null) {
    throw StateError(
      'currentUserIdProvider read while signed out — this indicates a '
      'screen reachable outside the router auth guard (FR-025)',
    );
  }
  return userId;
});

/// Cold-start / background-resume re-entry gate (FR-020/FR-021,
/// data-model.md §3). `true` means the Login screen must be shown as a lock
/// screen before the already-signed-in user can reach the app, regardless of
/// [isSignedInProvider].
///
/// FR-020's cold-start rule is implemented by reacting to the FIRST auth
/// event this app instance ever receives from [authStateChangesProvider]:
/// if a session already exists at that point (a persisted session was
/// restored), the app locks immediately — this is exactly "an
/// already-authenticated session exists on the device" at cold start.
/// Subsequent auth events (e.g. an explicit new sign-in) do NOT re-lock —
/// [SignInScreen] explicitly unlocks right after a real sign-in completes
/// (FR-021), and [AppLifecycleObserver] is the only other thing allowed to
/// lock again, on a background-resume past the 5-minute threshold (FR-020).
class AppLockNotifier extends StateNotifier<bool> {
  AppLockNotifier(Ref ref) : super(false) {
    _subscription = ref.listen(authStateChangesProvider, (previous, next) {
      if (_initialCheckDone) return;
      _initialCheckDone = true;
      if (next.valueOrNull?.session != null) {
        state = true;
      }
    }, fireImmediately: true);
  }

  bool _initialCheckDone = false;
  late final ProviderSubscription<AsyncValue<AuthState>> _subscription;

  void lock() => state = true;
  void unlock() => state = false;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

final appLockProvider = StateNotifierProvider<AppLockNotifier, bool>((ref) {
  return AppLockNotifier(ref);
});

/// `true` only while the most recent auth event is
/// `AuthChangeEvent.passwordRecovery` (FR-016), taking router priority over
/// [isSignedInProvider]/[appLockProvider] so the user lands on the "Set New
/// Password" screen instead of the main app (the recovery deep link
/// establishes a real, if recovery-scoped, session —
/// contracts/auth_repository_interface.md §4). Self-corrects back to
/// `false` as soon as any other auth event fires afterward — in particular,
/// [AuthRepository.confirmPasswordReset]'s internal global sign-out emits a
/// `signedOut` event once the reset completes, which naturally flips this
/// back off with no separate reset step needed.
final isPasswordRecoveryProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.valueOrNull?.event == AuthChangeEvent.passwordRecovery;
});
