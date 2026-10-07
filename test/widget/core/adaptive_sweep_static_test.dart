import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/theme/app_icons.dart';
import 'package:finance/core/widgets/empty_state_view.dart';
import 'package:finance/core/widgets/not_available_placeholder_screen.dart';
import 'package:finance/main.dart';

import '../../support/adaptive_sweep.dart';
import '../../support/load_app_fonts.dart';

/// Final sweep, layer 1: the "not available yet" placeholder (Thông báo and
/// Trợ giúp) and the two startup-error screens.
void main() {
  setUpAll(loadAppFonts);

  group('Thông báo / Trợ giúp placeholder', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        await pumpSweepCase(
          tester,
          c,
          (theme) => MaterialApp(
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(c.textScale)),
              child: child!,
            ),
            home: const NotAvailablePlaceholderScreen(
              icon: LucideIcons.bell,
              title: 'Thông báo',
              message:
                  'Tính năng này chưa có. Chúng tôi đang chuẩn bị nội dung '
                  'cho trang này.',
            ),
          ),
          rail: false,
        );
        if (c.width >= 840) {
          expect(
            tester.getRect(find.byType(EmptyStateView)).width,
            lessThanOrEqualTo(960.01),
          );
        }
      });
    }
  });

  for (final reason in StartupFailureReason.values) {
    group('Startup error (${reason.name})', () {
      for (final c in sweepCases) {
        testWidgets(c.name, (tester) async {
          await pumpSweepCase(
            tester,
            c,
            (theme) => StartupErrorApp(reason: reason),
            rail: false,
          );
        });
      }
    });
  }
}
