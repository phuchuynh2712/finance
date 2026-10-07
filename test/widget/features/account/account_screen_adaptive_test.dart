import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/account/presentation/account_screen.dart';
import 'package:finance/features/account/presentation/security_screen.dart';

import '../../../support/account_harness.dart';
import '../../../support/expense_screen_harness.dart';
import '../../../support/load_app_fonts.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    await loadAppFonts();
    l10n = await AppLocalizations.delegate.load(const Locale('vi'));
  });

  Finder row(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;

  /// The Hồ sơ language row spans the column; so does Bảo mật's change-password
  /// row, so their rects are the two screens' content columns.
  Rect accountColumn(WidgetTester tester) =>
      tester.getRect(row(l10n.accountLanguageLabel));
  Rect securityColumn(WidgetTester tester) =>
      tester.getRect(row(l10n.securityChangePasswordRow));

  group('A1/A2: one bounded column, the same as Bảo mật', () {
    for (final theme in {
      'light': AppTheme.light,
      'dark': AppTheme.dark,
    }.entries) {
      for (final w in [840.0, 1200.0, 1440.0, 1600.0, 2560.0]) {
        testWidgets(
          '${theme.key} ${w.toInt()}: ≤ 960, centered, equal to Bảo mật',
          (tester) async {
            await pumpAccountScreen(
              tester,
              const AccountScreen(),
              width: w,
              height: 1000,
              rail: true,
              theme: theme.value,
            );
            final account = accountColumn(tester);
            final viewportCenter = 83 + (w - 83) / 2;
            final expected = (w - 83 - 36).clamp(0.0, 960.0);
            expect(account.width, closeTo(expected, 0.01));
            expect(account.center.dx, closeTo(viewportCenter, 1));

            await pumpAccountScreen(
              tester,
              const SecurityScreen(),
              width: w,
              height: 1000,
              rail: true,
              theme: theme.value,
            );
            final security = securityColumn(tester);
            expect((security.left - account.left).abs(), lessThanOrEqualTo(8));
            expect(
              (security.width - account.width).abs(),
              lessThanOrEqualTo(8),
            );
          },
        );
      }
    }

    testWidgets('A3: at 700 both use the viewport minus 36', (tester) async {
      await pumpAccountScreen(
        tester,
        const AccountScreen(),
        width: 700,
        height: 1000,
        rail: true,
      );
      final account = accountColumn(tester);
      expect(account.left, 83 + 18);
      expect(account.right, 700 - 18);
      await pumpAccountScreen(
        tester,
        const SecurityScreen(),
        width: 700,
        height: 1000,
        rail: true,
      );
      final security = securityColumn(tester);
      // Within the border widths of the two screens' cards.
      expect(security.left, closeTo(account.left, 2));
      expect(security.right, closeTo(account.right, 2));
    });

    testWidgets('A8: the title strip stays full width', (tester) async {
      await pumpAccountScreen(
        tester,
        const AccountScreen(),
        width: 1440,
        height: 900,
        rail: true,
      );
      expect(tester.getRect(find.byType(AppBar)).width, 1440 - 83);
    });
  });

  group('A4/D5: the language pop-up', () {
    Future<void> openPicker(WidgetTester tester, {Locale? locale}) async {
      await pumpAccountScreen(
        tester,
        const AccountScreen(),
        width: 1440,
        height: 900,
        rail: true,
        locale: locale ?? const Locale('vi'),
      );
      await tester.tap(row(l10n.accountLanguageLabel));
      await tester.pumpAndSettle();
      expect(find.byType(SimpleDialog), findsOneWidget);
    }

    testWidgets('centered, at most 560 wide', (tester) async {
      await openPicker(tester);
      final rect = tester.getRect(
        find
            .descendant(
              of: find.byType(SimpleDialog),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(rect.width, lessThanOrEqualTo(560.01));
      expect(rect.center.dx, closeTo(720, 1));
    });

    testWidgets(
      'the selected language has the initial focus; Enter confirms it',
      (tester) async {
        await openPicker(tester);
        final selected = find.ancestor(
          of: find.text(l10n.accountLanguageVietnamese).last,
          matching: find.byType(InkWell),
        );
        expect(focusIsWithin(tester, selected.first), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(SimpleDialog), findsNothing);
      },
    );

    testWidgets('Escape dismisses without changing the language', (
      tester,
    ) async {
      await openPicker(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(SimpleDialog), findsNothing);
      expect(find.text(l10n.accountLanguageLabel), findsOneWidget);
    });

    testWidgets('choosing English still works with the mouse', (tester) async {
      await openPicker(tester);
      await tester.tap(find.text(l10n.accountLanguageEnglish).last);
      await tester.pumpAndSettle();
      expect(find.byType(SimpleDialog), findsNothing);
    });
  });

  group('A5/A6/A7', () {
    testWidgets('menu rows are 48 high or more and show hover feedback', (
      tester,
    ) async {
      await pumpAccountScreen(
        tester,
        const AccountScreen(),
        width: 1440,
        height: 900,
        rail: true,
      );
      for (final label in [
        l10n.accountLanguageLabel,
        l10n.accountSignOutAction,
      ]) {
        final finder = row(label);
        expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));
        expect(offersHoverFeedback(tester, finder), isTrue, reason: label);
      }
    });

    testWidgets('the wheel works over the side margin at 1440×400', (
      tester,
    ) async {
      await pumpAccountScreen(
        tester,
        const AccountScreen(),
        width: 1440,
        height: 400,
        rail: true,
      );
      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      final before = scrollable.position.pixels;
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(const Offset(150, 250)));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 120)));
      await tester.pump();
      expect(scrollable.position.pixels, greaterThan(before));
    });

    testWidgets('A7: at 410 the paddings are the pre-change 18', (
      tester,
    ) async {
      await pumpAccountScreen(
        tester,
        const AccountScreen(),
        width: 410,
        height: 900,
      );
      final language = accountColumn(tester);
      expect(language.left, 18);
      expect(language.right, 410 - 18);
    });
  });
}
