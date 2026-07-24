abstract interface class ConnectionTestRepository {
  /// Performs a minimal round-trip call against Supabase to verify
  /// connectivity and credentials. Throws on failure.
  Future<void> checkConnection();
}
