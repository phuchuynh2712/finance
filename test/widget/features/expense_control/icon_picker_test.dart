import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/widgets/expense_control_icons.dart';
import 'package:finance/features/expense_control/presentation/widgets/icon_picker.dart';

void main() {
  Widget harness({
    required String? selected,
    required ValueChanged<String> onSelected,
  }) {
    return MaterialApp(
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: IconPicker(selectedKey: selected, onSelected: onSelected),
      ),
    );
  }

  testWidgets('selecting an icon returns its key', (tester) async {
    String? selectedKey;
    await tester.pumpWidget(
      harness(selected: null, onSelected: (key) => selectedKey = key),
    );

    await tester.tap(find.byIcon(resolveExpenseControlIcon('family')));
    await tester.pump();

    expect(selectedKey, 'family');
  });

  testWidgets('initial selection renders with the selected visual state', (
    tester,
  ) async {
    await tester.pumpWidget(harness(selected: 'home', onSelected: (_) {}));

    final homeSemantics = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .firstWhere((s) => s.properties.label == 'Biểu tượng home');
    expect(homeSemantics.properties.selected, isTrue);

    final familySemantics = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .firstWhere((s) => s.properties.label == 'Biểu tượng family');
    expect(familySemantics.properties.selected, isNot(isTrue));
  });
}
