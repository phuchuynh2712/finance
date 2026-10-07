import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/features/expenses/presentation/overview_providers.dart';
import 'package:finance/features/expenses/presentation/overview_screen.dart';
import 'package:finance/features/expenses/presentation/report_screen.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/features/expense_control/presentation/expense_control_providers.dart';

import '../../support/account_harness.dart';
import '../../support/adaptive_sweep.dart';
import '../../support/expense_control_fixtures.dart';
import '../../support/history_fixtures.dart';
import '../../support/load_app_fonts.dart';
import '../../support/pull_complete_override.dart';

/// Final sweep, layer 1: Tổng quan and Báo cáo across the width × theme ×
/// height × text-size matrix.
void main() {
  setUpAll(loadAppFonts);

  Widget wrapApp(Widget app, SweepCase c, {List<Override> extra = const []}) {
    return ProviderScope(
      overrides: [
        expenseControlRepositoryProvider.overrideWithValue(
          FakeExpenseControlRepository(accounts(5)),
        ),
        transactionHistoryRepositoryProvider.overrideWithValue(
          FakeHistoryRepository(sampleHistory()),
        ),
        overviewAuthActionsProvider.overrideWithValue(FakeAccountActions()),
        pullCompleteOverride,
        ...extra,
      ],
      child: MaterialApp(
        theme: c.theme,
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(c.textScale)),
          child: child!,
        ),
        home: app,
      ),
    );
  }

  group('Tổng quan', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        await pumpSweepCase(
          tester,
          c,
          (theme) => const OverviewScreen(),
          wrap: (app) => wrapApp(app, c),
        );
        await expectNoDeadZoneFor(tester, c);
      });
    }
  });

  group('Báo cáo', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        await pumpSweepCase(
          tester,
          c,
          (theme) => const ReportScreen(),
          wrap: (app) => wrapApp(app, c),
        );
        await expectNoDeadZoneFor(tester, c);
      });
    }
  });
}
