import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expenses/presentation/spending_screen.dart';
import 'package:finance/features/expenses/presentation/widgets/balance_group_card.dart';

import '../../../support/expense_control_fixtures.dart';
import '../../../support/expense_screen_harness.dart';
import '../../../support/load_app_fonts.dart';

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required double height,
  List<ExpenseControlItem>? items,
  bool rail = false,
  ThemeData? theme,
}) async {
  useView(tester, width, height);
  await tester.pumpWidget(
    KeyedSubtree(
      key: UniqueKey(),
      child: wrapForTest(
        const SpendingScreen(),
        repository: FakeExpenseControlRepository(items ?? accounts(4)),
        theme: theme ?? AppTheme.light,
        rail: rail,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ScrollPosition _listPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    // Real Lexend widths: the 320dp case is about horizontal fit.
    await loadAppFonts();
    l10n = await AppLocalizations.delegate.load(const Locale('vi'));
  });

  Finder entryButton(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;

  group('H1/H2: one bounded column; the two entry buttons side by side', () {
    for (final entry in {
      'light': AppTheme.light,
      'dark': AppTheme.dark,
    }.entries) {
      for (final w in [1200.0, 1440.0, 2560.0]) {
        testWidgets(
          '${entry.key} ${w.toInt()} beside the rail: ≤ 960, centered',
          (tester) async {
            await _pump(
              tester,
              width: w,
              height: 900,
              rail: true,
              theme: entry.value,
            );
            final viewportCenter = 83 + (w - 83) / 2;
            final card = tester.getRect(find.byType(BalanceGroupCard).first);
            expect(card.width, closeTo(960, 0.01));
            expect(card.center.dx, closeTo(viewportCenter, 1));

            final income = tester.getRect(
              entryButton(l10n.spendingIncomeAction),
            );
            final expense = tester.getRect(
              entryButton(l10n.spendingExpenseAction),
            );
            // Side by side, 64 high, each at most half of the column.
            expect(income.height, 64);
            expect(expense.height, 64);
            expect(income.top, expense.top);
            expect(income.right, lessThan(expense.left));
            expect(income.width, lessThanOrEqualTo(480.01));
            expect(expense.width, lessThanOrEqualTo(480.01));
            final union = income.expandToInclude(expense);
            expect(union.width, closeTo(960, 0.01));
            expect(union.center.dx, closeTo(viewportCenter, 1));
          },
        );
      }
    }

    testWidgets('840 beside the rail: the viewport (757) minus 36', (
      tester,
    ) async {
      await _pump(tester, width: 840, height: 800, rail: true);
      final card = tester.getRect(find.byType(BalanceGroupCard).first);
      expect(card.left, 83 + 18);
      expect(card.right, 840 - 18);
    });

    testWidgets('600–839 beside the rail: the viewport minus 36', (
      tester,
    ) async {
      await _pump(tester, width: 700, height: 800, rail: true);
      final card = tester.getRect(find.byType(BalanceGroupCard).first);
      expect(card.left, 83 + 18);
      expect(card.right, 700 - 18);
      final income = tester.getRect(entryButton(l10n.spendingIncomeAction));
      final expense = tester.getRect(entryButton(l10n.spendingExpenseAction));
      expect(income.height, 64);
      expect(income.width, lessThanOrEqualTo((700 - 83 - 36) / 2 + 0.01));
      expect(expense.left, greaterThan(income.right));
    });

    testWidgets('the history link keeps its place inside the column', (
      tester,
    ) async {
      await _pump(tester, width: 1440, height: 900);
      final history = tester.getRect(entryButton(l10n.spendingHistoryAction));
      expect(history.width, closeTo(960, 0.01));
      expect(history.center.dx, closeTo(720, 1));
    });
  });

  group('H4: rows', () {
    testWidgets('a group collapses and expands as before', (tester) async {
      await _pump(tester, width: 1440, height: 900, items: accounts(3));
      expect(find.byKey(const ValueKey('balance-item-row-a1')), findsOneWidget);
      await tester.tap(find.text('Nhóm'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('balance-item-row-a1')), findsNothing);
      await tester.tap(find.text('Nhóm'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('balance-item-row-a1')), findsOneWidget);
    });

    testWidgets('the group header offers hover feedback and focus', (
      tester,
    ) async {
      await _pump(tester, width: 1440, height: 900, items: accounts(3));
      final header = find
          .ancestor(of: find.text('Nhóm'), matching: find.byType(InkWell))
          .first;
      expect(offersHoverFeedback(tester, header), isTrue);
      expect(tester.widget<InkWell>(header).canRequestFocus, isTrue);
    });

    testWidgets('a read-only row shows a hover tint under the mouse', (
      tester,
    ) async {
      await _pump(tester, width: 1440, height: 900, items: accounts(3));
      Color? tint() => tester
          .widget<ColoredBox>(
            find.descendant(
              of: find.byKey(const ValueKey('balance-item-row-a1')),
              matching: find.byType(ColoredBox),
            ),
          )
          .color;
      expect(tint()?.a ?? 0, 0);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey('balance-item-row-a1'))),
      );
      await tester.pump();
      expect(tint()?.a ?? 0, greaterThan(0));
      await mouse.moveTo(const Offset(5, 5));
      await tester.pump();
      expect(tint()?.a ?? 0, 0);
    });
  });

  group('H5: long names and large balances', () {
    for (final w in [320.0, 1440.0]) {
      testWidgets('${w.toInt()}: a 60-character name and a 12-digit balance', (
        tester,
      ) async {
        final longName = 'Tên rất dài ' * 5;
        await _pump(
          tester,
          width: w,
          height: 800,
          items: [
            leafItem('big', name: longName.trim(), balance: 999999999999),
            leafItem('neg', name: 'Âm', balance: -999999999999, sortOrder: 1),
          ],
        );
        expect(tester.takeException(), isNull);
        final balance = tester.getRect(
          find.textContaining('999.999.999.999').first,
        );
        expect(balance.right, lessThanOrEqualTo(w));
        expect(balance.left, greaterThanOrEqualTo(0));
      });
    }
  });

  group('H6: scrolling from the margin', () {
    testWidgets('the wheel works over the side margin at 1440×500', (
      tester,
    ) async {
      await _pump(
        tester,
        width: 1440,
        height: 500,
        items: groupWithChildren('g1', childCount: 30),
      );
      final position = _listPosition(tester);
      expect(position.maxScrollExtent, greaterThan(0));
      final before = position.pixels;
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(const Offset(50, 300)));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 120)));
      await tester.pump();
      expect(position.pixels, greaterThan(before));
    });
  });

  group('H7: compact is unchanged', () {
    testWidgets('410: 18dp side padding and full-width cards', (tester) async {
      await _pump(tester, width: 410, height: 864);
      final card = tester.getRect(find.byType(BalanceGroupCard).first);
      expect(card.left, 18);
      expect(card.right, 410 - 18);
      final income = tester.getRect(entryButton(l10n.spendingIncomeAction));
      expect(income.left, 18);
    });
  });
}
