import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/expenses/presentation/income_screen.dart';

import '../../../support/expense_control_fixtures.dart';
import '../../../support/expense_screen_harness.dart';

Future<FakeExpenseControlRepository> _pump(
  WidgetTester tester, {
  required double width,
  required double height,
  bool rail = false,
  ThemeData? theme,
  bool withItems = true,
}) async {
  useView(tester, width, height);
  final repository = FakeExpenseControlRepository(
    withItems ? accounts(3) : const [],
  );
  await tester.pumpWidget(
    KeyedSubtree(
      key: UniqueKey(),
      child: wrapForTest(
        const IncomeScreen(),
        repository: repository,
        theme: theme ?? AppTheme.light,
        rail: rail,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Finder _amountField(int row) => find.byKey(ValueKey('income-amount-$row'));
Finder _save(AppLocalizations l10n) => find.ancestor(
  of: find.text(l10n.incomeSaveAction),
  matching: find.bySubtype<FilledButton>(),
);
Finder _addButton(AppLocalizations l10n) => find
    .ancestor(
      of: find.text(l10n.incomeAddSourceAction),
      matching: find.byType(InkWell),
    )
    .first;

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
    l10n = await AppLocalizations.delegate.load(const Locale('vi'));
  });

  for (final entry in {
    'light': AppTheme.light,
    'dark': AppTheme.dark,
  }.entries) {
    group('I1/I2 bounded column (${entry.key})', () {
      testWidgets('1440×900: one column of at most 520, centered', (
        tester,
      ) async {
        await _pump(tester, width: 1440, height: 900, theme: entry.value);
        for (final (name, finder) in [
          ('save', _save(l10n)),
          ('add source', _addButton(l10n)),
        ]) {
          final rect = tester.getRect(finder);
          expect(rect.width, closeTo(520, 0.01), reason: name);
          expect(rect.center.dx, closeTo(720, 1), reason: name);
        }
        // The row's name field and amount field are at most 520 apart.
        final name = tester.getRect(find.byType(TextFormField).first);
        final amount = tester.getRect(_amountField(0));
        expect(amount.right - name.left, lessThanOrEqualTo(520));
      });

      testWidgets('840 beside the rail: centered in the viewport', (
        tester,
      ) async {
        await _pump(
          tester,
          width: 840,
          height: 800,
          rail: true,
          theme: entry.value,
        );
        final rect = tester.getRect(_save(l10n));
        expect(rect.width, closeTo(520, 0.01));
        expect(rect.center.dx, closeTo(83 + (840 - 83) / 2, 1));
      });
    });
  }

  testWidgets(
    'I3: with 12 sources at 1440×500 the list scrolls from the margin '
    'and Save stays reachable',
    (tester) async {
      await _pump(tester, width: 1440, height: 500);
      for (var i = 0; i < 11; i++) {
        // The add button sits at the end of the lazy list: scroll to it first.
        final end = _listPosition(tester);
        end.jumpTo(end.maxScrollExtent);
        await tester.pump();
        await tester.tap(_addButton(l10n));
        await tester.pump();
      }
      _listPosition(tester).jumpTo(0);
      await tester.pumpAndSettle();
      final position = _listPosition(tester);
      expect(position.maxScrollExtent, greaterThan(0));

      // Save is pinned and fully inside the window.
      final save = tester.getRect(_save(l10n));
      expect(save.bottom, lessThanOrEqualTo(500));
      expect(save.top, greaterThanOrEqualTo(0));

      // The mouse wheel works over the empty side margin (x = 50), not only
      // over the column.
      final before = position.pixels;
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(const Offset(50, 250)));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 120)));
      await tester.pump();
      expect(position.pixels, greaterThan(before));
    },
  );

  testWidgets(
    'I4: typing an amount updates the total; Tab reaches the fields',
    (tester) async {
      await _pump(tester, width: 1440, height: 900);
      await tester.enterText(_amountField(0), '5000000');
      await tester.pump();
      expect(find.textContaining('5.000.000'), findsWidgets);

      // Keyboard order reaches the name, then the amount field.
      final focusScope = FocusManager.instance;
      var reachedAmount = false;
      for (var i = 0; i < 12 && !reachedAmount; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final context = focusScope.primaryFocus?.context;
        if (context == null) continue;
        context.visitAncestorElements((element) {
          if (element.widget.key == const ValueKey('income-amount-0')) {
            reachedAmount = true;
            return false;
          }
          return true;
        });
        if (context.widget.key == const ValueKey('income-amount-0')) {
          reachedAmount = true;
        }
      }
      expect(reachedAmount, isTrue);
    },
  );

  testWidgets('I5: typed amounts and the total survive 1440 → 410 → 1440', (
    tester,
  ) async {
    await _pump(tester, width: 1440, height: 900);
    await tester.tap(_addButton(l10n));
    await tester.pump();
    await tester.enterText(_amountField(0), '3000000');
    await tester.enterText(_amountField(1), '2000000');
    await tester.pump();
    expect(find.textContaining('5.000.000'), findsWidgets);

    for (final (w, h) in [(410.0, 864.0), (1440.0, 900.0)]) {
      tester.view.physicalSize = Size(w, h);
      await tester.pumpAndSettle();
      expect(find.textContaining('5.000.000'), findsWidgets, reason: '$w');
      expect(
        tester.widget<TextFormField>(_amountField(0)).controller!.text,
        isNotEmpty,
      );
      expect(find.byKey(const ValueKey('income-amount-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('income-amount-1')), findsOneWidget);
    }
  });

  testWidgets('I7: the empty state is bounded and centered', (tester) async {
    await _pump(tester, width: 1440, height: 900, withItems: false);
    expect(find.text(l10n.incomeEmptyStateMessage), findsOneWidget);
    final rect = tester.getRect(find.text(l10n.incomeEmptyStateMessage));
    expect(rect.center.dx, closeTo(720, 1));
  });

  testWidgets('I8: the add button and Save offer hover feedback', (
    tester,
  ) async {
    await _pump(tester, width: 1440, height: 900);
    expect(offersHoverFeedback(tester, _addButton(l10n)), isTrue);
    expect(offersHoverFeedback(tester, _save(l10n)), isTrue);
  });

  testWidgets('I6: at 410 the paddings are the pre-change 18', (tester) async {
    await _pump(tester, width: 410, height: 864);
    final save = tester.getRect(_save(l10n));
    expect(save.left, 18);
    expect(save.right, 410 - 18);
    expect(tester.getRect(_amountField(0)).right, lessThanOrEqualTo(410 - 18));
  });
}
