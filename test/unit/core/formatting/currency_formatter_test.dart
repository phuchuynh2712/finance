import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/formatting/currency_formatter.dart';

void main() {
  group('formatCompact — vi locale', () {
    final formatter = CurrencyFormatter('vi');

    test('rounds to one decimal using "triệu" for magnitudes >= 1,000,000', () {
      expect(formatter.formatCompact(12400000), '12,4 triệu ₫');
    });

    test(
      'matches the design reference example exactly (27.250.000 → 27,3 triệu ₫)',
      () {
        expect(formatter.formatCompact(27250000), '27,3 triệu ₫');
      },
    );

    test(
      'the threshold value itself (exactly 1,000,000) uses compact form',
      () {
        expect(formatter.formatCompact(1000000), '1,0 triệu ₫');
      },
    );

    test(
      'falls back to the full grouped form below the 1,000,000 threshold',
      () {
        expect(formatter.formatCompact(999999), formatter.format(999999));
      },
    );

    test('falls back to the full grouped form for zero', () {
      expect(formatter.formatCompact(0), formatter.format(0));
    });
  });

  group('formatCompact — en locale', () {
    final formatter = CurrencyFormatter('en');

    test(
      'always falls back to the full grouped form, even above the threshold',
      () {
        expect(formatter.formatCompact(12400000), formatter.format(12400000));
      },
    );
  });
}
