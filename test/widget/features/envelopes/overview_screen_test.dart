import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/features/envelopes/domain/envelope.dart';
import 'package:finance/features/envelopes/presentation/envelopes_providers.dart';
import 'package:finance/features/envelopes/presentation/overview_screen.dart';

Envelope _envelope(String id, int balance) => Envelope(
  id: id,
  userId: 'u1',
  name: id,
  allocationMethod: AllocationMethod.fixed,
  allocationValue: 100000,
  balance: balance,
  isRoundingReceiver: false,
);

Widget _harness(List<Envelope> envelopes) {
  return ProviderScope(
    overrides: [
      envelopesStreamProvider.overrideWith((ref) => Stream.value(envelopes)),
    ],
    child: MaterialApp(
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const OverviewScreen(),
    ),
  );
}

void main() {
  testWidgets(
    'flags only negative-balance envelopes with a warning icon (FR-020, SC-005)',
    (tester) async {
      await tester.pumpWidget(
        _harness([
          _envelope('Rent', 5000000),
          _envelope('Groceries', -100000),
          _envelope('Savings', 2000000),
          _envelope('Fun', -50000),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.alertTriangle), findsNWidgets(2));

      final groceriesTile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Groceries'),
          matching: find.byType(ListTile),
        ),
      );
      expect(groceriesTile.leading, isNotNull);

      final rentTile = tester.widget<ListTile>(
        find.ancestor(of: find.text('Rent'), matching: find.byType(ListTile)),
      );
      expect(rentTile.leading, isNull);
    },
  );

  testWidgets('shows no warning icons when all balances are non-negative', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness([_envelope('Rent', 5000000), _envelope('Savings', 2000000)]),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.alertTriangle), findsNothing);
  });
}
