import 'package:flutter/material.dart';

import '../../../core/formatting/currency_formatter.dart';

/// Centralized percentage formatting for this feature (research.md §10) —
/// no ad hoc string interpolation scattered across widgets. Trims a
/// trailing `.0` (`90` not `90.0`) but keeps one decimal when needed
/// (`12.5`).
String formatPercent(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

/// Formats a fixed-amount VND value via the shared
/// `core/formatting/currency_formatter.dart` (Constitution Principle III —
/// research.md §10), never ad hoc string interpolation.
String formatFixedAmount(BuildContext context, double value) {
  final currency = CurrencyFormatter(Localizations.localeOf(context).toString());
  return currency.format(value.round());
}
