import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/presentation/widgets/expense_item_row.dart';

ExpenseControlItem _leaf() => const ExpenseControlItem(
  id: 'a',
  userId: 'u1',
  parentId: null,
  name: 'Rent',
  iconKey: 'home',
  description: null,
  sortOrder: 0,
  allocationMethod: ExpenseAllocationMethod.percentage,
  allocationValue: 20,
  balance: 0,
  isSavingsReceiver: false,
);

/// One of the eight icon-only controls the tooltip audit fixed (T021) —
/// used here, rather than a synthetic example, so this test verifies the
/// actual production fix, not just that Flutter's own Tooltip mechanism
/// works.
Widget _harness({VoidCallback? onEdit, VoidCallback? onDelete}) {
  return MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('vi'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(
      body: ExpenseItemRow(item: _leaf(), onEdit: onEdit, onDelete: onDelete),
    ),
  );
}

void main() {
  testWidgets(
    'hovering the edit button (mouse pointer present) shows its tooltip (FR-008)',
    (tester) async {
      await tester.pumpWidget(_harness(onEdit: () {}, onDelete: () {}));

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer();
      await gesture.moveTo(tester.getCenter(find.byIcon(LucideIcons.pencil)));
      await tester.pumpAndSettle();

      expect(find.text('Sửa Rent'), findsOneWidget);
    },
  );

  testWidgets(
    'Tab reaches and Enter activates both the edit and delete buttons, in order (FR-009)',
    (tester) async {
      var editTapped = false;
      var deleteTapped = false;
      await tester.pumpWidget(
        _harness(
          onEdit: () => editTapped = true,
          onDelete: () => deleteTapped = true,
        ),
      );

      // Start from nothing focused, then Tab to the first focusable control
      // (the edit button — showHeader's icon/name text isn't focusable).
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        Focus.of(
          tester.element(find.byIcon(LucideIcons.pencil)),
        ).hasPrimaryFocus,
        isTrue,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(editTapped, isTrue);
      expect(deleteTapped, isFalse);

      // Tab again to the next focusable control — the delete button.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        Focus.of(
          tester.element(find.byIcon(LucideIcons.trash2)),
        ).hasPrimaryFocus,
        isTrue,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(deleteTapped, isTrue);
    },
  );
}
