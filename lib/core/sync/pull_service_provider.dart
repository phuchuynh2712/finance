import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/database/app_database_provider.dart';
import 'package:finance/core/network/supabase_client_provider.dart';
import 'pull_service.dart';

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
      return (db, userId) => PullService(db, client: client, userId: userId);
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
