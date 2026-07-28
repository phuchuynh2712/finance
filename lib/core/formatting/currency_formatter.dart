import 'package:intl/intl.dart';

/// Locale-aware VND currency formatting — the single shared entry point for
/// displaying financial figures, per constitution Principle III ("never ad
/// hoc string interpolation" for currency).
class CurrencyFormatter {
  CurrencyFormatter(String localeName)
    : _format = NumberFormat.currency(
        locale: localeName,
        symbol: '₫',
        decimalDigits: 0,
      );

  final NumberFormat _format;

  /// Formats a whole-VND integer amount, e.g. `20000000` → `20.000.000 ₫`
  /// (`vi` locale) or `₫20,000,000` (`en` locale grouping).
  String format(int amountInVnd) => _format.format(amountInVnd);
}
