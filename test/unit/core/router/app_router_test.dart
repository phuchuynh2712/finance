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

    test('signed out, on sign-up → no redirect', () {
      expect(
        computeAuthRedirect(isSignedIn: false, matchedLocation: '/sign-up'),
        isNull,
      );
    });

    test('signed in, on sign-in → redirects to overview', () {
      expect(
        computeAuthRedirect(isSignedIn: true, matchedLocation: '/sign-in'),
        '/overview',
      );
    });

    test('signed in, on sign-up → redirects to overview', () {
      expect(
        computeAuthRedirect(isSignedIn: true, matchedLocation: '/sign-up'),
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

    // FR-020/FR-021: the re-entry lock gate.
    test('signed in, locked, on a normal tab → redirects to sign-in', () {
      expect(
        computeAuthRedirect(
          isSignedIn: true,
          isLocked: true,
          matchedLocation: '/overview',
        ),
        '/sign-in',
      );
    });

    test('signed in, locked, already on sign-in → no redirect', () {
      expect(
        computeAuthRedirect(
          isSignedIn: true,
          isLocked: true,
          matchedLocation: '/sign-in',
        ),
        isNull,
      );
    });

    test(
      'signed in, unlocked (explicit isLocked: false), on sign-in → redirects to overview',
      () {
        expect(
          computeAuthRedirect(
            isSignedIn: true,
            isLocked: false,
            matchedLocation: '/sign-in',
          ),
          '/overview',
        );
      },
    );

    // FR-016: the password-recovery deep link takes priority over everything.
    test(
      'password recovery, not signed in, on a normal tab → redirects to reset-password',
      () {
        expect(
          computeAuthRedirect(
            isSignedIn: false,
            isPasswordRecovery: true,
            matchedLocation: '/overview',
          ),
          '/reset-password',
        );
      },
    );

    test(
      'password recovery, signed in and unlocked → still redirects to reset-password, not overview',
      () {
        expect(
          computeAuthRedirect(
            isSignedIn: true,
            isLocked: false,
            isPasswordRecovery: true,
            matchedLocation: '/overview',
          ),
          '/reset-password',
        );
      },
    );

    test('password recovery, already on reset-password → no redirect', () {
      expect(
        computeAuthRedirect(
          isSignedIn: true,
          isPasswordRecovery: true,
          matchedLocation: '/reset-password',
        ),
        isNull,
      );
    });
  });
}
