import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/main.dart' show localizedAppTitle;

/// The browser tab and the task switcher show the app's name in the language
/// the app is in.
void main() {
  Future<String> titleIn(WidgetTester tester, Locale locale) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateTitle: localizedAppTitle,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const SizedBox.shrink(),
      ),
    );
    return tester.widget<Title>(find.byType(Title)).title;
  }

  testWidgets('Vietnamese: "Kiểm Soát"', (tester) async {
    expect(await titleIn(tester, const Locale('vi')), 'Kiểm Soát');
  });

  testWidgets('English: "Finance"', (tester) async {
    expect(await titleIn(tester, const Locale('en')), 'Finance');
  });
}
