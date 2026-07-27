import 'package:supabase_flutter/supabase_flutter.dart';

/// The subset of auth operations the Account screen needs (FR-026).
/// Depending on this interface, rather than the concrete [AuthRepository]
/// directly, keeps Account's controller testable without a live Supabase
/// client.
abstract interface class AccountAuthActions {
  Future<void> updateAvatar(String avatarUrl);
  Future<void> changePassword(String newPassword);
  Future<void> signOut();
}

/// Wraps Supabase Auth for the Budget Envelopes feature's Account/sign-in
/// flows. Email+password is the only supported method (research.md §5) —
/// FR-026 requires in-app password change, which only makes sense for a
/// password-based credential.
class AuthRepository implements AccountAuthActions {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp({required String email, required String password}) async {
    await _client.auth.signUp(email: email, password: password);
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<void> changePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  @override
  Future<void> updateAvatar(String avatarUrl) async {
    await _client.auth.updateUser(
      UserAttributes(data: {'avatar_url': avatarUrl}),
    );
  }

  String? get currentAvatarUrl =>
      _client.auth.currentUser?.userMetadata?['avatar_url'] as String?;
}
