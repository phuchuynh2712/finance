import 'package:intl/intl.dart';

/// Locale-aware VND currency formatting — the single shared entry point for
/// displaying financial figures, per constitution Principle III ("never ad
/// hoc string interpolation" for currency).
class CurrencyFormatter {
  CurrencyFormatter(String localeName)
    : _isVietnamese = localeName.startsWith('vi'),
      _format = NumberFormat.currency(
        locale: localeName,
        symbol: '₫',
        decimalDigits: 0,
      );

  final bool _isVietnamese;
  final NumberFormat _format;

  static const _million = 1000000;

  /// Formats a whole-VND integer amount, e.g. `20000000` → `20.000.000 ₫`
  /// (`vi` locale) or `₫20,000,000` (`en` locale grouping).
  String format(int amountInVnd) => _format.format(amountInVnd);

  /// A rounded, abbreviated form for `vi` magnitudes at or above 1,000,000,
  /// e.g. `12400000` → `"12,4 triệu ₫"` (research.md Decision 5). Falls back
  /// to [format] below that threshold, and for any non-`vi` locale — the
  /// design has no compact notation for other locales, and FR-002 always
  /// shows the exact [format] amount alongside this one, so no information
  /// is lost.
  String formatCompact(int amountInVnd) {
    if (!_isVietnamese || amountInVnd.abs() < _million) {
      return format(amountInVnd);
    }
    final millions = (amountInVnd / _million).toStringAsFixed(1);
    return '${millions.replaceAll('.', ',')} triệu ₫';
  }
}
