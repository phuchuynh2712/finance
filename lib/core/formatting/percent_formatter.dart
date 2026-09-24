/// Formats a percentage without an unnecessary trailing decimal.
String formatPercent(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
