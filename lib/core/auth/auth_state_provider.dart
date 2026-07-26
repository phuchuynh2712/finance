import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/supabase_client_provider.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
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
