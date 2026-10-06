import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/router/app_router.dart';

Session _session() => Session(
  accessToken: 'access-token',
  tokenType: 'bearer',
  refreshToken: 'refresh-token',
  expiresIn: 3600,
  user: const User(
    id: 'user-1',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-10-06T00:00:00Z',
  ),
);

/// Regression for "the first sign-in press does nothing, the second one
/// navigates": GoRouter re-runs its redirect when the refresh listenable
/// fires, and the redirect reads [isSignedInProvider]. If the listenable
/// fires before that derived provider has caught up with the auth event, the
/// redirect still sees "signed out" and the user stays on the sign-in screen.
void main() {
  group('router refresh timing', () {
    late StreamController<AuthState> auth;
    late ProviderContainer container;

    setUp(() {
      auth = StreamController<AuthState>.broadcast();
      container = ProviderContainer(
        overrides: [
          authStateChangesProvider.overrideWith((ref) => auth.stream),
        ],
      );
      // The running app has already evaluated the redirect once (signed
      // out) before the user can press the button, so the derived provider
      // exists and holds `false`.
      expect(container.read(isSignedInProvider), isFalse);
    });

    tearDown(() async {
      container.dispose();
      await auth.close();
    });

    test(
      'a sign-in event refreshes the router with isSignedIn already true',
      () async {
        final seenAtRefresh = <bool>[];
        container
            .read(routerRefreshListenableProvider)
            .addListener(
              () => seenAtRefresh.add(container.read(isSignedInProvider)),
            );

        auth.add(AuthState(AuthChangeEvent.signedIn, _session()));
        await pumpEventQueue();

        expect(
          seenAtRefresh,
          isNotEmpty,
          reason: 'the router must be refreshed',
        );
        expect(
          seenAtRefresh.last,
          isTrue,
          reason:
              'the last refresh must see the signed-in state, otherwise the '
              'redirect to the main screen is skipped until a second sign-in',
        );
      },
    );

    test(
      'a sign-out event refreshes the router with isSignedIn already false',
      () async {
        auth.add(AuthState(AuthChangeEvent.signedIn, _session()));
        await pumpEventQueue();
        // The running app has evaluated the redirect while signed in, so the
        // derived provider is cached as `true` before the sign-out arrives.
        expect(container.read(isSignedInProvider), isTrue);

        final seenAtRefresh = <bool>[];
        container
            .read(routerRefreshListenableProvider)
            .addListener(
              () => seenAtRefresh.add(container.read(isSignedInProvider)),
            );

        auth.add(const AuthState(AuthChangeEvent.signedOut, null));
        await pumpEventQueue();

        expect(seenAtRefresh, isNotEmpty);
        expect(seenAtRefresh.last, isFalse);
      },
    );
  });
}
