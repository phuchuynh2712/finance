import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/expenses/presentation/expense_screen.dart';

import '../../../support/expense_control_fixtures.dart';
import '../../../support/expense_screen_harness.dart';

const _padKeys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', '⌫'];

final _themes = <String, ThemeData>{
  'light': AppTheme.light,
  'dark': AppTheme.dark,
};

Rect _screen(double w, double h) => Rect.fromLTWH(0, 0, w, h);

void _expectInside(
  WidgetTester tester,
  Finder finder,
  Rect screen,
  String why,
) {
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(screen.left - 0.01), reason: why);
  expect(rect.top, greaterThanOrEqualTo(screen.top - 0.01), reason: why);
  expect(rect.right, lessThanOrEqualTo(screen.right + 0.01), reason: why);
  expect(rect.bottom, lessThanOrEqualTo(screen.bottom + 0.01), reason: why);
}

void main() {
  group('L2: everything fits, no scrolling, from 600 × 640', () {
    const cases = [
      (600.0, 640.0, true), // the shell's rail leaves a 517dp viewport
      (1000.0, 640.0, false),
      (1366.0, 650.0, false),
      (1440.0, 900.0, false),
    ];
    for (final entry in _themes.entries) {
      for (final (w, h, rail) in cases) {
        testWidgets(
          '${w.toInt()}×${h.toInt()}${rail ? ' with rail' : ''}, ${entry.key}: '
          '8 accounts + banner fit without scrolling',
          (tester) async {
            await pumpExpenseScreen(
              tester,
              width: w,
              height: h,
              items: accounts(8),
              theme: entry.value,
              rail: rail,
            );
            await tapDigits(tester, '100000');
            await tester.tap(chip('a3'));
            await tester.pump();

            expect(previewBanner(), findsOneWidget);
            expect(mainScrollPosition(tester).maxScrollExtent, 0);

            final screen = _screen(w, h);
            _expectInside(tester, amountDisplay(), screen, 'amount');
            for (final key in _padKeys) {
              _expectInside(tester, keypadKey(key), screen, 'key $key');
            }
            for (var i = 1; i <= 8; i++) {
              _expectInside(tester, chip('a$i'), screen, 'chip a$i');
            }
            _expectInside(tester, previewBanner(), screen, 'banner');
            _expectInside(tester, saveButton(), screen, 'Save');
          },
        );
      }
    }
  });

  group('L1: bounded, centered panel', () {
    for (final (w, h) in [(1440.0, 900.0), (1000.0, 700.0)]) {
      testWidgets('${w.toInt()}×${h.toInt()}: pad panel ≤ 520 and centered', (
        tester,
      ) async {
        await pumpExpenseScreen(tester, width: w, height: h);
        final pad = tester.getRect(find.byType(GridView));
        expect(pad.width, lessThanOrEqualTo(520.01));
        expect(pad.width, closeTo(520, 0.01));
        expect(pad.center.dx, closeTo(w / 2, 1));
      });
    }

    testWidgets('with the rail, the panel is centered in the viewport', (
      tester,
    ) async {
      await pumpExpenseScreen(tester, width: 1440, height: 900, rail: true);
      final pad = tester.getRect(find.byType(GridView));
      expect(pad.width, closeTo(520, 0.01));
      expect(pad.center.dx, closeTo(83 + (1440 - 83) / 2, 1));
    });
  });

  group('L3/L4/L7: key size', () {
    for (final h in [640.0, 704.0, 768.0, 900.0]) {
      for (final w in [600.0, 1200.0, 2560.0]) {
        testWidgets(
          '${w.toInt()}×${h.toInt()}: key height follows the formula',
          (tester) async {
            await pumpExpenseScreen(tester, width: w, height: h);
            final expected = (48 + (h - 640) / 8).clamp(48.0, 64.0);
            final rect = tester.getRect(keypadKey('5'));
            expect(rect.height, closeTo(expected, 0.01));
            expect(rect.height, lessThanOrEqualTo(72));
            expect(rect.width, greaterThanOrEqualTo(48));
          },
        );
      }
    }

    testWidgets('every key, chip, tab and Save is at least 48 × 48', (
      tester,
    ) async {
      await pumpExpenseScreen(
        tester,
        width: 1000,
        height: 640,
        items: accounts(8),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      final targets = <String, Finder>{
        for (final key in _padKeys) 'key $key': keypadKey(key),
        for (var i = 1; i <= 8; i++) 'chip a$i': chip('a$i'),
        'tab manual': find
            .ancestor(
              of: find.text(l10n.expenseTabManual),
              matching: find.byType(InkWell),
            )
            .first,
        'tab scan': find
            .ancestor(
              of: find.text(l10n.expenseTabScan),
              matching: find.byType(InkWell),
            )
            .first,
        'save': saveButton(),
      };
      targets.forEach((name, finder) {
        final size = tester.getSize(finder);
        expect(size.width, greaterThanOrEqualTo(48), reason: name);
        expect(size.height, greaterThanOrEqualTo(48), reason: name);
      });
    });

    testWidgets('very wide (2560×900) and very tall (1440×1300) stay bounded', (
      tester,
    ) async {
      for (final (w, h) in [(2560.0, 900.0), (1440.0, 1300.0)]) {
        await pumpExpenseScreen(tester, width: w, height: h);
        expect(tester.getRect(find.byType(GridView)).width, closeTo(520, 0.01));
        expect(tester.getRect(keypadKey('5')).height, closeTo(64, 0.01));
      }
    });
  });

  group('L5: more accounts than two rows', () {
    for (final (label, items) in [
      ('16 accounts', accounts(16)),
      ('8 accounts with 14-character names', accounts(8, nameLength: 14)),
    ]) {
      testWidgets('$label: the chooser keeps two rows and scrolls inside', (
        tester,
      ) async {
        await pumpExpenseScreen(tester, width: 1440, height: 900, items: items);
        final chooser = find.byType(SingleChildScrollView);
        expect(chooser, findsOneWidget);
        expect(tester.getSize(chooser).height, lessThanOrEqualTo(106.01));
        final position = tester
            .state<ScrollableState>(
              find.descendant(of: chooser, matching: find.byType(Scrollable)),
            )
            .position;
        expect(position.maxScrollExtent, greaterThan(0));

        // The rest stays in view while the chooser scrolls inside.
        final screen = _screen(1440, 900);
        _expectInside(tester, amountDisplay(), screen, 'amount');
        _expectInside(tester, keypadKey('0'), screen, 'key 0');
        _expectInside(tester, saveButton(), screen, 'Save');
        expect(mainScrollPosition(tester).maxScrollExtent, 0);
      });
    }

    testWidgets('a chip reached by Tab is scrolled into view', (tester) async {
      await pumpExpenseScreen(
        tester,
        width: 1440,
        height: 900,
        items: accounts(16),
      );
      final chooser = find.byType(SingleChildScrollView);
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: chooser, matching: find.byType(Scrollable)),
          )
          .position;
      expect(position.pixels, 0);
      // Back, the two mode tabs, then the chips in visual order.
      for (var i = 0; i < 60 && !focusIsWithin(tester, chip('a16')); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(focusIsWithin(tester, chip('a16')), isTrue);
      expect(position.pixels, greaterThan(0));
      final chooserRect = tester.getRect(chooser);
      final chipRect = tester.getRect(chip('a16'));
      expect(chipRect.bottom, lessThanOrEqualTo(chooserRect.bottom + 0.5));
      expect(chipRect.top, greaterThanOrEqualTo(chooserRect.top - 0.5));
    });
  });

  group('L6/L11: short windows', () {
    testWidgets(
      '1000×500: the pad region scrolls, amount and Save stay in view',
      (tester) async {
        await pumpExpenseScreen(
          tester,
          width: 1000,
          height: 500,
          items: accounts(8),
        );
        final screen = _screen(1000, 500);
        expect(mainScrollPosition(tester).maxScrollExtent, greaterThan(0));
        _expectInside(tester, amountDisplay(), screen, 'amount pinned');
        _expectInside(tester, saveButton(), screen, 'Save pinned');
        // Every key can be scrolled to and tapped.
        for (final key in ['1', '0', '9']) {
          await tester.ensureVisible(keypadKey(key));
          await tester.pump();
          await tester.tap(keypadKey(key));
          await tester.pump();
        }
        expect(amountText(tester), contains('109'));
        // The amount never left the screen while the pad was used.
        _expectInside(tester, amountDisplay(), screen, 'amount still pinned');
      },
    );

    testWidgets(
      '844×390 (phone held sideways): the amount scrolls with the pad',
      (tester) async {
        await pumpExpenseScreen(
          tester,
          width: 844,
          height: 390,
          items: accounts(8),
        );
        final screen = _screen(844, 390);
        // The amount lives inside the main list (not pinned above it).
        expect(
          find.descendant(
            of: find.byType(ListView).first,
            matching: amountDisplay(),
          ),
          findsOneWidget,
        );
        _expectInside(tester, saveButton(), screen, 'Save pinned');
        for (final key in ['1', '0', '⌫', '5']) {
          await tester.ensureVisible(keypadKey(key));
          await tester.pump();
          await tester.tap(keypadKey(key));
          await tester.pump();
        }
        await tester.ensureVisible(chip('a8'));
        await tester.pump();
        await tester.tap(chip('a8'));
        await tester.pump();
        // The banner sits at the end of the (lazy) list: scroll to it.
        final position = mainScrollPosition(tester);
        position.jumpTo(position.maxScrollExtent);
        await tester.pump();
        expect(previewBanner(), findsOneWidget);
      },
    );
  });

  group('L8: scan mode', () {
    testWidgets('the scan tab uses the same bounded panel at 1440×900', (
      tester,
    ) async {
      await pumpExpenseScreen(tester, width: 1440, height: 900);
      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      await tester.tap(find.text(l10n.expenseTabScan));
      await tester.pumpAndSettle();
      expect(keypadKey('1'), findsNothing);
      final capture = find.ancestor(
        of: find.text(l10n.expenseScanCaptureAction),
        matching: find.bySubtype<FilledButton>(),
      );
      final rect = tester.getRect(capture.first);
      expect(rect.width, lessThanOrEqualTo(520.01));
      expect(rect.center.dx, closeTo(720, 1));
    });
  });

  group('L9: compact is unchanged', () {
    testWidgets(
      '410×864: 2.2 aspect keys, horizontal chooser, amount in list',
      (tester) async {
        await pumpExpenseScreen(tester, width: 410, height: 864);
        final rect = tester.getRect(keypadKey('5'));
        expect(rect.width / rect.height, closeTo(2.2, 0.02));
        expect(
          tester
              .widgetList<ListView>(find.byType(ListView))
              .any((list) => list.scrollDirection == Axis.horizontal),
          isTrue,
        );
        expect(find.byType(SingleChildScrollView), findsNothing);
        expect(
          find.descendant(
            of: find.byType(ListView).first,
            matching: amountDisplay(),
          ),
          findsOneWidget,
        );
        // Same 18dp side padding as before.
        expect(tester.getRect(find.byType(GridView)).left, 18);
      },
    );
  });

  group('L12: hover feedback and focus', () {
    for (final entry in _themes.entries) {
      testWidgets(
        '${entry.key}: keys, chips, tabs and Save offer hover feedback',
        (tester) async {
          await pumpExpenseScreen(
            tester,
            width: 1440,
            height: 900,
            theme: entry.value,
          );
          final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
          final targets = <String, Finder>{
            'key 5': keypadKey('5'),
            'chip': chip('a1'),
            'tab scan': find
                .ancestor(
                  of: find.text(l10n.expenseTabScan),
                  matching: find.byType(InkWell),
                )
                .first,
            'save': saveButton(),
          };
          targets.forEach((name, finder) {
            expect(offersHoverFeedback(tester, finder), isTrue, reason: name);
          });
        },
      );
    }

    testWidgets(
      'Tab focuses chips, the mode tabs and Save (keys are skipped)',
      (tester) async {
        await pumpExpenseScreen(tester, width: 1440, height: 900);
        final visited = <String>[];
        for (var i = 0; i < 12; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          for (final key in _padKeys) {
            if (focusIsWithin(tester, keypadKey(key))) visited.add('key$key');
          }
          for (var c = 1; c <= 7; c++) {
            if (focusIsWithin(tester, chip('a$c'))) visited.add('chip$c');
          }
        }
        expect(visited.where((v) => v.startsWith('key')), isEmpty);
        expect(visited, containsAll(['chip1', 'chip7']));
      },
    );
  });

  group('L13: the delete key is labelled', () {
    for (final (w, h) in [(410.0, 864.0), (1440.0, 900.0)]) {
      for (final locale in [const Locale('vi'), const Locale('en')]) {
        testWidgets(
          '${w.toInt()}×${h.toInt()} ${locale.languageCode}: tooltip and label',
          (tester) async {
            useView(tester, w, h);
            final semanticsHandle = tester.ensureSemantics();
            await tester.pumpWidget(
              wrapForTest(
                const ExpenseScreen(),
                repository: FakeExpenseControlRepository(accounts(3)),
                locale: locale,
              ),
            );
            await tester.pumpAndSettle();
            final l10n = await AppLocalizations.delegate.load(locale);
            expect(l10n.expenseKeypadDeleteSemantic, isNotEmpty);
            expect(
              find.byTooltip(l10n.expenseKeypadDeleteSemantic),
              findsOneWidget,
            );
            expect(
              find.bySemanticsLabel(l10n.expenseKeypadDeleteSemantic),
              findsOneWidget,
            );
            semanticsHandle.dispose();
          },
        );
      }
    }
  });
}
