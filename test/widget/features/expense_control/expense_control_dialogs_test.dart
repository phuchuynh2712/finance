import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/presentation/expense_control_screen.dart';

import '../../../support/expense_control_fixtures.dart';
import '../../../support/expense_screen_harness.dart';

List<ExpenseControlItem> _plan() => [
  ...groupWithChildren('g1', groupName: 'Nhà', childCount: 2),
  leafItem('solo', name: 'Tiết kiệm', sortOrder: 1, value: 20),
];

Future<FakeExpenseControlRepository> _pump(
  WidgetTester tester, {
  required double width,
  required double height,
  ThemeData? theme,
}) async {
  useView(tester, width, height);
  final repository = FakeExpenseControlRepository(_plan());
  await tester.pumpWidget(
    KeyedSubtree(
      key: UniqueKey(),
      child: wrapForTest(
        const ExpenseControlScreen(),
        repository: repository,
        theme: theme ?? AppTheme.light,
        rail: width >= 600,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

/// Desktop platforms have a hardware keyboard: the pop-up focuses its first
/// field and Enter saves. The default test platform is Android (a phone).
final _desktop = AppTheme.light.copyWith(platform: TargetPlatform.macOS);

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('vi'));
  });

  Finder nameField() =>
      find.widgetWithText(TextField, l10n.expenseControlNameLabel);
  Finder valueField() =>
      find.widgetWithText(TextField, l10n.expenseControlValueLabel);

  Future<void> openAddDialog(WidgetTester tester) async {
    final add = find.text(l10n.expenseControlAddItemAction);
    // On a short window the button is below the fold of the lazy list.
    await tester.scrollUntilVisible(
      add,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(add.first);
    await tester.pump();
    await tester.tap(add.first);
    await tester.pumpAndSettle();
  }

  group('D1/D3: the add-item pop-up', () {
    testWidgets('1440×900: centered, at most 560 wide, name field focused', (
      tester,
    ) async {
      await _pump(tester, width: 1440, height: 900, theme: _desktop);
      await openAddDialog(tester);
      final rect = dialogRect(tester);
      expect(rect.width, lessThanOrEqualTo(560.01));
      expect(rect.center.dx, closeTo(720, 1));
      expect(focusIsWithin(tester, nameField()), isTrue);
    });

    testWidgets('410×864: fully visible inside the window', (tester) async {
      await _pump(tester, width: 410, height: 864);
      await openAddDialog(tester);
      final rect = dialogRect(tester);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(410));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(864));
    });

    testWidgets('Enter in the last field saves when the form is valid', (
      tester,
    ) async {
      final repository = await _pump(
        tester,
        width: 1440,
        height: 900,
        theme: _desktop,
      );
      await openAddDialog(tester);
      await tester.enterText(nameField(), 'Thuê nhà');
      await tester.enterText(valueField(), '12');
      await tester.pump();
      await tester.tap(valueField());
      await tester.pump();
      // A real Enter in a single-line field reaches the framework as the
      // text-input "done" action (the browser/OS input handles the key).
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        (await repository.getAll()).any((item) => item.name == 'Thuê nhà'),
        isTrue,
      );
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Enter does nothing while the form is invalid', (tester) async {
      final repository = await _pump(
        tester,
        width: 1440,
        height: 900,
        theme: _desktop,
      );
      final before = (await repository.getAll()).length;
      await openAddDialog(tester);
      await tester.enterText(valueField(), '12'); // the name is still empty
      await tester.pump();
      await tester.tap(valueField());
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect((await repository.getAll()).length, before);
    });

    for (final (w, h) in [(410.0, 864.0), (844.0, 390.0), (1440.0, 900.0)]) {
      testWidgets('${w.toInt()}×${h.toInt()} without a hardware keyboard: the '
          'on-screen keyboard stays closed and its "done" key does not save', (
        tester,
      ) async {
        final repository = await _pump(tester, width: w, height: h);
        final before = (await repository.getAll()).length;
        await openAddDialog(tester);
        // No field takes the focus by itself (that would raise the keyboard).
        expect(tester.widget<TextField>(nameField()).autofocus, isFalse);
        expect(focusIsWithin(tester, nameField()), isFalse);
        // The keyboard keeps the platform's own action keys.
        expect(tester.widget<TextField>(nameField()).textInputAction, isNull);
        expect(tester.widget<TextField>(valueField()).textInputAction, isNull);
        expect(tester.widget<TextField>(valueField()).onSubmitted, isNull);

        await tester.enterText(nameField(), 'Thuê nhà');
        await tester.enterText(valueField(), '12');
        await tester.pump();
        await tester.tap(valueField());
        await tester.pump();
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect((await repository.getAll()).length, before);
      });
    }

    testWidgets('Escape closes the pop-up without saving', (tester) async {
      final repository = await _pump(tester, width: 1440, height: 900);
      final before = (await repository.getAll()).length;
      await openAddDialog(tester);
      await tester.enterText(nameField(), 'Bỏ');
      await _press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(AlertDialog), findsNothing);
      expect((await repository.getAll()).length, before);
    });

    testWidgets(
      'D8: resizing while open keeps it centered, visible and typed',
      (tester) async {
        await _pump(tester, width: 1440, height: 900);
        await openAddDialog(tester);
        await tester.enterText(nameField(), 'Giữ nguyên');
        for (final (w, h) in [(410.0, 864.0), (1440.0, 900.0)]) {
          useView(tester, w, h);
          await tester.pumpAndSettle();
          final rect = dialogRect(tester);
          expect(rect.left, greaterThanOrEqualTo(0), reason: '$w');
          expect(rect.right, lessThanOrEqualTo(w), reason: '$w');
          expect(rect.center.dx, closeTo(w / 2, 1), reason: '$w');
          expect(find.text('Giữ nguyên'), findsOneWidget, reason: '$w');
        }
      },
    );
  });

  group('D4: the delete-group confirmation defaults to the safe action', () {
    Future<void> openDelete(WidgetTester tester) async {
      await tester.tap(
        find.byTooltip(l10n.expenseControlDeleteSemantic('Nhà')),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'Cancel has the initial focus; Enter cancels and deletes nothing',
      (tester) async {
        final repository = await _pump(tester, width: 1440, height: 900);
        await openDelete(tester);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          focusIsWithin(
            tester,
            find.widgetWithText(TextButton, l10n.cancelAction),
          ),
          isTrue,
        );
        await _press(tester, LogicalKeyboardKey.enter);
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          (await repository.getAll()).any((item) => item.id == 'g1'),
          isTrue,
        );
      },
    );

    testWidgets('Escape cancels', (tester) async {
      final repository = await _pump(tester, width: 1440, height: 900);
      await openDelete(tester);
      await _press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        (await repository.getAll()).any((item) => item.id == 'g1'),
        isTrue,
      );
    });

    testWidgets('the confirm button still deletes when chosen on purpose', (
      tester,
    ) async {
      final repository = await _pump(tester, width: 1440, height: 900);
      await openDelete(tester);
      await tester.tap(find.text(l10n.expenseControlDeleteGroupConfirmAction));
      await tester.pumpAndSettle();
      expect(
        (await repository.getAll()).any((item) => item.id == 'g1'),
        isFalse,
      );
    });

    testWidgets('it is at most 560 wide and centered', (tester) async {
      await _pump(tester, width: 1440, height: 900);
      await openDelete(tester);
      final rect = dialogRect(tester);
      expect(rect.width, lessThanOrEqualTo(560.01));
      expect(rect.center.dx, closeTo(720, 1));
    });
  });
}
