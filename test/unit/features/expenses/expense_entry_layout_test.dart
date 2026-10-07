import 'dart:ui' show Size;

import 'package:finance/features/expenses/presentation/expense_entry_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExpenseEntryLayout.of (data-model §1.3)', () {
    test('isWide flips exactly at 600dp', () {
      expect(ExpenseEntryLayout.of(const Size(599.9, 900)).isWide, isFalse);
      expect(ExpenseEntryLayout.of(const Size(600, 900)).isWide, isTrue);
    });

    test('wide key height follows clamp(48 + (h - 640) / 8, 48, 64)', () {
      double k(double height, [double width = 1000]) =>
          ExpenseEntryLayout.of(Size(width, height)).keyHeight!;
      expect(k(500), 48);
      expect(k(640), 48);
      expect(k(704), 56);
      expect(k(768), 64);
      expect(k(900), 64);
      expect(k(1300), 64);
    });

    test('the key height never depends on the width', () {
      for (final width in [600.0, 1200.0, 2560.0]) {
        expect(ExpenseEntryLayout.of(Size(width, 704)).keyHeight, 56);
      }
    });

    test('no wide key is ever taller than 72 or shorter than 48', () {
      for (var h = 300.0; h <= 2000; h += 13) {
        final k = ExpenseEntryLayout.of(Size(1000, h)).keyHeight!;
        expect(k, inInclusiveRange(48, 72));
      }
    });

    test('the amount is pinned only in wide mode and from 500dp high', () {
      expect(ExpenseEntryLayout.pinAmountMinHeight, 500);
      expect(ExpenseEntryLayout.of(const Size(412, 900)).amountPinned, isFalse);
      expect(ExpenseEntryLayout.of(const Size(844, 390)).amountPinned, isFalse);
      expect(
        ExpenseEntryLayout.of(const Size(1000, 499.9)).amountPinned,
        isFalse,
      );
      expect(ExpenseEntryLayout.of(const Size(1000, 500)).amountPinned, isTrue);
      expect(ExpenseEntryLayout.of(const Size(1440, 900)).amountPinned, isTrue);
    });

    test('compact values are exactly the pre-change layout', () {
      final layout = ExpenseEntryLayout.of(const Size(410, 864));
      expect(layout.isWide, isFalse);
      expect(layout.keyHeight, isNull); // derived from width, aspect ratio 2.2
      expect(ExpenseEntryLayout.compactKeyAspectRatio, 2.2);
      expect(layout.keyGap, 8);
      expect(layout.chooserWraps, isFalse);
      expect(layout.chooserMaxHeight, isNull);
      expect(layout.tabHeight, 38);
      expect(layout.tabsTopPadding, 16);
      expect(layout.contentTopGap, 8);
      expect(layout.amountVerticalPadding, 8);
      expect(layout.keypadVerticalPadding, 14);
      expect(layout.eyebrowBottomPadding, 8);
      expect(layout.bannerBottomMargin, 14);
      expect(layout.saveTopPadding, 0);
      expect(layout.saveBottomPadding, 20);
      expect(layout.saveHeight, 52);
    });

    test('wide values', () {
      final layout = ExpenseEntryLayout.of(const Size(1440, 900));
      expect(layout.isWide, isTrue);
      expect(layout.keyGap, 6);
      expect(layout.chooserWraps, isTrue);
      expect(layout.chooserMaxHeight, 106);
      expect(layout.tabHeight, 48);
      expect(layout.saveHeight, 48);
      expect(layout.saveBottomPadding, lessThan(20));
      expect(layout.tabsTopPadding, lessThan(16));
      expect(layout.keypadVerticalPadding, lessThan(14));
    });
  });
}
