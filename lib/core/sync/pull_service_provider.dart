import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/database/app_database_provider.dart';
import 'package:finance/core/network/supabase_client_provider.dart';
import 'pull_service.dart';
import 'reconciliation_monitor.dart';
import 'sync_notices_provider.dart';

/// Builds a [PullService] for [userId] against [db] — the real Supabase
/// wiring by default. Overridable in tests so [pullServiceProvider] can be
/// exercised without a live Supabase connection, the same rationale as
/// [PullService]'s own injectable `subscribe`/`fetchBatch` (contracts/
/// pull-write-helper.md's precedent): a test overrides this provider with
/// a factory that returns a [PullService] built from fake `subscribe`/
/// `fetchBatch` closures instead of a real [SupabaseClient].
final pullServiceFactoryProvider =
    Provider<PullService Function(AppDatabase db, String userId)>((ref) {
      final client = ref.watch(supabaseClientProvider);
      return (db, userId) => PullService(
        db,
        client: client,
        userId: userId,
        // A catch-up pull that ran to its end is a settled point at which the
        // derived balances can be checked against the server's (FR-018).
        onCaughtUp: () =>
            unawaited(ref.read(reconciliationMonitorProvider).check()),
      );
    });

/// The active [PullService] for the currently signed-in user, or `null`
/// while signed out. Rebuilds automatically whenever [currentUserIdProvider]
/// changes — this is what makes this provider fire for BOTH of FR-001's
/// triggering cases without special-casing either:
///
/// (a) A fresh sign-in while the app is running: [authStateChangesProvider]
///     emits a new session, [currentUserIdProvider] changes value, Riverpod
///     disposes the old build (there is none yet, or a prior user's) and
///     runs this one again for the new `userId`.
/// (b) A cold launch with an already-persisted session: [currentUserIdProvider]
///     already resolves to a real `userId` the very first time anything
///     reads it — no special "was this the first-ever auth event" branch is
///     needed, unlike `AppLockNotifier`'s `fireImmediately`-based pattern
///     (`auth_state_provider.dart`) — this provider simply reads whatever
///     `currentUserIdProvider` currently is, whenever it's first watched.
///
/// A sign-out (or a switch to a different user) disposes the previous
/// [PullService] (via `ref.onDispose`, which calls `.stop()`) before this
/// provider rebuilds for the new user — so a stale pull for the WRONG user
/// is never left running, and a new user's pull is always scoped to their
/// own `userId` from the start (research.md §0's explicit non-reuse of
/// `AppLockNotifier`'s "only the first event this app instance ever sees"
/// guard, which would incorrectly suppress this for a second sign-in).
final pullServiceProvider = Provider<PullService?>((ref) {
  if (!ref.watch(isSignedInProvider)) return null;

  final userId = ref.watch(currentUserIdProvider);
  final buildService = ref.watch(pullServiceFactoryProvider);
  final service = buildService(ref.watch(appDatabaseProvider), userId);
  service.start();
  ref.onDispose(() {
    // Fire-and-forget: `stop()` is async (Realtime channel teardown), but
    // disposal itself is synchronous — there's nothing further for this
    // provider to do once dispose starts, and a new PullService for a
    // different user is safe to start concurrently with the old one's
    // teardown (research.md Decision 7's outbox-bypass makes overlapping
    // writes for two different users' rows a non-issue: each write is
    // scoped by its own row's userId, never cross-user).
    service.stop();
  });
  return service;
});

/// Compares each item's derived balance with the one the server reports and
/// tells the person when they still differ after one new synchronisation
/// (FR-018, research.md Decision 10). Lives with the pull service because its
/// remedy is [PullService.resync] on the current user's service, read lazily
/// so the two providers never wait for each other.
final Provider<ReconciliationMonitor> reconciliationMonitorProvider =
    Provider<ReconciliationMonitor>((ref) {
      final monitor = ReconciliationMonitor.forDatabase(
        ref.watch(appDatabaseProvider),
        ref.watch(syncNoticesProvider),
        resync: () async {
          final pull = ref.read(pullServiceProvider);
          if (pull == null) return false; // signed out: nothing to synchronise
          await pull.resync();
          return true;
        },
      );
      ref.onDispose(monitor.dispose);
      return monitor;
    });
