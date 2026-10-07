import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/auth/app_lock_policy.dart';

/// Contract `contracts/inactivity-lock.md` §1 and §5 (FR-001, FR-004).
void main() {
  final now = DateTime(2026, 10, 7, 12);

  bool shouldLock(
    Duration idle, {
    bool signedIn = true,
    bool locked = false,
    DateTime? last,
  }) => AppLockPolicy.shouldLock(
    lastActivityAt: last ?? now.subtract(idle),
    now: now,
    isSignedIn: signedIn,
    isLocked: locked,
  );

  group('shouldLock', () {
    test('locks at exactly 5 minutes and after, not before', () {
      expect(shouldLock(const Duration(minutes: 4, seconds: 59)), isFalse);
      expect(shouldLock(const Duration(minutes: 5)), isTrue);
      expect(shouldLock(const Duration(minutes: 5, seconds: 1)), isTrue);
      expect(shouldLock(const Duration(hours: 3)), isTrue);
    });

    test('signed out → never', () {
      expect(shouldLock(const Duration(hours: 1), signedIn: false), isFalse);
    });

    test('already locked → no second lock', () {
      expect(shouldLock(const Duration(hours: 1), locked: true), isFalse);
    });

    test('no activity recorded yet → does not lock', () {
      expect(
        AppLockPolicy.shouldLock(
          lastActivityAt: null,
          now: now,
          isSignedIn: true,
          isLocked: false,
        ),
        isFalse,
      );
    });

    test('a last activity in the future (clock moved back) counts as now', () {
      expect(
        shouldLock(Duration.zero, last: now.add(const Duration(hours: 2))),
        isFalse,
      );
    });

    test('an explicit period replaces the default', () {
      expect(
        AppLockPolicy.shouldLock(
          lastActivityAt: now.subtract(const Duration(seconds: 20)),
          now: now,
          isSignedIn: true,
          isLocked: false,
          period: const Duration(seconds: 20),
        ),
        isTrue,
      );
    });
  });

  group('the period (FR-004)', () {
    test('the default is 5 minutes', () {
      expect(AppLockPolicy.defaultInactivityPeriod, const Duration(minutes: 5));
    });

    test('without an override the build uses the default', () {
      expect(
        AppLockPolicy.resolvePeriod(isRelease: false, overrideSeconds: 0),
        const Duration(minutes: 5),
      );
    });

    test('a non-release build accepts INACTIVITY_LOCK_SECONDS', () {
      expect(
        AppLockPolicy.resolvePeriod(isRelease: false, overrideSeconds: 20),
        const Duration(seconds: 20),
      );
    });

    test('a release build ignores it: the override can never ship', () {
      expect(
        AppLockPolicy.resolvePeriod(isRelease: true, overrideSeconds: 5),
        const Duration(minutes: 5),
      );
    });

    test('a negative override is ignored', () {
      expect(
        AppLockPolicy.resolvePeriod(isRelease: false, overrideSeconds: -3),
        const Duration(minutes: 5),
      );
    });

    test('the period in force for the test build is the default', () {
      expect(AppLockPolicy.inactivityPeriod, const Duration(minutes: 5));
    });
  });
}
