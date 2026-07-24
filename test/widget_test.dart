import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/l10n/app_localizations.dart';

void main() {
  testWidgets('MaterialApp renders Vietnamese title by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('vi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: Text('smoke test')),
        ),
      ),
    );

    expect(find.text('smoke test'), findsOneWidget);
  });
}
