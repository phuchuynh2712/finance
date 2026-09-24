import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/config/app_environment.dart';
import 'package:finance/core/storage/secure_local_storage.dart';

/// Initializes the Supabase SDK using public build-time configuration.
///
/// `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` are passed through
/// `--dart-define` or `--dart-define-from-file`; no `.env` file is bundled in
/// web builds. MUST be awaited in `main()` before `runApp`.
Future<void> initSupabase() async {
  AppEnvironment.validate();

  await Supabase.initialize(
    url: AppEnvironment.supabaseUrl,
    publishableKey: AppEnvironment.supabasePublishableKey,
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
