import 'package:flutter/foundation.dart';

class AppEnvironment {
  AppEnvironment._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// FR-004: the fixed `https://` redirect Supabase sends a Web
  /// password-reset link to. Unused (and unvalidated) on other platforms
  /// — the mobile app keeps its own hardcoded deep-link scheme.
  static const webPasswordResetRedirectUrl = String.fromEnvironment(
    'WEB_PASSWORD_RESET_REDIRECT_URL',
  );

  static void validate() {
    final uri = Uri.tryParse(supabaseUrl);
    if (supabaseUrl.isEmpty ||
        uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty) {
      throw const FormatException('Invalid Supabase URL configuration.');
    }
    if (supabasePublishableKey.isEmpty) {
      throw const FormatException(
        'Missing Supabase publishable key configuration.',
      );
    }
    if (kIsWeb && !isValidWebRedirectUrl(webPasswordResetRedirectUrl)) {
      throw const FormatException(
        'Invalid or missing WEB_PASSWORD_RESET_REDIRECT_URL configuration.',
      );
    }
  }

  /// MUST be `https`, or `http` on exactly `localhost`/`127.0.0.1` — the
  /// same narrow loopback exemption OAuth redirect-URI validation
  /// commonly uses (e.g. RFC 8252 §7.3), needed because this project's
  /// own documented local Web dev workflow (README.md) runs at a fixed
  /// `http://localhost` origin, not `https`. Not private — [validate]'s
  /// own gate on this depends on the real `kIsWeb` (always false in a VM
  /// `flutter test` run), so tests exercise this rule directly instead.
  static bool isValidWebRedirectUrl(String value) {
    if (value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
    if (uri.scheme == 'https') return true;
    return uri.scheme == 'http' &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1');
  }
}
