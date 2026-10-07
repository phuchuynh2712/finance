import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/l10n/app_localizations.dart';

import '../../../support/app_shell_harness.dart';
import '../../../support/expense_control_fixtures.dart';
import '../../../support/expense_screen_harness.dart';
import '../../../support/load_app_fonts.dart';

/// The bottom bar's five labels each get a fifth of the width. At a large
/// system text size "Tổng quan" and "Kế hoạch" used to wrap onto a second
/// line and push their icons out of line with the others; the labels are now
/// drawn at no more than 110 % (the widest size at which "Tổng quan" still fits
/// a 412dp-wide phone) while the rest of the app keeps scaling.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    await loadAppFonts();
    l10n = await AppLocalizations.delegate.load(const Locale('vi'));
  });

  List<String> labels() => [
    l10n.tabOverview,
    l10n.tabExpenseControl,
    l10n.tabSpending,
    l10n.tabHistory,
    l10n.tabAccount,
  ];

  /// Lines each destination label is laid out on, at [scale].
  Future<List<int>> lineCounts(
    WidgetTester tester, {
    required double width,
    required double scale,
    required Type bar,
  }) async {
    useView(tester, width, 864);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final container = shellContainerFor(FakeExpenseControlRepository([]));
    addTearDown(container.dispose);
    await tester.pumpWidget(shellApp(container));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    double heightOf(String label) => tester
        .getSize(
          find
              .descendant(of: find.byType(bar), matching: find.text(label))
              .first,
        )
        .height;
    // "Thu chi" is short enough to be one line at every width and scale, so
    // its height is the height of one line.
    final oneLine = heightOf(l10n.tabSpending);
    return [for (final label in labels()) (heightOf(label) / oneLine).round()];
  }

  for (final width in [320.0, 360.0, 412.0]) {
    testWidgets('$width wide, default text size: every label is on one line', (
      tester,
    ) async {
      final lines = await lineCounts(
        tester,
        width: width,
        scale: 1.0,
        bar: NavigationBar,
      );
      expect(lines, [1, 1, 1, 1, 1]);
    });
  }

  testWidgets('360 wide, text ×1.1 (the cap): every label is still on one '
      'line', (tester) async {
    final lines = await lineCounts(
      tester,
      width: 360,
      scale: 1.1,
      bar: NavigationBar,
    );
    expect(lines, [1, 1, 1, 1, 1]);
  });

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('412 wide, text ×$scale: every label stays on one line', (
      tester,
    ) async {
      final lines = await lineCounts(
        tester,
        width: 412,
        scale: scale,
        bar: NavigationBar,
      );
      expect(lines, [1, 1, 1, 1, 1]);
    });
  }

  for (final width in [320.0, 360.0]) {
    testWidgets('$width wide: past 110 % the labels no longer change', (
      tester,
    ) async {
      final clamped = await lineCounts(
        tester,
        width: width,
        scale: 1.1,
        bar: NavigationBar,
      );
      final big = await lineCounts(
        tester,
        width: width,
        scale: 2.0,
        bar: NavigationBar,
      );
      expect(big, clamped);
    });
  }
}
