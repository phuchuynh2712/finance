import 'package:finance/core/sync/initial_pull_complete_provider.dart';

/// A `ProviderScope`/`ProviderContainer` override that makes
/// `initialPullCompleteProvider` resolve to `true` immediately — for
/// widget tests that exercise a screen's own data/empty/error handling
/// and are not themselves testing FR-011's pull-in-progress loading state
/// (those tests, e.g. `transaction_history_screen_test.dart`'s FR-011
/// cases, override `initialPullCompleteProvider` directly with the value
/// they need instead of using this constant).
///
/// Without this override, every screen consuming `initialPullCompleteProvider`
/// sees it in its default `AsyncLoading` state (no `PullCursor` row exists
/// in a fresh in-memory test database) and correctly renders FR-011's
/// loading state forever — which is production-correct behavior, but
/// causes `pumpAndSettle()` to time out in any test that doesn't otherwise
/// care about the pull-loading distinction and just wants to see the
/// screen's normal data/empty/error UI.
final pullCompleteOverride = initialPullCompleteProvider.overrideWith(
  (ref) => Stream.value(true),
);
