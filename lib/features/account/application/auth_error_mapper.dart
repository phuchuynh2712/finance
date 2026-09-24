import 'package:supabase_flutter/supabase_flutter.dart';

/// Returns whether an authentication failure represents an already-registered
/// email during sign-up. SDK exception details stay outside presentation.
bool isDuplicateSignUpError(Object error) {
  return error is AuthApiException &&
      (error.code == 'email_exists' || error.code == 'user_already_exists');
}
