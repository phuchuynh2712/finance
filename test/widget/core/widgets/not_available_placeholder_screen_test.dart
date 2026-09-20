import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:finance/core/widgets/not_available_placeholder_screen.dart';

void main() {
  testWidgets(
    'renders an AppBar with the given title and the message via EmptyStateView',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NotAvailablePlaceholderScreen(
            icon: LucideIcons.history,
            title: 'Lịch sử giao dịch',
            message: 'Tính năng đang được phát triển.',
          ),
        ),
      );

      expect(find.widgetWithText(AppBar, 'Lịch sử giao dịch'), findsOneWidget);
      expect(find.text('Tính năng đang được phát triển.'), findsOneWidget);
      expect(find.byIcon(LucideIcons.history), findsOneWidget);
    },
  );

  testWidgets('when pushed via Navigator.push, a back button pops it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const NotAvailablePlaceholderScreen(
                      icon: LucideIcons.history,
                      title: 'Lịch sử',
                      message: 'Chưa có',
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Lịch sử'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Lịch sử'), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets(
    'when rendered in-place (not pushed), it still renders correctly with no back button expected',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NotAvailablePlaceholderScreen(
            icon: LucideIcons.layoutDashboard,
            title: 'Tổng quan',
            message: 'Chưa có',
          ),
        ),
      );

      // As the root route, Flutter renders no back button automatically —
      // this is the same widget as the pushed case, just with nothing to
      // pop back to (contracts/spending_balance_ui_state.md's Tổng quan row).
      expect(find.byType(BackButton), findsNothing);
      expect(find.widgetWithText(AppBar, 'Tổng quan'), findsOneWidget);
    },
  );
}
