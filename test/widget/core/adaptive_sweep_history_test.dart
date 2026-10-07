import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/features/expense_control/presentation/expense_control_providers.dart';
import 'package:finance/features/expenses/application/transaction_history.dart';
import 'package:finance/features/expenses/presentation/transaction_history_providers.dart';
import 'package:finance/features/expenses/presentation/transaction_history_screen.dart';

import '../../support/adaptive_sweep.dart';
import '../../support/expense_control_fixtures.dart';
import '../../support/history_fixtures.dart';
import '../../support/load_app_fonts.dart';
import '../../support/pull_complete_override.dart';

/// Final sweep, layer 1: Lịch sử giao dịch and Lịch sử theo khoản (the same
/// screen with a group filter) across the width × theme × height × text-size
/// matrix.
void main() {
  setUpAll(loadAppFonts);

  Widget wrapApp(Widget app, SweepCase c) {
    return ProviderScope(
      overrides: [
        expenseControlRepositoryProvider.overrideWithValue(
          FakeExpenseControlRepository(accounts(5)),
        ),
        transactionHistoryRepositoryProvider.overrideWithValue(
          FakeHistoryRepository(sampleHistory(count: 40)),
        ),
        pullCompleteOverride,
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

  group('Lịch sử giao dịch', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        await pumpSweepCase(
          tester,
          c,
          (theme) => const TransactionHistoryScreen(),
          wrap: (app) => wrapApp(app, c),
        );
        await expectNoDeadZoneFor(tester, c);
      });
    }
  });

  group('Lịch sử theo khoản', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        await pumpSweepCase(
          tester,
          c,
          (theme) => ProviderScope(
            overrides: [
              selectedTransactionHistoryFilterProvider.overrideWith(
                (ref) => const TransactionHistoryFilter.group('Nhóm'),
              ),
            ],
            child: const TransactionHistoryScreen(),
          ),
          wrap: (app) => wrapApp(app, c),
        );
        await expectNoDeadZoneFor(tester, c);
      });
    }
  });
}
