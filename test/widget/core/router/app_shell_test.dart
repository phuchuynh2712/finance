import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/router/app_router.dart';

/// Structural verification of the bottom navigation (FR-020, spec.md US4
/// Acceptance Scenarios 1–4) — inspects the real [appRouterProvider]'s
/// route tree directly rather than rendering the full widget shell, since
/// the account screen's dependency chain reaches a concrete
/// Supabase-backed repository that can't be safely faked without also
/// initializing Supabase. This still exercises the production router
/// construction and its exact branch/path list — the part that was
/// actually broken before (I1: the old `/envelopes` branch left in place,
/// yielding 6 tabs instead of 5).
void main() {
  test(
    'the shell has exactly 5 branches, in order, and the old /envelopes branch is gone',
    () {
      final container = ProviderContainer(
        overrides: [
          // Sidesteps every auth/lock provider touching Supabase — they
          // all derive solely from this stream (verified in
          // auth_state_provider.dart).
          authStateChangesProvider.overrideWith((ref) => const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      final shellRoute = router.configuration.routes
          .whereType<StatefulShellRoute>()
          .single;

      final paths = [
        for (final branch in shellRoute.branches)
          (branch.routes.single as GoRoute).path,
      ];

      expect(paths, [
        '/overview',
        '/expense-control',
        '/spending',
        '/history',
        '/account',
      ]);
      expect(paths, isNot(contains('/envelopes')));
    },
  );
}
