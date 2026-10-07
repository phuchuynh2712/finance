import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/l10n/app_localizations.dart';

import '../../../support/expense_control_fixtures.dart';
import '../../../support/expense_screen_harness.dart';

Future<void> _resize(WidgetTester tester, double w, double h) async {
  tester.view.physicalSize = Size(w, h);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'S1: amount, chosen account and banner survive 1440 → 410 → 1440',
    (tester) async {
      await pumpExpenseScreen(
        tester,
        width: 1440,
        height: 900,
        items: accounts(5),
      );
      await tapDigits(tester, '1500');
      await tester.tap(chip('a2'));
      await tester.pump();
      expect(amountText(tester), contains('1.500'));
      expect(previewBanner(), findsOneWidget);

      for (final (w, h) in [(410.0, 864.0), (1440.0, 900.0), (700.0, 700.0)]) {
        await _resize(tester, w, h);
        expect(amountText(tester), contains('1.500'), reason: '$w×$h');
        expect(previewBanner(), findsOneWidget, reason: '$w×$h');
        // The chosen account is still the one the banner talks about.
        expect(bannerText(tester), contains('Ví 2'), reason: '$w×$h');
      }
    },
  );

  testWidgets('S1: the chosen account is still the one that gets saved', (
    tester,
  ) async {
    final repository = await pumpExpenseScreenPushed(
      tester,
      width: 1440,
      height: 900,
      items: accounts(5),
    );
    await tapDigits(tester, '1500');
    await tester.tap(chip('a4'));
    await tester.pump();
    await _resize(tester, 410, 864);
    await _resize(tester, 1440, 900);
    await tester.tap(find.bySubtype<FilledButton>().last);
    await tester.pumpAndSettle();
    expect(repository.lastItemId, 'a4');
    expect(repository.lastAmount, 1500);
  });

  testWidgets('S2: the scan mode survives a resize across 600', (tester) async {
    await pumpExpenseScreen(tester, width: 1440, height: 900);
    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
    await tester.tap(find.text(l10n.expenseTabScan));
    await tester.pumpAndSettle();
    expect(keypadKey('1'), findsNothing);

    await _resize(tester, 410, 864);
    expect(keypadKey('1'), findsNothing);
    expect(find.text(l10n.expenseScanCaptureAction), findsOneWidget);

    await _resize(tester, 1440, 900);
    expect(keypadKey('1'), findsNothing);
    expect(find.text(l10n.expenseScanCaptureAction), findsOneWidget);
  });

  testWidgets('S3: widening a scrolled short window does not throw', (
    tester,
  ) async {
    await pumpExpenseScreen(
      tester,
      width: 1000,
      height: 500,
      items: accounts(8),
    );
    mainScrollPosition(tester).jumpTo(60);
    await tester.pump();
    await _resize(tester, 1440, 900);
    expect(tester.takeException(), isNull);
    // Everything fits again: the scroll offset clamped back to 0.
    expect(mainScrollPosition(tester).pixels, 0);
  });

  testWidgets('crossing the 500dp pin threshold keeps the typed amount', (
    tester,
  ) async {
    await pumpExpenseScreen(
      tester,
      width: 1000,
      height: 700,
      items: accounts(4),
    );
    await tapDigits(tester, '42');
    await _resize(tester, 1000, 450);
    expect(amountText(tester), contains('42'));
    await _resize(tester, 1000, 700);
    expect(amountText(tester), contains('42'));
    expect(tester.takeException(), isNull);
  });
}
