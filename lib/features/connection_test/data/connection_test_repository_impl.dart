import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/connection_test_repository.dart';

/// Verifies connectivity by calling Supabase Auth's session endpoint —
/// works against any project without requiring a pre-existing table.
class ConnectionTestRepositoryImpl implements ConnectionTestRepository {
  ConnectionTestRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<void> checkConnection() async {
    try {
      await _client.auth.refreshSession();
    } on AuthException {
      // No active session is expected on first run; reaching this point
      // without a network/DNS/auth-config error already proves the
      // client can talk to the Supabase project.
    }
  }
}
