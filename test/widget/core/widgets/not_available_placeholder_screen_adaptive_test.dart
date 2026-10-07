import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/theme/app_icons.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/core/widgets/empty_state_view.dart';
import 'package:finance/core/widgets/not_available_placeholder_screen.dart';

import '../../../support/expense_screen_harness.dart';
import '../../../support/load_app_fonts.dart';

const _message =
    'Tính năng này chưa có. Chúng tôi đang chuẩn bị nội dung cho trang này '
    'và sẽ cập nhật trong một phiên bản sắp tới của ứng dụng.';

/// Pumps the placeholder as the second route of a Navigator, so the back
/// button exists exactly as in the app (pushed from another screen).
Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required double height,
  ThemeData? theme,
  bool rail = false,
}) async {
  useView(tester, width, height);
  Widget page() => const NotAvailablePlaceholderScreen(
    icon: LucideIcons.bell,
    title: 'Thông báo',
    message: _message,
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => rail
                      ? Row(
                          children: [
                            const SizedBox(width: 83),
                            Expanded(child: page()),
                          ],
                        )
                      : page(),
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
  setUpAll(loadAppFonts);

  group('N1: bounded, centered message', () {
    for (final entry in {
      'light': AppTheme.light,
      'dark': AppTheme.dark,
    }.entries) {
      for (final w in [1440.0, 2560.0]) {
        testWidgets('${entry.key} ${w.toInt()}: ≤ 960 and centered', (
          tester,
        ) async {
          await _pump(
            tester,
            width: w,
            height: 900,
            theme: entry.value,
            rail: true,
          );
          final view = tester.getRect(find.byType(EmptyStateView));
          expect(view.width, closeTo(960, 0.01));
          expect(view.center.dx, closeTo(83 + (w - 83) / 2, 1));
          final text = tester.getRect(find.text(_message));
          expect(text.width, lessThanOrEqualTo(960));
          expect(text.center.dx, closeTo(83 + (w - 83) / 2, 1));
        });
      }
    }

    testWidgets('320: the message wraps and nothing overflows', (tester) async {
      await _pump(tester, width: 320, height: 700);
      expect(tester.takeException(), isNull);
      final text = tester.getRect(find.text(_message));
      expect(text.left, greaterThanOrEqualTo(0));
      expect(text.right, lessThanOrEqualTo(320));
    });
  });

  group('N3/N4: back button and short windows', () {
    testWidgets('the back button has a tooltip and a 48dp target', (
      tester,
    ) async {
      await _pump(tester, width: 1440, height: 900, rail: true);
      final back = find.byType(BackButton);
      expect(back, findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
      final size = tester.getSize(find.byType(IconButton).first);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.byType(NotAvailablePlaceholderScreen), findsNothing);
    });

    for (final (w, h) in [(2560.0, 200.0), (320.0, 160.0)]) {
      testWidgets('${w.toInt()}×${h.toInt()}: scrolls instead of overflowing', (
        tester,
      ) async {
        await _pump(tester, width: w, height: h);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
