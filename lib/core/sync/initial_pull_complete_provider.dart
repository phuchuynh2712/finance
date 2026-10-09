import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/database/app_database_provider.dart';
import 'package:finance/core/sync/pull_service.dart';

/// Whether the signed-in user's initial catch-up pull has completed for
/// EVERY syncable table (research.md Decision 6) — the logical AND across
/// `PullCursor.initialPullCompleted` rows, not just one table. Screens
/// consume this to distinguish "still pulling" from "genuinely empty"
/// (FR-011): `if (!(ref.watch(initialPullCompleteProvider).valueOrNull ??
/// false)) return const Center(child: CircularProgressIndicator()); return
/// existingStreamProvider.when(...)`. Per explicit user direction, this
/// reuses the existing `Center(child: CircularProgressIndicator())`
/// convention every screen in this app already uses for its own loading
/// states — this codebase has no skeleton-shaped widget anywhere, so
/// introducing one would be a new pattern, not a reuse of an existing one
/// (constitution's "loading states... MUST follow the same reusable
/// patterns across the app").
///
/// A `StreamProvider`, not a plain `Provider` — this must update reactively
/// as the pull progresses (each table's `PullCursor` row is written batch
/// by batch, research.md Decision 4/5), not just be read once at screen
/// build time. Built on Drift's own `.watch()` so it re-emits automatically
/// whenever any `PullCursor` row for this user changes, the same reactive
/// convention every other screen-facing stream in this app already uses
/// (`ExpenseControlRepositoryImpl`'s `watchAll()` etc.).
final initialPullCompleteProvider = StreamProvider<bool>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final userId = ref.watch(currentUserIdProvider);

  return (db.select(
    db.pullCursor,
  )..where((t) => t.userId.equals(userId))).watch().map((rows) {
    // No PullCursor rows yet at all (pull hasn't started/committed its
    // first batch for either table) — not complete.
    if (rows.isEmpty) return false;

    final completedByTable = {
      for (final row in rows) row.syncTableName: row.initialPullCompleted,
    };
    // Every syncable table must have a row AND be marked complete — a
    // table with no row yet is exactly as "not done" as one with a row
    // whose initialPullCompleted is still false.
    return syncableTables.every((table) => completedByTable[table] ?? false);
  });
});
