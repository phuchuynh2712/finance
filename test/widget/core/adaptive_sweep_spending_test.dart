import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/features/expense_control/presentation/expense_control_screen.dart';
import 'package:finance/features/expense_control/presentation/widgets/expense_group_card.dart';
import 'package:finance/features/expenses/presentation/expense_screen.dart';
import 'package:finance/features/expenses/presentation/income_screen.dart';
import 'package:finance/features/expenses/presentation/spending_screen.dart';
import 'package:finance/features/expenses/presentation/widgets/balance_group_card.dart';

import '../../support/adaptive_sweep.dart';
import '../../support/expense_control_fixtures.dart';
import '../../support/load_app_fonts.dart';

/// Final sweep, layer 1: Thu chi, Thu nhập, Chi tiêu (manual and scan) and Kế
/// hoạch across the width × theme × height × text-size matrix.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    await loadAppFonts();
    l10n = await AppLocalizations.delegate.load(const Locale('vi'));
  });

  Future<void> sweep(WidgetTester tester, SweepCase c, Widget screen) {
    return pumpSweepCase(
      tester,
      c,
      (theme) => screen,
      wrap: (app) => wrapForTest(
        app,
        repository: FakeExpenseControlRepository([
          ...accounts(7),
          ...groupWithChildren('g2', groupName: 'Nhóm hai', childCount: 3),
        ]),
        theme: c.theme,
        textScale: c.textScale,
      ),
    );
  }

  group('Thu chi', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        await sweep(tester, c, const SpendingScreen());
        if (c.width >= 840) {
          final card = tester.getRect(find.byType(BalanceGroupCard).first);
          expect(card.width, lessThanOrEqualTo(960.01));
        }
        await expectNoDeadZoneFor(tester, c);
      });
    }
  });

  group('Thu nhập', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        await sweep(tester, c, const IncomeScreen());
        if (c.width >= 600) {
          final save = tester.getRect(find.bySubtype<FilledButton>().last);
          expect(save.width, lessThanOrEqualTo(520.01));
        }
        await expectNoDeadZoneFor(tester, c);
      });
    }
  });

  group('Chi tiêu (manual)', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        await sweep(tester, c, const ExpenseScreen());
        if (c.width >= 600) {
          final pad = tester.getRect(find.byType(GridView));
          expect(pad.width, lessThanOrEqualTo(520.01));
        }
        await expectNoDeadZoneFor(tester, c);
      });
    }
  });

  group('Chi tiêu (scan)', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        await sweep(tester, c, const ExpenseScreen());
        await tester.tap(find.text(l10n.expenseTabScan));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(l10n.expenseScanCaptureAction));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'after capturing');
        await expectNoDeadZoneFor(tester, c);
      });
    }
  });

  group('Kế hoạch', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        await sweep(tester, c, const ExpenseControlScreen());
        if (c.width >= 840) {
          final card = tester.getRect(find.byType(ExpenseGroupCard).first);
          expect(card.width, lessThanOrEqualTo(960.01));
        }
        await expectNoDeadZoneFor(tester, c);
      });
    }
  });
}
