import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/widgets/not_available_placeholder_screen.dart';
import 'application/transaction_history.dart';
import 'presentation/expense_screen.dart';
import 'presentation/income_screen.dart';
import 'presentation/overview_screen.dart';
import 'presentation/report_screen.dart';
import 'presentation/spending_screen.dart';
import 'presentation/transaction_history_providers.dart';
import 'presentation/transaction_history_screen.dart';

Widget spendingRoute(BuildContext context, GoRouterState state) =>
    const SpendingScreen();

Widget overviewRoute(BuildContext context, GoRouterState state) =>
    const OverviewScreen();

Widget reportRoute(BuildContext context, GoRouterState state) =>
    const ReportScreen();

/// Nested under `/spending` (secure-storage-routing-cleanup Tier A) —
/// preserves today's exact push behavior (shell chrome stays visible,
/// same screens), only reachable by a real URL now.
Widget incomeRoute(BuildContext context, GoRouterState state) =>
    const IncomeScreen();

Widget expenseRoute(BuildContext context, GoRouterState state) =>
    const ExpenseScreen();

/// Nested under both `/spending` and `/overview` (shared, unfiltered) —
/// same screen either branch pushes today.
Widget transactionHistoryRoute(BuildContext context, GoRouterState state) =>
    const TransactionHistoryScreen();

/// Nested under `/overview` — the notification bell's "not available yet"
/// placeholder (Tier B). Only one case, unlike account's 3, so no lookup
/// key is needed.
Widget overviewNotificationsPlaceholderRoute(
  BuildContext context,
  GoRouterState state,
) {
  final l10n = AppLocalizations.of(context);
  return NotAvailablePlaceholderScreen(
    icon: LucideIcons.bell,
    title: l10n.overviewNotificationSemantic,
    message: l10n.notAvailablePlaceholderMessage,
  );
}

/// Nested under `/overview/history` (Tier C) — the negative-balance
/// banner's filtered-history link. `accountName` arrives URL-decoded
/// already (go_router decodes path segments), so it's passed straight
/// into the same `ProviderScope` override the original `Navigator.push`
/// call site used, reusing `TransactionHistoryFilter.group` without any
/// change to `TransactionHistoryScreen` or its providers.
Widget overviewFilteredHistoryRoute(BuildContext context, GoRouterState state) {
  final accountName = state.pathParameters['accountName']!;
  return ProviderScope(
    overrides: [
      selectedTransactionHistoryFilterProvider.overrideWith(
        (ref) => TransactionHistoryFilter.group(accountName),
      ),
    ],
    child: const TransactionHistoryScreen(),
  );
}
