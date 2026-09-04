/// Plain-Dart registration validation rules, independent of Flutter so
/// they're unit-testable without a widget harness.
class SignUpValidation {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static const minPasswordLength = 6;

  /// Returns `true` only for a non-empty, correctly-formatted email — an
  /// empty string never matches the pattern, so this already enforces
  /// FR-006's "email is always required" rule with no separate empty-check
  /// needed.
  static bool isEmailValid(String email) => _emailPattern.hasMatch(email);

  /// Returns `true` if the password meets the minimum length requirement.
  static bool isPasswordValid(String password) =>
      password.length >= minPasswordLength;

  /// Returns `true` if the confirmation exactly matches the password.
  static bool isConfirmPasswordValid(String password, String confirmPassword) =>
      password == confirmPassword;
}
