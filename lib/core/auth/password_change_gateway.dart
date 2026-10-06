/// The slice of Supabase Auth that changing a signed-in person's password
/// needs, behind an interface so the sequence in `ChangePasswordService` is
/// unit-testable with fakes and no live client.
///
/// [AuthRepository] implements it. The current password is verified on a
/// short-lived temporary session reached over plain REST (no second
/// `GoTrueClient`), so the app's own session, router, lock and sync never see
/// a second sign-in (research.md Decision 1).
///
/// Server behavior this design is built around (verified against the real
/// service): updating a password revokes every OTHER session of the account and
/// keeps only the session that performed the update. So the temporary session
/// is handed to the app afterwards ([VerifiedPasswordSession.continueOnThisDevice])
/// or this device would be signed out too.
abstract interface class PasswordChangeGateway {
  /// Refreshes THIS device's own session against the service. Throws when the
  /// session has been revoked or has expired, in which case nothing may be
  /// changed. Also leaves this device with a fresh access token for
  /// [endOtherSessions].
  Future<void> ensureSessionActive();

  /// Signs a temporary session in with the current password.
  /// Throws `AuthApiException(code: 'invalid_credentials')` if it is wrong.
  Future<VerifiedPasswordSession> verifyCurrentPassword(String currentPassword);

  /// Ends every session of the account except this device's. Never silently a
  /// no-op: throws `AuthSessionMissingException` when this device has no live
  /// access token (the SDK would otherwise ignore the resulting 401 and report
  /// success).
  Future<void> endOtherSessions();
}

/// A temporary session created by [PasswordChangeGateway.verifyCurrentPassword]
/// that can set the new password and is then thrown away.
abstract interface class VerifiedPasswordSession {
  /// Sets the new password on the temporary, freshly signed-in session (which
  /// also satisfies Supabase's "secure password change" recency rule). The
  /// server revokes every other session of the account as part of this.
  Future<void> setNewPassword(String newPassword);

  /// Hands this session to the app's own client so THIS device keeps a valid
  /// session after the server revoked its old one. Throws if the app cannot
  /// take it over; the caller then [close]s the session.
  Future<void> continueOnThisDevice();

  /// Revokes the temporary session (scope local) unless it was handed to the
  /// app, and frees its resources. Idempotent; never throws to the caller.
  Future<void> close();
}
