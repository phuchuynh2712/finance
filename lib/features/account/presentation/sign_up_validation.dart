import 'package:finance/features/account/domain/password_policy.dart';

/// Plain-Dart registration validation rules, independent of Flutter so
/// they're unit-testable without a widget harness. The password rules live in
/// [PasswordPolicy], the one rule shared with the email reset and change
/// password.
class SignUpValidation {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Returns `true` only for a non-empty, correctly-formatted email — an
  /// empty string never matches the pattern, so this already enforces
  /// FR-006's "email is always required" rule with no separate empty-check
  /// needed.
  static bool isEmailValid(String email) => _emailPattern.hasMatch(email);

  /// Returns `true` if the password meets the app-wide minimum length
  /// ([PasswordPolicy.minLength], 8).
  static bool isPasswordValid(String password) =>
      PasswordPolicy.meetsMinimum(password);

  /// Returns `true` if the confirmation exactly matches the password.
  static bool isConfirmPasswordValid(String password, String confirmPassword) =>
      PasswordPolicy.matches(password, confirmPassword);
}
