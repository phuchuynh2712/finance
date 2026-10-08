import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance/core/database/app_database_provider.dart';
import 'package:finance/core/network/supabase_client_provider.dart';
import 'pull_service_provider.dart';
import 'sync_worker.dart';

/// Instantiated once (kept alive for the app's lifetime) by [FinanceApp]
/// watching this provider at the root of the widget tree — same pattern
/// as `appLifecycleObserverProvider`. Starts the periodic outbox drain
/// immediately; the offline-first contract (Offline-First Data & Sync)
/// requires this worker actually run, not merely exist as a class.
final syncWorkerProvider = Provider<SyncWorker>((ref) {
  final worker = SyncWorker(
    ref.watch(appDatabaseProvider),
    ref.watch(supabaseClientProvider),
    // A drain that leaves nothing waiting is a settled point at which the
    // derived balances can be checked against the server's (FR-018).
    onIdle: () => ref.read(reconciliationMonitorProvider).check(),
  );
  worker.start();
  ref.onDispose(worker.dispose);
  return worker;
});
