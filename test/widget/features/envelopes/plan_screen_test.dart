import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/features/envelopes/domain/allocation_event.dart';
import 'package:finance/features/envelopes/domain/allocation_event_line.dart';
import 'package:finance/features/envelopes/domain/allocation_repository.dart';
import 'package:finance/features/envelopes/domain/envelope.dart';
import 'package:finance/features/envelopes/presentation/envelopes_providers.dart';
import 'package:finance/features/envelopes/presentation/plan_screen.dart';

class _FakeAllocationRepository implements AllocationRepository {
  bool confirmed = false;

  @override
  Future<void> confirmEvent({
    required AllocationEvent event,
    required List<AllocationEventLine> lines,
  }) async {
    confirmed = true;
  }
}

Envelope _fixed(String id, int amount) => Envelope(
  id: id,
  userId: 'u1',
  name: id,
  allocationMethod: AllocationMethod.fixed,
  allocationValue: amount.toDouble(),
  balance: 0,
  isRoundingReceiver: false,
);

Envelope _percentage(
  String id,
  double fraction, {
  bool isRoundingReceiver = false,
}) => Envelope(
  id: id,
  userId: 'u1',
  name: id,
  allocationMethod: AllocationMethod.percentage,
  allocationValue: fraction,
  balance: 0,
  isRoundingReceiver: isRoundingReceiver,
);

Widget _harness({
  required List<Envelope> envelopes,
  required AllocationRepository allocationRepository,
}) {
  return ProviderScope(
    overrides: [
      envelopesStreamProvider.overrideWith((ref) => Stream.value(envelopes)),
      allocationRepositoryProvider.overrideWithValue(allocationRepository),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
    child: MaterialApp(
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // Mirrors production: Overview already watches envelopesStreamProvider
      // and has it resolved to AsyncData before its Plan action is even
      // reachable, so this Consumer warms the stream up the same way before
      // the test taps through to PlanScreen.
      home: Consumer(
        builder: (context, ref, _) {
          ref.watch(envelopesStreamProvider);
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const PlanScreen())),
                child: const Text('open plan'),
              ),
            ),
          );
        },
      ),
    ),
  );
}

void main() {
  testWidgets('shows the allocation preview once a valid income is entered', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        envelopes: [
          _fixed('Rent', 5000000),
          _percentage('Savings', 0.30),
          _percentage('Buffer', 0.0, isRoundingReceiver: true),
        ],
        allocationRepository: _FakeAllocationRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open plan'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '20000000');
    await tester.pump();

    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('Savings'), findsOneWidget);
    expect(find.text('Buffer'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets(
    'disables confirm and shows a warning when over-allocated (FR-011a)',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          envelopes: [
            _fixed('Rent', 5000000),
            _percentage('Savings', 0.60, isRoundingReceiver: true),
          ],
          allocationRepository: _FakeAllocationRepository(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open plan'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '5000000');
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    },
  );

  testWidgets('confirming calls the repository and returns to the caller', (
    tester,
  ) async {
    final fakeRepo = _FakeAllocationRepository();
    await tester.pumpWidget(
      _harness(
        envelopes: [_percentage('Buffer', 1.0, isRoundingReceiver: true)],
        allocationRepository: fakeRepo,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open plan'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '1000000');
    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(fakeRepo.confirmed, isTrue);
    expect(find.byType(PlanScreen), findsNothing);
  });
}
