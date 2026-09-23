import 'package:flutter/material.dart';

import 'package:finance/core/formatting/currency_formatter.dart';

/// Formats a fixed-amount VND value via the shared
/// `core/formatting/currency_formatter.dart` (Constitution Principle III —
/// research.md §10), never ad hoc string interpolation.
String formatFixedAmount(BuildContext context, double value) {
  final currency = CurrencyFormatter(
    Localizations.localeOf(context).toString(),
  );
  return currency.format(value.round());
}
