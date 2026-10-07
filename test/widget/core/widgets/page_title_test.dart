import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/theme/app_icons.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/core/widgets/not_available_placeholder_screen.dart';
import 'package:finance/core/widgets/page_title.dart';
import 'package:finance/features/account/presentation/account_screen.dart';
import 'package:finance/features/expenses/presentation/spending_screen.dart';

import '../../../support/account_harness.dart';
import '../../../support/expense_control_fixtures.dart';
import '../../../support/expense_screen_harness.dart';
import '../../../support/load_app_fonts.dart';

/// A bare `Text` title is centered on iOS and on a desktop browser and
/// left-aligned on Android. Hồ sơ, Thu chi and the placeholders share one
/// title instead: a 34dp tinted chip with the page's icon, then the text,
/// always at the left.
void main() {
  setUpAll(loadAppFonts);

  // macOS is a platform whose default centers an AppBar title.
  final desktop = AppTheme.light.copyWith(platform: TargetPlatform.macOS);

  Future<void> pumpTitle(
    WidgetTester tester, {
    required double width,
    String title = 'Thu chi',
    double textScale = 1.0,
  }) async {
    useView(tester, width, 700);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: desktop,
        home: Scaffold(
          appBar: AppBar(
            title: PageTitle(icon: LucideIcons.receipt, title: title),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [412.0, 1440.0]) {
    testWidgets('$width wide: a 34dp chip with the icon, then the text, at '
        'the left even where a bare title would be centered', (tester) async {
      await pumpTitle(tester, width: width);
      final chip = tester.getRect(
        find
            .ancestor(
              of: find.byIcon(LucideIcons.receipt),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(chip.size, const Size(34, 34));
      expect(chip.left, 16); // the app bar's own title spacing
      final text = tester.getRect(find.text('Thu chi'));
      expect(text.left, chip.right + 12);
      expect(text.center.dy, closeTo(chip.center.dy, 1));
    });
  }

  testWidgets('a long title at 200 % text is cut with an ellipsis, not '
      'overflowed', (tester) async {
    await pumpTitle(
      tester,
      width: 320,
      title: 'Một tiêu đề rất dài cho trang này',
      textScale: 2.0,
    );
    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(find.textContaining('Một tiêu đề'));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  group('the pages that use it', () {
    for (final width in [412.0, 1440.0]) {
      testWidgets('$width wide: Thu chi', (tester) async {
        useView(tester, width, 800);
        await tester.pumpWidget(
          wrapForTest(
            const SpendingScreen(),
            repository: FakeExpenseControlRepository([]),
            theme: desktop,
          ),
        );
        await tester.pumpAndSettle();
        final title = find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(PageTitle),
        );
        expect(title, findsOneWidget);
        expect(tester.getTopLeft(title).dx, 16);
      });

      testWidgets('$width wide: Hồ sơ', (tester) async {
        await pumpAccountScreen(
          tester,
          const AccountScreen(),
          width: width,
          height: 800,
          theme: desktop,
        );
        final title = find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(PageTitle),
        );
        expect(title, findsOneWidget);
        expect(tester.getTopLeft(title).dx, 16);
      });

      testWidgets('$width wide: the placeholder', (tester) async {
        useView(tester, width, 800);
        await tester.pumpWidget(
          MaterialApp(
            theme: desktop,
            home: const NotAvailablePlaceholderScreen(
              icon: LucideIcons.bell,
              title: 'Thông báo',
              message: 'Tính năng đang được phát triển.',
            ),
          ),
        );
        await tester.pumpAndSettle();
        final title = find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(PageTitle),
        );
        expect(title, findsOneWidget);
        expect(tester.getTopLeft(title).dx, 16);
      });
    }
  });
}
