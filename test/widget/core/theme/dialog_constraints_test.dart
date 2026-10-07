import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/theme/app_theme.dart';

import '../../../support/expense_screen_harness.dart';

Future<void> _openWideDialog(
  WidgetTester tester,
  ThemeData theme,
  double width,
  double height, {
  double childWidth = 2000,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Tiêu đề'),
                  content: SizedBox(width: childWidth, height: 40),
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
}

void main() {
  for (final entry in {
    'light': AppTheme.light,
    'dark': AppTheme.dark,
  }.entries) {
    group('shared dialog constraints (${entry.key})', () {
      testWidgets(
        '1440×900: a very wide dialog is capped at 560 and centered',
        (tester) async {
          await _openWideDialog(tester, entry.value, 1440, 900);
          final rect = dialogRect(tester);
          expect(rect.width, closeTo(560, 0.01));
          expect(rect.center.dx, closeTo(720, 1));
        },
      );

      testWidgets('410×864: stays inside the window', (tester) async {
        await _openWideDialog(tester, entry.value, 410, 864);
        final rect = dialogRect(tester);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(410));
        expect(rect.width, greaterThanOrEqualTo(280));
      });

      testWidgets('a narrow dialog keeps the 280 minimum', (tester) async {
        await _openWideDialog(tester, entry.value, 1440, 900, childWidth: 20);
        expect(dialogRect(tester).width, greaterThanOrEqualTo(280));
      });
    });
  }
}
