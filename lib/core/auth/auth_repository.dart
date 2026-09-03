import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The subset of auth operations the Account screen needs (FR-026).
/// Depending on this interface, rather than the concrete [AuthRepository]
/// directly, keeps Account's controller testable without a live Supabase
/// client.
abstract interface class AccountAuthActions {
  Future<void> updateAvatar(String avatarUrl);
  Future<void> changePassword(String newPassword);
  Future<void> signOut();
  Future<void> linkGoogleAccount();
  String? get linkedGoogleEmail;
}

/// The OAuth scope requested when authorizing a Google identity for
/// sign-in/linking — email is all this feature needs (matching the ID
/// token's own `email` claim), no additional Google API access.
const _googleAuthScopes = <String>['email'];

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

  /// Registers a new email/password account (FR-001, FR-004). [displayName]
  /// and [phoneNumber] are optional (FR-019) and, when provided, are stored
  /// via Supabase's `data:` metadata parameter — the same
  /// `raw_user_meta_data` mechanism [updateAvatar] already uses for
  /// `avatar_url`. [phoneNumber] is plain profile text with no OTP/SMS
  /// verification (FR-020). Returns `true` when the account needs email
  /// confirmation before it can sign in (`AuthResponse.session == null`) —
  /// the caller must show a "check your email" message rather than
  /// navigating into the app (FR-015, FR-021).
  Future<bool> signUp({
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
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: metadata.isEmpty ? null : metadata,
    );
    return response.session == null;
  }

  /// Resends the confirmation email for an unconfirmed account (FR-023).
  Future<void> resendConfirmationEmail(String email) async {
    await _client.auth.resend(email: email, type: OtpType.signup);
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

  /// Signs in via native Google ID token (FR-005, FR-006, FR-007, FR-008).
  /// If the Google account's email matches an existing password-based
  /// account, Supabase's server automatically links and signs into that
  /// account — this method does not branch on that case itself; whatever
  /// account signInWithIdToken resolves to is correct and safe by
  /// construction, since Supabase evicts any unconfirmed prior identity on
  /// that account as part of the same server-side operation (research.md
  /// §6). Throws [GoogleSignInException] with code `canceled` if the user
  /// dismisses the account chooser (FR-009) — callers should treat that as a
  /// silent no-op, not an error.
  Future<void> signInWithGoogle() async {
    final tokens = await _authenticateWithGoogle();
    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: tokens.idToken,
      accessToken: tokens.accessToken,
    );
  }

  /// Links a Google account to the CURRENTLY signed-in user (FR-016) — used
  /// for a Google account whose email differs from the signed-in account's
  /// email (automatic linking already covers the matching-email case via
  /// [signInWithGoogle]). Throws an [AuthApiException] with code
  /// `identity_already_exists` if the Google identity belongs to a
  /// different account (FR-017).
  @override
  Future<void> linkGoogleAccount() async {
    final tokens = await _authenticateWithGoogle();
    await _client.auth.linkIdentityWithIdToken(
      provider: OAuthProvider.google,
      idToken: tokens.idToken,
      accessToken: tokens.accessToken,
    );
  }

  /// Returns the linked Google account's email, or null if none linked
  /// (FR-018).
  @override
  String? get linkedGoogleEmail {
    final identities = _client.auth.currentUser?.identities;
    if (identities == null) return null;
    for (final identity in identities) {
      if (identity.provider == 'google') {
        return identity.identityData?['email'] as String?;
      }
    }
    return null;
  }

  /// The shared native Google authentication + authorization step
  /// (research.md §2) used by both [signInWithGoogle] and
  /// [linkGoogleAccount]: `authenticate()` for the interactive account
  /// chooser, then `authorizationForScopes()` (falling back to
  /// `authorizeScopes()` if null) to obtain the access token alongside the
  /// ID token.
  Future<({String idToken, String accessToken})>
  _authenticateWithGoogle() async {
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: 'Google Sign-In returned no ID token.',
      );
    }

    final authClient = account.authorizationClient;
    final authorization =
        await authClient.authorizationForScopes(_googleAuthScopes) ??
        await authClient.authorizeScopes(_googleAuthScopes);

    return (idToken: idToken, accessToken: authorization.accessToken);
  }
}
