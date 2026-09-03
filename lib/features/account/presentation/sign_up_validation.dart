/// Plain-Dart registration validation rules (FR-002), independent of Flutter
/// so they're unit-testable without a widget harness.
class SignUpValidation {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static const minPasswordLength = 6;

  /// Returns an error message key, or `null` if the email is valid.
  static bool isEmailValid(String email) => _emailPattern.hasMatch(email);

  /// Returns `true` if the password meets the minimum length requirement.
  static bool isPasswordValid(String password) =>
      password.length >= minPasswordLength;

  /// Returns `true` if the confirmation exactly matches the password.
  static bool isConfirmPasswordValid(String password, String confirmPassword) =>
      password == confirmPassword;
}
