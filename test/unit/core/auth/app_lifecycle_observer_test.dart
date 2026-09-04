import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/auth/app_lifecycle_observer.dart';

void main() {
  group('shouldRelockOnResume', () {
    final now = DateTime(2026, 9, 4, 12, 0, 0);

    test('not signed in → never relocks, regardless of elapsed time', () {
      expect(
        shouldRelockOnResume(
          lastBackgroundedAt: now.subtract(const Duration(hours: 1)),
          now: now,
          isSignedIn: false,
        ),
        isFalse,
      );
    });

    test('no recorded background timestamp → does not relock', () {
      expect(
        shouldRelockOnResume(
          lastBackgroundedAt: null,
          now: now,
          isSignedIn: true,
        ),
        isFalse,
      );
    });

    test(
      'backgrounded under 5 minutes → does not relock (quick app-switch)',
      () {
        expect(
          shouldRelockOnResume(
            lastBackgroundedAt: now.subtract(const Duration(minutes: 4)),
            now: now,
            isSignedIn: true,
          ),
          isFalse,
        );
      },
    );

    test(
      'backgrounded exactly 5 minutes → does not relock (boundary is exclusive)',
      () {
        expect(
          shouldRelockOnResume(
            lastBackgroundedAt: now.subtract(const Duration(minutes: 5)),
            now: now,
            isSignedIn: true,
          ),
          isFalse,
        );
      },
    );

    test('backgrounded over 5 minutes, signed in → relocks', () {
      expect(
        shouldRelockOnResume(
          lastBackgroundedAt: now.subtract(
            const Duration(minutes: 5, seconds: 1),
          ),
          now: now,
          isSignedIn: true,
        ),
        isTrue,
      );
    });

    test('backgrounded a long time (hours), signed in → relocks', () {
      expect(
        shouldRelockOnResume(
          lastBackgroundedAt: now.subtract(const Duration(hours: 2)),
          now: now,
          isSignedIn: true,
        ),
        isTrue,
      );
    });
  });
}
