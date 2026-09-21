import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/auth_state_provider.dart';

class AccountController {
  AccountController(this._repository);

  final AccountAuthActions _repository;

  Future<void> signOut() => _repository.signOut();
}

/// Narrower than [authRepositoryProvider] on purpose: overriding this in
/// tests only requires a fake [AccountAuthActions], not the full
/// [AuthRepository] contract (which needs a live [SupabaseClient] to
/// construct).
final accountAuthActionsProvider = Provider<AccountAuthActions>((ref) {
  return ref.watch(authRepositoryProvider);
});

final accountControllerProvider = Provider.autoDispose<AccountController>((
  ref,
) {
  return AccountController(ref.watch(accountAuthActionsProvider));
});
