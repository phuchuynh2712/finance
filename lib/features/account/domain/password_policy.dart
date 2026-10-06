/// The app-wide rule for a password the person is *setting* (sign-up, the
/// email reset and change password). Sign-in never calls it: checking length
/// there would only lock out an existing account.
///
/// Pure Dart on purpose — no Flutter, Supabase or Riverpod import — so the
/// rule is unit-testable and the architecture test keeps `domain/` clean.
class PasswordPolicy {
  PasswordPolicy._();

  /// The single source of truth for the minimum length. The Supabase project's
  /// own minimum is set to the same value in its dashboard (an external owner
  /// setting), so the rule cannot be bypassed from another client.
  static const minLength = 8;

  /// Whether [password] is long enough. Length is counted in Unicode code
  /// points exactly as typed: no trimming and no composition rules, so an
  /// accented Vietnamese letter or an emoji counts as one character.
  static bool meetsMinimum(String password) =>
      password.runes.length >= minLength;

  /// Whether the new password differs from the current one.
  static bool differs(String current, String candidate) => current != candidate;

  /// Whether the confirmation exactly matches the password.
  static bool matches(String a, String b) => a == b;
}
