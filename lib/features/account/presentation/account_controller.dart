import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/auth_state_provider.dart';

class AccountController extends StateNotifier<bool> {
  AccountController(this._repository) : super(false);

  final AccountAuthActions _repository;

  /// State is `true` while a sign-out request is in flight, so the UI can
  /// show a spinner and block double-taps on the sign-out row.
  Future<void> signOut() async {
    if (state) return;
    state = true;
    try {
      await _repository.signOut();
    } finally {
      if (mounted) state = false;
    }
  }
}

/// Narrower than [authRepositoryProvider] on purpose: overriding this in
/// tests only requires a fake [AccountAuthActions], not the full
/// [AuthRepository] contract (which needs a live [SupabaseClient] to
/// construct).
final accountAuthActionsProvider = Provider<AccountAuthActions>((ref) {
  return ref.watch(authRepositoryProvider);
});

final accountControllerProvider =
    StateNotifierProvider.autoDispose<AccountController, bool>((ref) {
      return AccountController(ref.watch(accountAuthActionsProvider));
    });
