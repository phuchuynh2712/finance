import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/presentation/widgets/expense_item_row.dart';

ExpenseControlItem _leaf(double value) => ExpenseControlItem(
  id: 'a',
  userId: 'u1',
  parentId: null,
  name: 'Rent',
  iconKey: 'home',
  description: null,
  sortOrder: 0,
  allocationMethod: ExpenseAllocationMethod.percentage,
  allocationValue: value,
  balance: 0,
);

Widget _harness(ExpenseControlItem item) {
  return MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('vi'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(body: ExpenseItemRow(item: item, showHeader: false)),
  );
}

void main() {
  testWidgets(
    'the allocation value renders as a non-interactive static label, not a TextField (FR-001)',
    (tester) async {
      await tester.pumpWidget(_harness(_leaf(20)));

      // FR-001: no input widget at all — the old TextField-based field is
      // gone entirely, replaced by a plain label.
      expect(find.byType(TextField), findsNothing);
      expect(find.text('20%'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the value label produces no reaction — no keyboard, no cursor, no dialog (FR-001, SC-001)',
    (tester) async {
      await tester.pumpWidget(_harness(_leaf(20)));

      await tester.tap(find.text('20%'));
      await tester.pumpAndSettle();

      // Still no TextField (nothing became focusable/editable), no keyboard
      // requested, and no dialog opened as a side effect of the tap.
      expect(find.byType(TextField), findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.byType(Dialog), findsNothing);
      // The label itself is unchanged — tapping did not mutate anything.
      expect(find.text('20%'), findsOneWidget);
    },
  );

  testWidgets(
    'a fixed-amount value renders formatted, not the raw percentage-style number',
    (tester) async {
      final fixedLeaf = ExpenseControlItem(
        id: 'b',
        userId: 'u1',
        parentId: null,
        name: 'Học phí các con',
        iconKey: 'home',
        description: null,
        sortOrder: 0,
        allocationMethod: ExpenseAllocationMethod.fixed,
        allocationValue: 4000000,
        balance: 0,
      );
      await tester.pumpWidget(_harness(fixedLeaf));

      expect(find.byType(TextField), findsNothing);
      // Exact currency punctuation is CurrencyFormatter's concern, not this
      // widget's — assert the raw amount's digits are present and it is not
      // rendered with a trailing "%".
      expect(find.textContaining('4.000.000'), findsOneWidget);
      expect(find.text('4000000%'), findsNothing);
    },
  );
}
