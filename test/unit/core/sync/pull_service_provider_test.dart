import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/database/app_database_provider.dart';
import 'package:finance/core/sync/pull_service.dart';
import 'package:finance/core/sync/pull_service_provider.dart';

/// A no-op subscribe closure — none of these tests need to observe live
/// events/reconnects, only that a PullService gets constructed and
/// started (or not) for the right userId.
Future<void> Function() _noopSubscribe(
  List<String> tables,
  void Function(String table, Map<String, dynamic> row) onEvent,
  void Function() onReady,
) {
  return () async {};
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  ProviderContainer buildContainer({
    required bool signedIn,
    required String userId,
    required List<String> startedForUserIds,
  }) {
    return ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        isSignedInProvider.overrideWithValue(signedIn),
        currentUserIdProvider.overrideWithValue(userId),
        pullServiceFactoryProvider.overrideWithValue((db, userId) {
          startedForUserIds.add(userId);
          return PullService(
            db,
            userId: userId,
            subscribe: _noopSubscribe,
            fetchBatch: (table, userId, cursor) async => const [],
          );
        }),
      ],
    );
  }

  test('a signed-in state (fresh sign-in or cold-start-with-session, '
      'indistinguishable at this provider — see its own doc) starts a pull '
      'for that user', () async {
    final startedForUserIds = <String>[];
    final container = buildContainer(
      signedIn: true,
      userId: 'user-a',
      startedForUserIds: startedForUserIds,
    );
    addTearDown(container.dispose);

    final service = container.read(pullServiceProvider);

    expect(service, isNotNull);
    expect(startedForUserIds, ['user-a']);
  });

  test('a signed-out state does not start any pull', () async {
    final startedForUserIds = <String>[];
    final container = buildContainer(
      signedIn: false,
      userId: 'user-a', // irrelevant while signed out
      startedForUserIds: startedForUserIds,
    );
    addTearDown(container.dispose);

    final service = container.read(pullServiceProvider);

    expect(service, isNull);
    expect(startedForUserIds, isEmpty);
  });

  test('a sign-out followed by a different user signing in starts a NEW '
      'pull scoped to the new userId (confirms non-reuse of '
      "AppLockNotifier's \"only the first event ever\" guard)", () async {
    final startedForUserIds = <String>[];
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        isSignedInProvider.overrideWithValue(true),
        currentUserIdProvider.overrideWithValue('user-a'),
        pullServiceFactoryProvider.overrideWithValue((db, userId) {
          startedForUserIds.add(userId);
          return PullService(
            db,
            userId: userId,
            subscribe: _noopSubscribe,
            fetchBatch: (table, userId, cursor) async => const [],
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    final firstService = container.read(pullServiceProvider);
    expect(startedForUserIds, ['user-a']);

    // Sign out, then a DIFFERENT user signs in — both overrides change,
    // simulating the real authStateChangesProvider emitting a new
    // session for a different user.
    container.updateOverrides([
      appDatabaseProvider.overrideWithValue(db),
      isSignedInProvider.overrideWithValue(true),
      currentUserIdProvider.overrideWithValue('user-b'),
      pullServiceFactoryProvider.overrideWithValue((db, userId) {
        startedForUserIds.add(userId);
        return PullService(
          db,
          userId: userId,
          subscribe: _noopSubscribe,
          fetchBatch: (table, userId, cursor) async => const [],
        );
      }),
    ]);

    final secondService = container.read(pullServiceProvider);

    expect(startedForUserIds, ['user-a', 'user-b']);
    expect(secondService, isNot(same(firstService)));
  });
}
