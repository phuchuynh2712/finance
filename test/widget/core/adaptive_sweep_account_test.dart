import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/features/account/presentation/account_screen.dart';
import 'package:finance/features/account/presentation/change_password_screen.dart';
import 'package:finance/features/account/presentation/security_screen.dart';

import '../../support/account_harness.dart';
import '../../support/adaptive_sweep.dart';
import '../../support/load_app_fonts.dart';

/// Final sweep, layer 1: Hồ sơ, Bảo mật and Đổi mật khẩu across the width ×
/// theme × height × text-size matrix; Hồ sơ and Bảo mật share one column.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    await loadAppFonts();
    l10n = await AppLocalizations.delegate.load(const Locale('vi'));
  });

  Future<void> sweep(WidgetTester tester, SweepCase c, Widget screen) {
    return pumpSweepCase(
      tester,
      c,
      (theme) => screen,
      wrap: (app) =>
          wrapForAccountTest(app, theme: c.theme, textScale: c.textScale),
    );
  }

  Finder row(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;

  group('Hồ sơ', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        await sweep(tester, c, const AccountScreen());
        if (c.width >= 840) {
          final language = tester.getRect(row(l10n.accountLanguageLabel));
          expect(language.width, lessThanOrEqualTo(960.01));
        }
        await expectNoDeadZoneFor(tester, c);
      });
    }
  });

  group('Bảo mật', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        await sweep(tester, c, const SecurityScreen());
        if (c.width >= 840) {
          final change = tester.getRect(row(l10n.securityChangePasswordRow));
          expect(change.width, lessThanOrEqualTo(960.01));
        }
        await expectNoDeadZoneFor(tester, c);
      });
    }
  });

  group('Đổi mật khẩu', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        await sweep(tester, c, const ChangePasswordScreen());
        if (c.width >= 600) {
          final field = tester.getRect(find.byType(TextField).first);
          expect(field.width, lessThanOrEqualTo(450.01));
        }
        await expectNoDeadZoneFor(tester, c);
      });
    }
  });
}
