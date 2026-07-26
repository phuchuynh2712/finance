import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/router/app_router.dart';

void main() {
  group('computeAuthRedirect', () {
    test('signed out, not on sign-in → redirects to sign-in', () {
      expect(
        computeAuthRedirect(isSignedIn: false, matchedLocation: '/overview'),
        '/sign-in',
      );
    });

    test('signed out, already on sign-in → no redirect', () {
      expect(
        computeAuthRedirect(isSignedIn: false, matchedLocation: '/sign-in'),
        isNull,
      );
    });

    test('signed in, on sign-in → redirects to overview', () {
      expect(
        computeAuthRedirect(isSignedIn: true, matchedLocation: '/sign-in'),
        '/overview',
      );
    });

    test('signed in, on a normal tab → no redirect', () {
      expect(
        computeAuthRedirect(isSignedIn: true, matchedLocation: '/spending'),
        isNull,
      );
    });

    test(
      'loading auth state (isSignedInProvider defaults false) behaves like signed-out — fails safe',
      () {
        // isSignedInProvider's own doc comment: "Defaults to false while the
        // initial auth state is still loading, so the router guard fails
        // safe (redirects to sign-in) rather than briefly allowing access."
        expect(
          computeAuthRedirect(isSignedIn: false, matchedLocation: '/account'),
          '/sign-in',
        );
      },
    );
  });
}
