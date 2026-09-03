import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/secure_local_storage.dart';

/// Initializes the Supabase SDK using credentials from `.env`.
///
/// MUST be awaited in `main()` before `runApp`. Throws if the required
/// environment variables are missing, so misconfiguration fails loudly
/// at startup instead of surfacing as an unexplained network error later.
Future<void> initSupabase() async {
  final url = dotenv.env['SUPABASE_URL'];
  final publishableKey = dotenv.env['SUPABASE_PUBLISHABLE_KEY'];

  if (url == null || url.isEmpty) {
    throw StateError('SUPABASE_URL is missing from .env');
  }
  if (publishableKey == null || publishableKey.isEmpty) {
    throw StateError('SUPABASE_PUBLISHABLE_KEY is missing from .env');
  }

  await Supabase.initialize(
    url: url,
    publishableKey: publishableKey,
    authOptions: const FlutterAuthClientOptions(
      localStorage: SecureLocalStorage(),
    ),
  );
}

/// Shared Supabase client, injected via Riverpod per the constitution's
/// Dependency Injection rule (no direct construction inside widgets).
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
